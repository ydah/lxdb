# frozen_string_literal: true

module Lxdb
  module Heap
    module Glibc
      class MallocChunk
        include Constants

        attr_reader :address, :prev_size, :size, :fd, :bk, :fd_nextsize, :bk_nextsize

        def initialize(session, address)
          @session = session
          @address = address
          @pointer_size = session.architecture.pointer_size
          @memory = session.memory
          parse
        end

        def parse
          # Read chunk header
          @prev_size = read_field(0)
          @size = read_field(@pointer_size)

          # For free chunks, read forward/backward pointers
          return unless freed?

          user_data_offset = @pointer_size * 2
          @fd = read_field(user_data_offset)
          @bk = read_field(user_data_offset + @pointer_size)

          # Large bins have additional pointers
          return unless large_bin?

          @fd_nextsize = read_field(user_data_offset + @pointer_size * 2)
          @bk_nextsize = read_field(user_data_offset + @pointer_size * 3)
        end

        def real_size
          @size & ~SIZE_BITS
        end

        def prev_inuse?
          (@size & PREV_INUSE) != 0
        end

        def is_mmapped?
          (@size & IS_MMAPPED) != 0
        end

        def non_main_arena?
          (@size & NON_MAIN_ARENA) != 0
        end

        def freed?
          # A chunk is freed if the next chunk's PREV_INUSE bit is not set
          # This is a heuristic - we check if fd/bk look like valid pointers
          return false if real_size < min_chunk_size

          next_chunk_addr = @address + real_size
          begin
            next_size = read_field_at(next_chunk_addr + @pointer_size)
            (next_size & PREV_INUSE).zero?
          rescue StandardError
            false
          end
        end

        def in_use?
          !freed?
        end

        def user_data_address
          @address + (@pointer_size * 2)
        end

        def user_data_size
          real_size - (@pointer_size * 2)
        end

        def fastbin?
          real_size <= fastbin_max_size
        end

        def smallbin?
          !fastbin? && real_size < min_large_size
        end

        def large_bin?
          real_size >= min_large_size
        end

        def next_chunk
          return nil if real_size < min_chunk_size

          next_addr = @address + real_size
          MallocChunk.new(@session, next_addr)
        rescue StandardError
          nil
        end

        def prev_chunk
          return nil if prev_inuse? || @prev_size.zero?

          prev_addr = @address - @prev_size
          MallocChunk.new(@session, prev_addr)
        rescue StandardError
          nil
        end

        def to_s
          flags = []
          flags << "P" if prev_inuse?
          flags << "M" if is_mmapped?
          flags << "N" if non_main_arena?
          flag_str = flags.empty? ? "" : " [#{flags.join}]"

          status = in_use? ? "INUSE" : "FREE"

          format("Chunk @ 0x%x | size: 0x%x (%s)%s", @address, real_size, status, flag_str)
        end

        private

        def read_field(offset)
          read_field_at(@address + offset)
        end

        def read_field_at(addr)
          @memory.read_pointer(addr)
        end

        def min_chunk_size
          Constants.min_chunk_size(@pointer_size)
        end

        def min_large_size
          Constants.min_large_size(@pointer_size)
        end

        def fastbin_max_size
          # Default fastbin max size
          @pointer_size == 8 ? 0x80 : 0x40
        end
      end
    end
  end
end
