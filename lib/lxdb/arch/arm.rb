# frozen_string_literal: true

module Lxdb
  module Arch
    # ARM (32-bit) アーキテクチャサポート
    # AAPCS (ARM Architecture Procedure Call Standard) 準拠
    class ARM < Base
      # Thumbモードかどうかを判定するためのCPSRビット
      THUMB_BIT = 5

      def name
        "arm"
      end

      def pointer_size
        4
      end

      def general_purpose_registers
        %i[r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 sp lr pc]
      end

      def stack_pointer
        :sp
      end

      def program_counter
        :pc
      end

      def frame_pointer
        :r11 # ARM EABIではr11がフレームポインタ（fp）
      end

      def flags_register
        :cpsr
      end

      def calling_convention
        {
          # AAPCS - ARM Architecture Procedure Call Standard
          args: %i[r0 r1 r2 r3], # 最初の4引数はレジスタ、残りはスタック
          return: :r0, # 戻り値はr0 (64-bit戻り値はr0:r1)
          callee_saved: %i[r4 r5 r6 r7 r8 r9 r10 r11] # v1-v8
        }
      end

      def syscall_convention
        {
          number: :r7, # システムコール番号
          args: %i[r0 r1 r2 r3 r4 r5 r6],
          return: :r0
        }
      end

      def flags_bits
        {
          # CPSR (Current Program Status Register) のフラグビット
          N: 31,  # Negative
          Z: 30,  # Zero
          C: 29,  # Carry
          V: 28,  # Overflow
          Q: 27,  # Saturation
          T: 5,   # Thumb mode
          I: 7,   # IRQ disable
          F: 6    # FIQ disable
        }
      end

      # Thumbモードかどうかを判定
      def thumb_mode?(cpsr_value)
        (cpsr_value >> THUMB_BIT) & 1 == 1
      end

      # ARM特有のレジスタエイリアス
      def register_aliases
        {
          fp: :r11,   # Frame Pointer
          ip: :r12,   # Intra-Procedure-call scratch register
          sp: :r13,   # Stack Pointer
          lr: :r14,   # Link Register
          pc: :r15    # Program Counter
        }
      end

      # VFP/NEON浮動小数点レジスタ（オプション）
      def floating_point_registers
        # s0-s31 (single precision) または d0-d31 (double precision)
        (0..31).map { |i| :"s#{i}" } + (0..31).map { |i| :"d#{i}" }
      end

      # 実行モード（ARM/Thumb）
      def execution_modes
        %i[arm thumb]
      end
    end
  end
end
