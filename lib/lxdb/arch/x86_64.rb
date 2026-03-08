# frozen_string_literal: true

module Lxdb
  module Arch
    class X86_64 < Base
      def name
        "x86_64"
      end

      def pointer_size
        8
      end

      def general_purpose_registers
        %i[rax rbx rcx rdx rsi rdi rbp rsp r8 r9 r10 r11 r12 r13 r14 r15 rip]
      end

      def stack_pointer
        :rsp
      end

      def program_counter
        :rip
      end

      def frame_pointer
        :rbp
      end

      def flags_register
        :rflags
      end

      def calling_convention
        {
          # System V AMD64 ABI
          args: %i[rdi rsi rdx rcx r8 r9],
          return: :rax,
          callee_saved: %i[rbx rbp r12 r13 r14 r15]
        }
      end

      def syscall_convention
        {
          number: :rax,
          args: %i[rdi rsi rdx r10 r8 r9],
          return: :rax
        }
      end

      def flags_bits
        {
          CF: 0,   # Carry Flag
          PF: 2,   # Parity Flag
          AF: 4,   # Auxiliary Carry Flag
          ZF: 6,   # Zero Flag
          SF: 7,   # Sign Flag
          TF: 8,   # Trap Flag
          IF: 9,   # Interrupt Enable Flag
          DF: 10,  # Direction Flag
          OF: 11   # Overflow Flag
        }
      end
    end
  end
end
