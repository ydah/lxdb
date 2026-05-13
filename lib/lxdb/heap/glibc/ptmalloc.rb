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

        def chunks_for_arena(arena, count: 100)
          start = heap_base
          return [] unless start

          chunks = chunks(start_addr: start, count: count)
          return chunks if arena.nil? || arena == :all || arena == :main
          return chunks.select(&:non_main_arena?) if arena == :non_main

          chunks.select do |chunk|
            if arena == main_arena
              !chunk.non_main_arena?
            else
              chunk.non_main_arena?
            end
          end
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
          fastbins_for_arena(main_arena)
        end

        def unsorted_bin
          unsorted_bin_for_arena(main_arena)
        end

        def smallbins
          smallbins_for_arena(main_arena)
        end

        def largebins
          largebins_for_arena(main_arena)
        end

        def tcache_bins
          tcache_bins_for_arena(tcache)
        end

        def top_chunk
          main_arena&.top_chunk
        end

        def fastbins_for_arena(arena)
          return {} if arena.nil? || !main_arena
          return main_arena.all_fastbin_chunks if arena == :main
          return collect_all_fastbins_for_arenas(arenas_from_reference(arena))
        end

        def unsorted_bin_for_arena(arena)
          return [] if arena.nil? || !main_arena
          return main_arena.unsorted_bin_chunks if arena == :main
          return collect_all_chunks_for_arenas(arenas_from_reference(arena), :unsorted_bin_chunks)
        end

        def smallbins_for_arena(arena)
          return {} if arena.nil? || !main_arena
          return collect_all_bins_for_arenas(arenas_from_reference(arena), 2...Constants::NSMALLBINS) do |arena_state, index|
            arena_state.smallbin_chunks(index)
          end if arena != :main

          result = {}
          (2...Constants::NSMALLBINS).each do |i|
            chunks = main_arena.smallbin_chunks(i)
            result[i] = chunks unless chunks.empty?
          end
          result
        end

        def largebins_for_arena(arena)
          return {} if arena.nil? || !main_arena
          return collect_all_bins_for_arenas(arenas_from_reference(arena), 0...(Constants::NBINS - Constants::NSMALLBINS)) do |arena_state, index|
            arena_state.largebin_chunks(index)
          end if arena != :main

          result = {}
          (0...(Constants::NBINS - Constants::NSMALLBINS)).each do |i|
            chunks = main_arena.largebin_chunks(i)
            result[i] = chunks unless chunks.empty?
          end
          result
        end

        def tcache_bins_for_arena(target_tcache)
          return {} unless target_tcache

          target_tcache.all_tcache_chunks
        end

        def arenas
          @arenas ||= collect_arenas
        end

        def arena_by_reference(reference)
          return main_arena if reference.nil? || reference == :main
          return :all if reference == :all
          return :non_main if reference == :non_main

          arena_list = arenas
          return nil if arena_list.empty?

          if reference.is_a?(Integer)
            if reference >= 0 && reference < arena_list.size
              return arena_list[reference]
            end
          elsif reference.is_a?(String)
            if reference.match?(/\Aarena=/i)
              reference = reference.sub(/\Aarena=/i, "")
            end

            if reference.match?(/\A\d+\z/)
              index = reference.to_i
              return arena_list[index] if index >= 0 && index < arena_list.size
            end

            return main_arena if reference.match?(/\Amain\b|\Amain_arena\b/i)
            return :non_main if reference.match?(/\Anon-?main\b/i)
            return :all if reference.match?(/\Aall\b/i)

            if reference.start_with?("0x") || reference.match?(/\A[0-9a-f]+\z/i)
              begin
                address = Integer(reference)
              rescue StandardError
                address = Integer(reference, 16)
              rescue StandardError
                nil
              end
              return arena_list.find { |arena| arena.address == address } if address
            end
          end

          nil
        end

        private

        def arenas_from_reference(arena)
          return [] unless arena && main_arena

          return [main_arena] if arena == :main

          return [] unless %i[all non_main].include?(arena) || arena.is_a?(MallocState)

          case arena
          when :all
            arenas
          when :non_main
            arenas.reject { |item| item == main_arena }
          else
            [arena]
          end
        end

        def collect_all_fastbins_for_arenas(arena_states)
          result = {}
          arena_states.each do |arena_state|
            arena_state.all_fastbin_chunks.each do |index, chunks|
              result[index] ||= []
              result[index].concat(chunks)
            end
          end

          result
        end

        def collect_all_bins_for_arenas(arena_states, index_range, &block)
          result = {}
          arena_states.each do |arena_state|
            index_range.each do |index|
              chunks = block.call(arena_state, index)
              next if chunks.empty?

              result[index] ||= []
              result[index].concat(chunks)
            end
          end

          result
        end

        def collect_all_chunks_for_arenas(arena_states, method_name)
          chunks = []
          arena_states.each do |arena_state|
            chunks.concat(arena_state.public_send(method_name))
          end

          chunks
        end

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
