# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Arch::AArch64 do
  subject(:arch) { described_class.new }

  describe "#name" do
    it "returns 'aarch64'" do
      expect(arch.name).to eq("aarch64")
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

  describe "#general_purpose_registers" do
    it "includes x0-x30" do
      regs = arch.general_purpose_registers
      expect(regs).to include(:x0, :x1, :x15, :x30)
    end

    it "includes sp and pc" do
      regs = arch.general_purpose_registers
      expect(regs).to include(:sp, :pc)
    end

    it "returns 33 registers" do
      expect(arch.general_purpose_registers.size).to eq(33)
    end
  end

  describe "#stack_pointer" do
    it "returns :sp" do
      expect(arch.stack_pointer).to eq(:sp)
    end
  end

  describe "#program_counter" do
    it "returns :pc" do
      expect(arch.program_counter).to eq(:pc)
    end
  end

  describe "#frame_pointer" do
    it "returns :x29" do
      expect(arch.frame_pointer).to eq(:x29)
    end
  end

  describe "#link_register" do
    it "returns :x30" do
      expect(arch.link_register).to eq(:x30)
    end
  end

  describe "#flags_register" do
    it "returns :nzcv" do
      expect(arch.flags_register).to eq(:nzcv)
    end
  end

  describe "#calling_convention" do
    it "uses AAPCS64 convention" do
      conv = arch.calling_convention
      expect(conv[:args]).to eq(%i[x0 x1 x2 x3 x4 x5 x6 x7])
      expect(conv[:return]).to eq(:x0)
    end

    it "defines callee-saved registers" do
      conv = arch.calling_convention
      expect(conv[:callee_saved]).to include(:x19, :x20, :x29, :x30)
    end
  end

  describe "#syscall_convention" do
    it "uses x8 for syscall number" do
      conv = arch.syscall_convention
      expect(conv[:number]).to eq(:x8)
    end

    it "uses x0 for return value" do
      conv = arch.syscall_convention
      expect(conv[:return]).to eq(:x0)
    end
  end

  describe "#darwin_syscall_convention" do
    it "uses x16 for syscall number on macOS" do
      conv = arch.darwin_syscall_convention
      expect(conv[:number]).to eq(:x16)
    end
  end

  describe "#flags_bits" do
    it "includes NZCV flags" do
      flags = arch.flags_bits
      expect(flags[:N]).to eq(31)
      expect(flags[:Z]).to eq(30)
      expect(flags[:C]).to eq(29)
      expect(flags[:V]).to eq(28)
    end
  end

  describe "#pstate_bits" do
    it "includes exception level bits" do
      pstate = arch.pstate_bits
      expect(pstate[:EL]).to eq(2..3)
    end
  end

  describe "#register_aliases" do
    it "includes fp alias for x29" do
      expect(arch.register_aliases[:fp]).to eq(:x29)
    end

    it "includes lr alias for x30" do
      expect(arch.register_aliases[:lr]).to eq(:x30)
    end
  end

  describe "#word_registers" do
    it "returns w0-w30" do
      regs = arch.word_registers
      expect(regs).to include(:w0, :w15, :w30)
      expect(regs.size).to eq(31)
    end
  end

  describe "#simd_registers" do
    it "includes vector registers" do
      simd = arch.simd_registers
      expect(simd[:vector]).to include(:v0, :v31)
      expect(simd[:double]).to include(:d0, :d31)
    end
  end

  describe "#endian" do
    it "returns :little" do
      expect(arch.endian).to eq(:little)
    end
  end
end
