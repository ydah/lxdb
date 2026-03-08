# frozen_string_literal: true

module Lxdb
  module Arch
    # RISC-V アーキテクチャサポート
    # RV32I/RV64I 両対応
    class RISCV < Base
      attr_reader :xlen

      # @param xlen [Integer] レジスタ幅 (32 or 64)
      def initialize(xlen: 64)
        super()
        @xlen = xlen
      end

      def name
        xlen == 64 ? "riscv64" : "riscv32"
      end

      def pointer_size
        xlen / 8
      end

      def general_purpose_registers
        # x0-x31 (x0 は常に0)
        (0..31).map { |i| :"x#{i}" }
      end

      def stack_pointer
        :x2  # sp
      end

      def program_counter
        :pc
      end

      def frame_pointer
        :x8  # s0/fp
      end

      def link_register
        :x1  # ra (return address)
      end

      def flags_register
        nil  # RISC-Vには従来のフラグレジスタがない
      end

      def calling_convention
        {
          # RISC-V Calling Convention
          args: %i[x10 x11 x12 x13 x14 x15 x16 x17], # a0-a7
          return: :x10, # a0 (128-bit戻り値は a0:a1)
          callee_saved: %i[x8 x9 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27] # s0-s11
        }
      end

      def syscall_convention
        {
          number: :x17, # a7
          args: %i[x10 x11 x12 x13 x14 x15], # a0-a5
          return: :x10 # a0
        }
      end

      def flags_bits
        # RISC-Vにはフラグレジスタがないため、CSRのmstatusなどを参照
        {}
      end

      # ABI レジスタ名（エイリアス）
      def register_aliases
        {
          zero: :x0,   # Hard-wired zero
          ra: :x1,     # Return address
          sp: :x2,     # Stack pointer
          gp: :x3,     # Global pointer
          tp: :x4,     # Thread pointer
          t0: :x5,     # Temporary
          t1: :x6,
          t2: :x7,
          s0: :x8,     # Saved register / Frame pointer
          fp: :x8,     # Frame pointer (alias for s0)
          s1: :x9,
          a0: :x10,    # Function argument / Return value
          a1: :x11,
          a2: :x12,
          a3: :x13,
          a4: :x14,
          a5: :x15,
          a6: :x16,
          a7: :x17,
          s2: :x18,    # Saved registers
          s3: :x19,
          s4: :x20,
          s5: :x21,
          s6: :x22,
          s7: :x23,
          s8: :x24,
          s9: :x25,
          s10: :x26,
          s11: :x27,
          t3: :x28,    # Temporaries
          t4: :x29,
          t5: :x30,
          t6: :x31
        }
      end

      # 浮動小数点レジスタ (F/D拡張)
      def floating_point_registers
        (0..31).map { |i| :"f#{i}" }
      end

      # 浮動小数点レジスタのABI名
      def fp_register_aliases
        {
          ft0: :f0,  ft1: :f1,  ft2: :f2,  ft3: :f3,
          ft4: :f4,  ft5: :f5,  ft6: :f6,  ft7: :f7,
          fs0: :f8,  fs1: :f9,
          fa0: :f10, fa1: :f11, fa2: :f12, fa3: :f13,
          fa4: :f14, fa5: :f15, fa6: :f16, fa7: :f17,
          fs2: :f18, fs3: :f19, fs4: :f20, fs5: :f21,
          fs6: :f22, fs7: :f23, fs8: :f24, fs9: :f25,
          fs10: :f26, fs11: :f27,
          ft8: :f28, ft9: :f29, ft10: :f30, ft11: :f31
        }
      end

      # CSR (Control and Status Registers)
      def csr_registers
        {
          # User-level CSRs
          ustatus: 0x000,
          uie: 0x004,
          utvec: 0x005,
          uscratch: 0x040,
          uepc: 0x041,
          ucause: 0x042,
          utval: 0x043,
          uip: 0x044,
          # Machine-level CSRs
          mstatus: 0x300,
          misa: 0x301,
          mie: 0x304,
          mtvec: 0x305,
          mscratch: 0x340,
          mepc: 0x341,
          mcause: 0x342,
          mtval: 0x343,
          mip: 0x344
        }
      end

      # サポートされている拡張
      def extensions
        # 実行環境から検出するか、デフォルト値を返す
        %i[I M A F D C] # 一般的なRV64GCの拡張
      end

      # RV32かRV64かを判定
      def rv64?
        xlen == 64
      end

      def rv32?
        xlen == 32
      end

      # Compressed命令 (C拡張) が有効か
      def compressed_extension?
        extensions.include?(:C)
      end
    end

    # RV32用のエイリアス
    class RISCV32 < RISCV
      def initialize
        super(xlen: 32)
      end
    end

    # RV64用のエイリアス
    class RISCV64 < RISCV
      def initialize
        super(xlen: 64)
      end
    end
  end
end
