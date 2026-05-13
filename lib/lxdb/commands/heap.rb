# frozen_string_literal: true

module Lxdb
  module Commands
    class HeapChunks < Base
      command "heap", aliases: ["chunks"], description: "Show heap chunks", category: :heap

      def execute(args)
        require_stopped!

        allocator = allocator()
        arena_ref, count = parse_chunks_args(args)
        arena = allocator.arena_by_reference(arena_ref)
        chunks = allocator.chunks_for_arena(arena, count: count)

        if chunks.empty?
          output(c("No heap chunks found", :warning))
          output("Try: 'heap arenas' to inspect available arenas") unless allocator.arenas.empty?
          return
        end

        output(c("Heap Chunks:", :banner))
        output("  Arena: #{arena_label(arena)}")
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

      def parse_chunks_args(args)
        return [nil, 20] if args.empty?

        first = args[0].to_s

        if first.match?(/\A\d+\z/)
          count = parse_count(first)
          return [nil, count] if args[1].nil?
        end

        if arena_reference?(first)
          if args[1]
            [sanitize_arena_reference(first), parse_count(args[1])]
          else
            [sanitize_arena_reference(first), 20]
          end
        else
          count = parse_count(first)
          [nil, count.positive? ? count : 20]
        end
      end

      def arena_reference?(token)
        return false unless token

        normalized = token.to_s.downcase
        return true if normalized.start_with?("arena=")
        return true if %w[main non-main nonmain all].include?(normalized)
        return true if normalized.start_with?("0x")
        return true if token.match?(/\A\d+\z/)

        false
      end

      def sanitize_arena_reference(token)
        token = token.to_s
        token.start_with?("arena=") ? token.sub(/^arena=/i, "") : token
      end

      def parse_count(value)
        return 20 unless value.to_s.match?(/\A\d+\z/)

        count = value.to_i
        count.positive? ? count : 20
      end

      def arena_label(arena)
        if arena == :all
          "all"
        elsif arena == :non_main
          "non-main"
        elsif arena == :main || arena.nil?
          "main"
        else
          "##{allocator.arenas.index(arena)} (0x#{format("%x", arena.address)})"
        end
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
        bin_type, arena_ref = parse_bins_args(args)
        arena = allocator.arena_by_reference(arena_ref)

        return output(c("Unknown arena reference: #{arena_ref}", :error)) if arena_ref && arena.nil?

        case bin_type
        when "fast", "fastbins"
          show_fastbins(allocator, arena)
        when "tcache"
          show_tcache(allocator, arena)
        when "unsorted"
          show_unsorted(allocator, arena)
        when "small", "smallbins"
          show_smallbins(allocator, arena)
        when "large", "largebins"
          show_largebins(allocator, arena)
        else
          show_all_bins(allocator, arena)
        end
      end

      private

      def allocator
        Heap::Glibc::Ptmalloc.new(session)
      end

      def show_all_bins(allocator, arena)
        show_tcache(allocator, arena)
        output("")
        show_fastbins(allocator, arena)
        output("")
        show_unsorted(allocator, arena)
        output("")
        show_smallbins(allocator, arena)
        output("")
        show_largebins(allocator, arena)
      end

      def show_fastbins(allocator, arena)
        output(c("Fastbins:", :banner))

        bins = allocator.fastbins_for_arena(arena_for_bins(allocator, arena))
        if bins.empty?
          output("  (empty)")
          return
        end

        bins.each do |index, chunks|
          size = fastbin_size(index)
          output(c("  [#{index}] 0x#{size.to_s(16)}: ", :info) + format_chain(chunks))
        end
      end

      def show_tcache(allocator, arena)
        output(c("Tcache:", :banner))

        bins = allocator.tcache_bins_for_arena(tcache_for_arena(allocator, arena))
        if bins.empty?
          output("  (empty or not available)")
          return
        end

        bins.each do |index, chunks|
          size = tcache_size(index)
          output(c("  [#{index}] 0x#{size.to_s(16)}: ", :info) + format_chain(chunks))
        end
      end

      def show_unsorted(allocator, arena)
        output(c("Unsorted Bin:", :banner))

        chunks = allocator.unsorted_bin_for_arena(arena_for_bins(allocator, arena))
        if chunks.empty?
          output("  (empty)")
          return
        end

        output("  #{format_chain(chunks)}")
      end

      def show_smallbins(allocator, arena)
        output(c("Small Bins:", :banner))

        bins = allocator.smallbins_for_arena(arena_for_bins(allocator, arena))
        if bins.empty?
          output("  (empty)")
          return
        end

        bins.each do |index, chunks|
          output(c("  [#{index}]: ", :info) + format_chain(chunks))
        end
      end

      def show_largebins(allocator, arena)
        output(c("Large Bins:", :banner))

        bins = allocator.largebins_for_arena(arena_for_bins(allocator, arena))
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

      def parse_bins_args(args)
        first = args[0]&.downcase
        second = args[1]

        if first == "arena"
          return ["all", second]
        end

        if first && first.start_with?("arena=")
          return ["all", first]
        end

        if first && bin_type?(first)
          arena_ref = if second && arena_reference?(second)
                        sanitize_arena_reference(second)
                      end
          return [first, arena_ref]
        end

        if first && arena_reference?(first)
          return ["all", sanitize_arena_reference(first)]
        end

        ["all", nil]
      end

      def bin_type?(token)
        %w[fast fastbins tcache unsorted small smallbins large largebins all].include?(token)
      end

      def arena_for_bins(allocator, arena)
        resolved = arena
        return nil if resolved.nil? || resolved == :main
        return :all if resolved == :all
        return nil if resolved == :non_main
        resolved
      end

      def tcache_for_arena(allocator, arena)
        return nil if arena == :non_main
        allocator.tcache
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
