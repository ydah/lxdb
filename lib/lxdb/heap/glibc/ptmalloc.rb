# frozen_string_literal: true

module Lxdb
  module Heap
    module Glibc
      class Ptmalloc < Allocator
        def name
          "ptmalloc2 (glibc)"
        end

        def main_arena
          @main_arena ||= find_main_arena
        end

        def tcache
          @tcache ||= find_tcache
        end

        def heap_base
          @heap_base ||= find_heap_base
        end

        def chunks(start_addr: nil, count: 100)
          start = start_addr || heap_base
          return [] unless start

          result = []
          addr = start

          count.times do
            chunk = MallocChunk.new(@session, addr)
            break if chunk.real_size < Constants.min_chunk_size(pointer_size)
            break if chunk.real_size > 0x100000 # Sanity check: 1MB max

            result << chunk
            addr += chunk.real_size
          rescue StandardError
            break
          end

          result
        end

        def find_main_arena
          # Try to find main_arena symbol
          result = @session.execute_command("image lookup -s main_arena")
          if result =~ /Address:\s*(0x[0-9a-fA-F]+)/
            addr = Regexp.last_match(1).to_i(16)
            return MallocState.new(@session, addr)
          end

          # Try common libc offsets (this is fragile)
          nil
        end

        def find_tcache
          # tcache is stored in thread-local storage
          # Try to find tcache symbol or use heuristics
          result = @session.execute_command("p (void*)tcache")
          if result =~ /(0x[0-9a-fA-F]+)/
            addr = Regexp.last_match(1).to_i(16)
            return TcachePerthread.new(@session, addr) if addr != 0
          end

          nil
        end

        def find_heap_base
          # Parse memory mappings to find heap
          result = @session.execute_command("memory region --all")
          result.each_line do |line|
            if (line =~ /\[heap\]/ || line =~ /heap/i) && (line =~ /(0x[0-9a-fA-F]+)/)
              return Regexp.last_match(1).to_i(16)
            end
          end

          # Fallback: try to find from brk
          result = @session.execute_command("p (void*)sbrk(0)")
          if result =~ /(0x[0-9a-fA-F]+)/
            # sbrk(0) returns current break, heap starts below it
            # This is approximate
          end

          nil
        end

        def fastbins
          return {} unless main_arena

          main_arena.all_fastbin_chunks
        end

        def unsorted_bin
          return [] unless main_arena

          main_arena.unsorted_bin_chunks
        end

        def smallbins
          return {} unless main_arena

          result = {}
          (2...Constants::NSMALLBINS).each do |i|
            chunks = main_arena.smallbin_chunks(i)
            result[i] = chunks unless chunks.empty?
          end
          result
        end

        def largebins
          return {} unless main_arena

          result = {}
          (0...(Constants::NBINS - Constants::NSMALLBINS)).each do |i|
            chunks = main_arena.largebin_chunks(i)
            result[i] = chunks unless chunks.empty?
          end
          result
        end

        def tcache_bins
          return {} unless tcache

          tcache.all_tcache_chunks
        end

        def top_chunk
          main_arena&.top_chunk
        end

        def arenas
          @arenas ||= collect_arenas
        end

        private

        def collect_arenas
          return [] unless main_arena

          result = []
          seen = {}
          current = main_arena

          64.times do
            break if current.nil?
            break if seen[current.address]

            result << current
            seen[current.address] = true

            next_addr = current.next_arena
            break unless next_addr.is_a?(Integer)
            break if next_addr <= 0
            break unless session.memory&.valid_pointer?(next_addr)
            break if next_addr == current.address

            current = MallocState.new(@session, next_addr)
          end

          result
        end
      end
    end
  end
end
