# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Arch::X86 do
  subject(:arch) { described_class.new }

  describe "#name" do
    it 'returns "x86"' do
      expect(arch.name).to eq("x86")
    end
  end

  describe "#pointer_size" do
    it "returns 4" do
      expect(arch.pointer_size).to eq(4)
    end
  end

  describe "#endian" do
    it "returns :little" do
      expect(arch.endian).to eq(:little)
    end
  end

  describe "#general_purpose_registers" do
    it "returns all 32-bit registers" do
      registers = arch.general_purpose_registers
      expect(registers).to include(:eax, :ebx, :ecx, :edx)
      expect(registers).to include(:esi, :edi, :ebp, :esp)
      expect(registers).to include(:eip)
    end

    it "returns exactly 9 registers" do
      expect(arch.general_purpose_registers.size).to eq(9)
    end
  end

  describe "#stack_pointer" do
    it "returns :esp" do
      expect(arch.stack_pointer).to eq(:esp)
    end
  end

  describe "#program_counter" do
    it "returns :eip" do
      expect(arch.program_counter).to eq(:eip)
    end
  end

  describe "#frame_pointer" do
    it "returns :ebp" do
      expect(arch.frame_pointer).to eq(:ebp)
    end
  end

  describe "#flags_register" do
    it "returns :eflags" do
      expect(arch.flags_register).to eq(:eflags)
    end
  end

  describe "#calling_convention" do
    it "returns cdecl convention" do
      convention = arch.calling_convention
      expect(convention).to be_a(Hash)
    end

    it "has empty args array for cdecl (stack-based)" do
      convention = arch.calling_convention
      expect(convention[:args]).to eq([])
    end

    it "uses eax for return value" do
      convention = arch.calling_convention
      expect(convention[:return]).to eq(:eax)
    end

    it "defines callee-saved registers" do
      convention = arch.calling_convention
      expect(convention[:callee_saved]).to eq(%i[ebx esi edi ebp])
    end
  end

  describe "#syscall_convention" do
    it "returns syscall convention" do
      convention = arch.syscall_convention
      expect(convention).to be_a(Hash)
    end

    it "uses eax for syscall number" do
      convention = arch.syscall_convention
      expect(convention[:number]).to eq(:eax)
    end

    it "uses correct argument registers" do
      convention = arch.syscall_convention
      expect(convention[:args]).to eq(%i[ebx ecx edx esi edi ebp])
    end

    it "uses eax for return value" do
      convention = arch.syscall_convention
      expect(convention[:return]).to eq(:eax)
    end
  end

  describe "#flags_bits" do
    it "returns flags bit positions" do
      flags = arch.flags_bits
      expect(flags).to be_a(Hash)
    end

    it "includes Carry Flag at bit 0" do
      expect(arch.flags_bits[:CF]).to eq(0)
    end

    it "includes Zero Flag at bit 6" do
      expect(arch.flags_bits[:ZF]).to eq(6)
    end

    it "includes Sign Flag at bit 7" do
      expect(arch.flags_bits[:SF]).to eq(7)
    end

    it "includes Overflow Flag at bit 11" do
      expect(arch.flags_bits[:OF]).to eq(11)
    end

    it "includes Direction Flag at bit 10" do
      expect(arch.flags_bits[:DF]).to eq(10)
    end
  end

  describe "#pointer_format" do
    it "returns 32-bit hex format" do
      expect(arch.pointer_format).to eq("0x%08x")
    end
  end
end
