# frozen_string_literal: true

module Lxdb
  module Heap
    module Glibc
      class MallocState
        include Constants

        attr_reader :address, :mutex, :flags, :fastbins, :top, :last_remainder, :bins, :binmap, :next_arena, :next_free, :system_mem

        def initialize(session, address)
          @session = session
          @address = address
          @pointer_size = session.architecture.pointer_size
          @memory = session.memory
          parse
        end

        def parse
          offset = 0

          # mutex (4 bytes)
          @mutex = @memory.read_u32(@address + offset)
          offset += 4

          # flags (4 bytes)
          @flags = @memory.read_u32(@address + offset)
          offset += 4

          # Padding for alignment on 64-bit
          offset += 8 if @pointer_size == 8

          # fastbinsY array
          @fastbins = []
          NFASTBINS.times do
            @fastbins << @memory.read_pointer(@address + offset)
            offset += @pointer_size
          end

          # top chunk
          @top = @memory.read_pointer(@address + offset)
          offset += @pointer_size

          # last_remainder
          @last_remainder = @memory.read_pointer(@address + offset)
          offset += @pointer_size

          # bins array (NBINS * 2 pointers for fd/bk)
          @bins = []
          (NBINS * 2).times do
            @bins << @memory.read_pointer(@address + offset)
            offset += @pointer_size
          end

          # binmap (4 * 4 bytes)
          @binmap = []
          4.times do
            @binmap << @memory.read_u32(@address + offset)
            offset += 4
          end

          # next (arena)
          @next_arena = @memory.read_pointer(@address + offset)
          offset += @pointer_size

          # next_free
          @next_free = @memory.read_pointer(@address + offset)
          offset += @pointer_size

          # system_mem
          @system_mem = @memory.read_pointer(@address + offset)
        end

        def fastbin_chunks(index)
          return [] if index >= @fastbins.size

          chunks = []
          ptr = @fastbins[index]

          while ptr != 0 && chunks.size < 1000 # Safety limit
            begin
              chunk = MallocChunk.new(@session, ptr)
              chunks << chunk
              ptr = chunk.fd
            rescue StandardError
              break
            end
          end

          chunks
        end

        def all_fastbin_chunks
          result = {}
          NFASTBINS.times do |i|
            chunks = fastbin_chunks(i)
            result[i] = chunks unless chunks.empty?
          end
          result
        end

        def bin_chunks(index)
          return [] if index >= NBINS

          chunks = []
          # Each bin has fd at bins[2*index] and bk at bins[2*index+1]
          bin_fd = @bins[index * 2]
          @bins[index * 2 + 1]

          # The bin itself is a fake chunk, so we start from bin_fd
          ptr = bin_fd

          while ptr != 0 && chunks.size < 1000
            # Check if we've looped back to the bin
            break if ptr == (@address + bin_offset(index))

            begin
              chunk = MallocChunk.new(@session, ptr)
              chunks << chunk
              ptr = chunk.fd
            rescue StandardError
              break
            end
          end

          chunks
        end

        def unsorted_bin_chunks
          bin_chunks(1)
        end

        def smallbin_chunks(index)
          return [] if index < 2 || index >= NSMALLBINS

          bin_chunks(index)
        end

        def largebin_chunks(index)
          actual_index = NSMALLBINS + index
          return [] if actual_index >= NBINS

          bin_chunks(actual_index)
        end

        def top_chunk
          return nil if @top.zero?

          MallocChunk.new(@session, @top)
        rescue StandardError
          nil
        end

        private

        def bin_offset(index)
          # Calculate offset to bin[index] within malloc_state
          base_offset = 4 + 4 # mutex + flags
          base_offset += 8 if @pointer_size == 8 # alignment padding
          base_offset += NFASTBINS * @pointer_size # fastbins
          base_offset += @pointer_size * 2 # top + last_remainder
          base_offset + (index * 2 * @pointer_size)
        end
      end
    end
  end
end
