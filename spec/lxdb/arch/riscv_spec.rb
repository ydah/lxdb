# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Arch::RISCV do
  describe "RV64" do
    subject(:arch) { described_class.new(xlen: 64) }

    describe "#name" do
      it "returns 'riscv64'" do
        expect(arch.name).to eq("riscv64")
      end
    end

    describe "#pointer_size" do
      it "returns 8" do
        expect(arch.pointer_size).to eq(8)
      end
    end

    describe "#pointer_format" do
      it "returns 64-bit hex format" do
        expect(arch.pointer_format).to eq("0x%016x")
      end
    end

    describe "#rv64?" do
      it "returns true" do
        expect(arch.rv64?).to be true
      end
    end

    describe "#rv32?" do
      it "returns false" do
        expect(arch.rv32?).to be false
      end
    end
  end

  describe "RV32" do
    subject(:arch) { described_class.new(xlen: 32) }

    describe "#name" do
      it "returns 'riscv32'" do
        expect(arch.name).to eq("riscv32")
      end
    end

    describe "#pointer_size" do
      it "returns 4" do
        expect(arch.pointer_size).to eq(4)
      end
    end

    describe "#rv32?" do
      it "returns true" do
        expect(arch.rv32?).to be true
      end
    end
  end

  describe "common functionality" do
    subject(:arch) { described_class.new }

    describe "#general_purpose_registers" do
      it "returns x0-x31" do
        regs = arch.general_purpose_registers
        expect(regs).to include(:x0, :x1, :x31)
        expect(regs.size).to eq(32)
      end
    end

    describe "#stack_pointer" do
      it "returns :x2" do
        expect(arch.stack_pointer).to eq(:x2)
      end
    end

    describe "#program_counter" do
      it "returns :pc" do
        expect(arch.program_counter).to eq(:pc)
      end
    end

    describe "#frame_pointer" do
      it "returns :x8" do
        expect(arch.frame_pointer).to eq(:x8)
      end
    end

    describe "#link_register" do
      it "returns :x1" do
        expect(arch.link_register).to eq(:x1)
      end
    end

    describe "#flags_register" do
      it "returns nil (RISC-V has no traditional flags register)" do
        expect(arch.flags_register).to be_nil
      end
    end

    describe "#calling_convention" do
      it "uses a0-a7 for arguments" do
        conv = arch.calling_convention
        expect(conv[:args]).to eq(%i[x10 x11 x12 x13 x14 x15 x16 x17])
      end

      it "uses a0 for return value" do
        conv = arch.calling_convention
        expect(conv[:return]).to eq(:x10)
      end

      it "defines callee-saved registers" do
        conv = arch.calling_convention
        expect(conv[:callee_saved]).to include(:x8, :x9, :x18)
      end
    end

    describe "#syscall_convention" do
      it "uses a7 for syscall number" do
        conv = arch.syscall_convention
        expect(conv[:number]).to eq(:x17)
      end

      it "uses a0 for return value" do
        conv = arch.syscall_convention
        expect(conv[:return]).to eq(:x10)
      end
    end

    describe "#register_aliases" do
      it "includes standard ABI names" do
        aliases = arch.register_aliases
        expect(aliases[:zero]).to eq(:x0)
        expect(aliases[:ra]).to eq(:x1)
        expect(aliases[:sp]).to eq(:x2)
        expect(aliases[:fp]).to eq(:x8)
        expect(aliases[:a0]).to eq(:x10)
      end
    end

    describe "#floating_point_registers" do
      it "returns f0-f31" do
        regs = arch.floating_point_registers
        expect(regs).to include(:f0, :f15, :f31)
        expect(regs.size).to eq(32)
      end
    end

    describe "#csr_registers" do
      it "includes machine-level CSRs" do
        csrs = arch.csr_registers
        expect(csrs[:mstatus]).to eq(0x300)
        expect(csrs[:mepc]).to eq(0x341)
      end
    end

    describe "#extensions" do
      it "returns default extensions" do
        expect(arch.extensions).to include(:I, :M, :A, :F, :D, :C)
      end
    end

    describe "#compressed_extension?" do
      it "returns true when C extension is present" do
        expect(arch.compressed_extension?).to be true
      end
    end

    describe "#endian" do
      it "returns :little" do
        expect(arch.endian).to eq(:little)
      end
    end
  end
end

RSpec.describe Lxdb::Arch::RISCV32 do
  subject(:arch) { described_class.new }

  it "is a RISCV with xlen=32" do
    expect(arch.xlen).to eq(32)
    expect(arch.name).to eq("riscv32")
  end
end

RSpec.describe Lxdb::Arch::RISCV64 do
  subject(:arch) { described_class.new }

  it "is a RISCV with xlen=64" do
    expect(arch.xlen).to eq(64)
    expect(arch.name).to eq("riscv64")
  end
end
