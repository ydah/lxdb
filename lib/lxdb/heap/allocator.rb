# frozen_string_literal: true

module Lxdb
  module Heap
    class Allocator
      attr_reader :session

      def initialize(session)
        @session = session
      end

      def detect
        # Try to detect which allocator is in use
        # For now, default to ptmalloc2 (glibc)
        Glibc::Ptmalloc.new(@session)
      end

      def name
        raise NotImplementedError
      end

      def chunks
        raise NotImplementedError
      end

      def bins
        raise NotImplementedError
      end

      def arenas
        raise NotImplementedError
      end

      protected

      def memory
        @session.memory
      end

      def architecture
        @session.architecture
      end

      def pointer_size
        architecture.pointer_size
      end

      def read_pointer(address)
        memory.read_pointer(address)
      end
    end
  end
end
