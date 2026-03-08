# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Arch::ARM do
  subject(:arch) { described_class.new }

  describe "#name" do
    it "returns 'arm'" do
      expect(arch.name).to eq("arm")
    end
  end

  describe "#pointer_size" do
    it "returns 4" do
      expect(arch.pointer_size).to eq(4)
    end
  end

  describe "#pointer_format" do
    it "returns 32-bit hex format" do
      expect(arch.pointer_format).to eq("0x%08x")
    end
  end

  describe "#general_purpose_registers" do
    it "returns ARM registers" do
      regs = arch.general_purpose_registers
      expect(regs).to include(:r0, :r1, :r2, :r3)
      expect(regs).to include(:sp, :lr, :pc)
    end

    it "returns 16 registers" do
      expect(arch.general_purpose_registers.size).to eq(16)
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
    it "returns :r11" do
      expect(arch.frame_pointer).to eq(:r11)
    end
  end

  describe "#flags_register" do
    it "returns :cpsr" do
      expect(arch.flags_register).to eq(:cpsr)
    end
  end

  describe "#calling_convention" do
    it "uses AAPCS convention" do
      conv = arch.calling_convention
      expect(conv[:args]).to eq(%i[r0 r1 r2 r3])
      expect(conv[:return]).to eq(:r0)
    end

    it "defines callee-saved registers" do
      conv = arch.calling_convention
      expect(conv[:callee_saved]).to include(:r4, :r5, :r6, :r7)
    end
  end

  describe "#syscall_convention" do
    it "uses r7 for syscall number" do
      conv = arch.syscall_convention
      expect(conv[:number]).to eq(:r7)
    end

    it "uses r0 for return value" do
      conv = arch.syscall_convention
      expect(conv[:return]).to eq(:r0)
    end
  end

  describe "#flags_bits" do
    it "includes CPSR flags" do
      flags = arch.flags_bits
      expect(flags[:N]).to eq(31)
      expect(flags[:Z]).to eq(30)
      expect(flags[:C]).to eq(29)
      expect(flags[:V]).to eq(28)
      expect(flags[:T]).to eq(5)
    end
  end

  describe "#thumb_mode?" do
    it "returns true when T bit is set" do
      cpsr_with_thumb = 1 << 5
      expect(arch.thumb_mode?(cpsr_with_thumb)).to be true
    end

    it "returns false when T bit is clear" do
      cpsr_arm_mode = 0
      expect(arch.thumb_mode?(cpsr_arm_mode)).to be false
    end
  end

  describe "#register_aliases" do
    it "includes fp alias for r11" do
      expect(arch.register_aliases[:fp]).to eq(:r11)
    end

    it "includes lr alias for r14" do
      expect(arch.register_aliases[:lr]).to eq(:r14)
    end
  end

  describe "#execution_modes" do
    it "includes arm and thumb modes" do
      expect(arch.execution_modes).to eq(%i[arm thumb])
    end
  end

  describe "#endian" do
    it "returns :little" do
      expect(arch.endian).to eq(:little)
    end
  end
end
