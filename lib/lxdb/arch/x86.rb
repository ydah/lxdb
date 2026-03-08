# frozen_string_literal: true

module Lxdb
  module Arch
    class X86 < Base
      def name
        "x86"
      end

      def pointer_size
        4
      end

      def general_purpose_registers
        %i[eax ebx ecx edx esi edi ebp esp eip]
      end

      def stack_pointer
        :esp
      end

      def program_counter
        :eip
      end

      def frame_pointer
        :ebp
      end

      def flags_register
        :eflags
      end

      def calling_convention
        {
          # cdecl - all args on stack
          args: [],
          return: :eax,
          callee_saved: %i[ebx esi edi ebp]
        }
      end

      def syscall_convention
        {
          number: :eax,
          args: %i[ebx ecx edx esi edi ebp],
          return: :eax
        }
      end

      def flags_bits
        {
          CF: 0,
          PF: 2,
          AF: 4,
          ZF: 6,
          SF: 7,
          TF: 8,
          IF: 9,
          DF: 10,
          OF: 11
        }
      end
    end
  end
end
