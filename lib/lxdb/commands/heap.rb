# frozen_string_literal: true

module Lxdb
  module Commands
    class HeapChunks < Base
      command "heap", aliases: ["chunks"], description: "Show heap chunks", category: :heap

      def execute(args)
        require_stopped!

        allocator = allocator()
        count = (args.first || 20).to_i

        chunks = allocator.chunks(count: count)

        if chunks.empty?
          output(c("No heap chunks found", :warning))
          return
        end

        output(c("Heap Chunks:", :banner))
        output("")

        chunks.each do |chunk|
          output(format_chunk(chunk))
        end

        output("")
        output(c("Total: #{chunks.size} chunks", :info))
      end

      private

      def allocator
        @allocator ||= Heap::Glibc::Ptmalloc.new(session)
      end

      def format_chunk(chunk)
        addr = c(format_address(chunk.address), :address)
        size = c(format("0x%x", chunk.real_size), :value)

        status = if chunk.in_use?
                   c("INUSE", :success)
                 else
                   c("FREE ", :warning)
                 end

        flags = []
        flags << "P" if chunk.prev_inuse?
        flags << "M" if chunk.is_mmapped?
        flags << "N" if chunk.non_main_arena?
        flags_str = flags.empty? ? "" : c(" [#{flags.join}]", :comment)

        "#{addr} | #{size.rjust(12)} | #{status}#{flags_str}"
      end
    end

    class HeapBins < Base
      command "bins", aliases: ["heapbins"], description: "Show heap bins (fastbins, tcache, etc.)", category: :heap

      def execute(args)
        require_stopped!

        allocator = allocator()
        bin_type = args.first&.downcase

        case bin_type
        when "fast", "fastbins"
          show_fastbins(allocator)
        when "tcache"
          show_tcache(allocator)
        when "unsorted"
          show_unsorted(allocator)
        when "small", "smallbins"
          show_smallbins(allocator)
        when "large", "largebins"
          show_largebins(allocator)
        else
          show_all_bins(allocator)
        end
      end

      private

      def allocator
        Heap::Glibc::Ptmalloc.new(session)
      end

      def show_all_bins(allocator)
        show_tcache(allocator)
        output("")
        show_fastbins(allocator)
        output("")
        show_unsorted(allocator)
      end

      def show_fastbins(allocator)
        output(c("Fastbins:", :banner))

        bins = allocator.fastbins
        if bins.empty?
          output("  (empty)")
          return
        end

        bins.each do |index, chunks|
          size = fastbin_size(index)
          output(c("  [#{index}] 0x#{size.to_s(16)}: ", :info) + format_chain(chunks))
        end
      end

      def show_tcache(allocator)
        output(c("Tcache:", :banner))

        bins = allocator.tcache_bins
        if bins.empty?
          output("  (empty or not available)")
          return
        end

        bins.each do |index, chunks|
          size = tcache_size(index)
          output(c("  [#{index}] 0x#{size.to_s(16)}: ", :info) + format_chain(chunks))
        end
      end

      def show_unsorted(allocator)
        output(c("Unsorted Bin:", :banner))

        chunks = allocator.unsorted_bin
        if chunks.empty?
          output("  (empty)")
          return
        end

        output("  #{format_chain(chunks)}")
      end

      def show_smallbins(allocator)
        output(c("Small Bins:", :banner))

        bins = allocator.smallbins
        if bins.empty?
          output("  (empty)")
          return
        end

        bins.each do |index, chunks|
          output(c("  [#{index}]: ", :info) + format_chain(chunks))
        end
      end

      def show_largebins(allocator)
        output(c("Large Bins:", :banner))

        bins = allocator.largebins
        if bins.empty?
          output("  (empty)")
          return
        end

        bins.each do |index, chunks|
          output(c("  [#{index}]: ", :info) + format_chain(chunks))
        end
      end

      def format_chain(chunks)
        chunks.map { |c| c(format_address(c.address), :address) }.join(" -> ")
      end

      def fastbin_size(index)
        min_size = session.architecture.pointer_size == 8 ? 0x20 : 0x10
        alignment = session.architecture.pointer_size == 8 ? 0x10 : 0x8
        min_size + (index * alignment)
      end

      def tcache_size(index)
        fastbin_size(index)
      end
    end

    class HeapTop < Base
      command "top_chunk", aliases: ["heaptop"], description: "Show top chunk", category: :heap

      def execute(_args)
        require_stopped!

        allocator = Heap::Glibc::Ptmalloc.new(session)
        chunk = allocator.top_chunk

        if chunk
          output(c("Top Chunk:", :banner))
          output("  Address: #{c(format_address(chunk.address), :address)}")
          output("  Size:    #{c(format("0x%x", chunk.real_size), :value)}")
        else
          output(c("Could not find top chunk", :warning))
        end
      end
    end

    class HeapArena < Base
      command "arena", aliases: ["main_arena"], description: "Show main arena info", category: :heap

      def execute(_args)
        require_stopped!

        allocator = Heap::Glibc::Ptmalloc.new(session)
        arena = allocator.main_arena

        if arena
          output(c("Main Arena:", :banner))
          output("  Address:     #{c(format_address(arena.address), :address)}")
          output("  Top:         #{c(format_address(arena.top), :address)}")
          output("  System mem:  #{c(format("0x%x", arena.system_mem), :value)}")
          output("  Flags:       #{c(format("0x%x", arena.flags), :value)}")
        else
          output(c("Could not find main_arena", :warning))
          output("Try: 'p &main_arena' in LLDB to find the address")
        end
      end
    end

    class HeapArenas < Base
      command "arenas", aliases: ["heap_arenas"], description: "Show all arena info", category: :heap

      def execute(_args)
        require_stopped!

        allocator = Heap::Glibc::Ptmalloc.new(session)
        arenas = allocator.arenas

        if arenas.empty?
          output(c("No arenas found", :warning))
          output("Try: 'p &main_arena' in LLDB to verify heap allocator state")
          return
        end

        output(c("Heap Arenas:", :banner))
        output("  Count: #{arenas.size}")
        output("")

        arenas.each_with_index do |arena, index|
          output(c("##{index}", :frame_number))
          output("  Address:        #{c(format_address(arena.address), :address)}")
          output("  Top:            #{c(format_address(arena.top), :address)}")
          output("  Last Remainder: #{c(format_address(arena.last_remainder), :address)}")
          output("  System memory:  #{c(format("0x%x", arena.system_mem), :value)}")
          output("  Flags:          #{c(format("0x%x", arena.flags), :value)}")
          output("  Next arena:     #{c(format_address(arena.next_arena), :address)}")
          output("")
        end
      end
    end
  end
end
