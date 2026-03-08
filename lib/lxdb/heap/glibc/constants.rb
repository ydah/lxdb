# frozen_string_literal: true

module Lxdb
  module Heap
    module Glibc
      # ptmalloc2 constants
      module Constants
        # Chunk flags
        PREV_INUSE = 0x1
        IS_MMAPPED = 0x2
        NON_MAIN_ARENA = 0x4
        SIZE_BITS = PREV_INUSE | IS_MMAPPED | NON_MAIN_ARENA

        # Bin constants
        NBINS = 128
        NSMALLBINS = 64
        NFASTBINS = 10

        # Size thresholds (64-bit)
        MIN_CHUNK_SIZE_64 = 0x20
        MALLOC_ALIGNMENT_64 = 0x10
        MIN_LARGE_SIZE_64 = 0x400

        # Size thresholds (32-bit)
        MIN_CHUNK_SIZE_32 = 0x10
        MALLOC_ALIGNMENT_32 = 0x8
        MIN_LARGE_SIZE_32 = 0x200

        # Tcache constants (glibc 2.26+)
        TCACHE_MAX_BINS = 64
        TCACHE_COUNT = 7

        def self.min_chunk_size(pointer_size)
          pointer_size == 8 ? MIN_CHUNK_SIZE_64 : MIN_CHUNK_SIZE_32
        end

        def self.malloc_alignment(pointer_size)
          pointer_size == 8 ? MALLOC_ALIGNMENT_64 : MALLOC_ALIGNMENT_32
        end

        def self.min_large_size(pointer_size)
          pointer_size == 8 ? MIN_LARGE_SIZE_64 : MIN_LARGE_SIZE_32
        end
      end
    end
  end
end
