# frozen_string_literal: true

module Lxdb
  module Arch
    # AArch64 (ARM64) アーキテクチャサポート
    # AAPCS64 (ARM 64-bit Architecture Procedure Call Standard) 準拠
    # Apple Silicon (M1/M2/M3) 対応
    class AArch64 < Base
      def name
        "aarch64"
      end

      def pointer_size
        8
      end

      def general_purpose_registers
        # x0-x30 + sp + pc
        (0..30).map { |i| :"x#{i}" } + %i[sp pc]
      end

      def stack_pointer
        :sp
      end

      def program_counter
        :pc
      end

      def frame_pointer
        :x29  # fp (frame pointer)
      end

      def link_register
        :x30  # lr (link register)
      end

      def flags_register
        :nzcv # Condition flags (in PSTATE)
      end

      def calling_convention
        {
          # AAPCS64 - ARM 64-bit Architecture Procedure Call Standard
          args: %i[x0 x1 x2 x3 x4 x5 x6 x7], # 最初の8引数はレジスタ
          return: :x0, # 戻り値はx0 (128-bit戻り値はx0:x1)
          callee_saved: %i[x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 x29 x30]
        }
      end

      def syscall_convention
        {
          number: :x8, # システムコール番号
          args: %i[x0 x1 x2 x3 x4 x5],
          return: :x0
        }
      end

      # macOS/iOS (Apple Silicon) 固有のシステムコール規約
      def darwin_syscall_convention
        {
          number: :x16, # macOSではx16がシステムコール番号
          args: %i[x0 x1 x2 x3 x4 x5],
          return: :x0
        }
      end

      def flags_bits
        {
          # NZCV condition flags (in PSTATE)
          N: 31,  # Negative
          Z: 30,  # Zero
          C: 29,  # Carry
          V: 28   # Overflow
        }
      end

      # PSTATE bits
      def pstate_bits
        {
          N: 31,    # Negative
          Z: 30,    # Zero
          C: 29,    # Carry
          V: 28,    # Overflow
          SS: 21,   # Software Step
          IL: 20,   # Illegal Execution State
          D: 9,     # Debug mask
          A: 8,     # SError mask
          I: 7,     # IRQ mask
          F: 6,     # FIQ mask
          EL: 2..3, # Exception Level (EL0-EL3)
          SP: 0     # Stack Pointer select
        }
      end

      # レジスタエイリアス
      def register_aliases
        {
          fp: :x29,  # Frame Pointer
          lr: :x30   # Link Register
        }
      end

      # 32-bit subregisters (w0-w30)
      def word_registers
        (0..30).map { |i| :"w#{i}" }
      end

      # SIMD/FP レジスタ (v0-v31 / q0-q31 / d0-d31 / s0-s31 / h0-h31 / b0-b31)
      def simd_registers
        {
          vector: (0..31).map { |i| :"v#{i}" },   # 128-bit
          quad: (0..31).map { |i| :"q#{i}" },     # 128-bit (legacy name)
          double: (0..31).map { |i| :"d#{i}" },   # 64-bit
          single: (0..31).map { |i| :"s#{i}" },   # 32-bit
          half: (0..31).map { |i| :"h#{i}" },     # 16-bit
          byte: (0..31).map { |i| :"b#{i}" }      # 8-bit
        }
      end

      # Apple Silicon 固有の情報
      def apple_silicon?
        # 実行時にプラットフォームを確認
        RUBY_PLATFORM.include?("darwin") && RUBY_PLATFORM.include?("arm64")
      end

      # PAC (Pointer Authentication Code) サポート
      def pac_enabled?
        # Apple Silicon では通常有効
        apple_silicon?
      end

      # BTI (Branch Target Identification) サポート
      def bti_enabled?
        # 実行環境依存
        false
      end

      # MTE (Memory Tagging Extension) サポート
      def mte_enabled?
        false
      end
    end
  end
end
