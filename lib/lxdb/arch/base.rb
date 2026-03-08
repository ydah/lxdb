# frozen_string_literal: true

module Lxdb
  module Arch
    class Base
      class << self
        def for_triple(triple)
          arch_name = triple.to_s.split("-").first.downcase
          case arch_name
          when /x86_64/, /amd64/
            X86_64.new
          when /i[3-6]86/, /x86/
            X86.new
          when /aarch64/, /arm64/
            AArch64.new
          when /armv?\d*/, /arm/
            ARM.new
          when /riscv64/
            RISCV64.new
          when /riscv32/
            RISCV32.new
          when /riscv/
            RISCV.new # デフォルトはRV64
          else
            raise DebuggerError, "Unsupported architecture: #{arch_name}"
          end
        end
      end

      def name
        raise NotImplementedError
      end

      def pointer_size
        raise NotImplementedError
      end

      def endian
        :little
      end

      def general_purpose_registers
        raise NotImplementedError
      end

      def stack_pointer
        raise NotImplementedError
      end

      def program_counter
        raise NotImplementedError
      end

      def frame_pointer
        raise NotImplementedError
      end

      def flags_register
        raise NotImplementedError
      end

      def calling_convention
        raise NotImplementedError
      end

      def syscall_convention
        raise NotImplementedError
      end

      def pointer_format
        pointer_size == 8 ? "0x%016x" : "0x%08x"
      end
    end
  end
end
