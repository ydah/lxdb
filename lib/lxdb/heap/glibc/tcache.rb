# frozen_string_literal: true

module Lxdb
  module Heap
    module Glibc
      class TcachePerthread
        include Constants

        attr_reader :address, :counts, :entries

        def initialize(session, address)
          @session = session
          @address = address
          @pointer_size = session.architecture.pointer_size
          @memory = session.memory
          parse
        end

        def parse
          offset = 0

          # counts array (TCACHE_MAX_BINS bytes, but may be uint16_t in newer glibc)
          @counts = []
          TCACHE_MAX_BINS.times do
            @counts << @memory.read_u8(@address + offset)
            offset += 1
          end

          # Align to pointer size
          offset = (offset + @pointer_size - 1) & ~(@pointer_size - 1)

          # entries array (TCACHE_MAX_BINS pointers)
          @entries = []
          TCACHE_MAX_BINS.times do
            @entries << @memory.read_pointer(@address + offset)
            offset += @pointer_size
          end
        end

        def tcache_chunks(index)
          return [] if index >= TCACHE_MAX_BINS
          return [] if @counts[index].zero?

          chunks = []
          ptr = @entries[index]
          count = @counts[index]

          while ptr != 0 && chunks.size < count && chunks.size < 100
            begin
              chunk = MallocChunk.new(@session, ptr - (@pointer_size * 2))
              chunks << chunk
              # In tcache, the next pointer is stored at the user data area
              ptr = @memory.read_pointer(ptr)
            rescue StandardError
              break
            end
          end

          chunks
        end

        def all_tcache_chunks
          result = {}
          TCACHE_MAX_BINS.times do |i|
            chunks = tcache_chunks(i)
            result[i] = chunks unless chunks.empty?
          end
          result
        end

        def bin_size(index)
          # Calculate the chunk size for a tcache bin index
          min_size = Constants.min_chunk_size(@pointer_size)
          alignment = Constants.malloc_alignment(@pointer_size)
          min_size + (index * alignment)
        end
      end
    end
  end
end
