# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Arch::X86_64 do
  subject(:arch) { described_class.new }

  describe "#name" do
    it 'returns "x86_64"' do
      expect(arch.name).to eq("x86_64")
    end
  end

  describe "#pointer_size" do
    it "returns 8" do
      expect(arch.pointer_size).to eq(8)
    end
  end

  describe "#endian" do
    it "returns :little" do
      expect(arch.endian).to eq(:little)
    end
  end

  describe "#general_purpose_registers" do
    it "returns all 64-bit registers" do
      registers = arch.general_purpose_registers
      expect(registers).to include(:rax, :rbx, :rcx, :rdx)
      expect(registers).to include(:rsi, :rdi, :rbp, :rsp)
      expect(registers).to include(:r8, :r9, :r10, :r11, :r12, :r13, :r14, :r15)
      expect(registers).to include(:rip)
    end

    it "returns exactly 17 registers" do
      expect(arch.general_purpose_registers.size).to eq(17)
    end
  end

  describe "#stack_pointer" do
    it "returns :rsp" do
      expect(arch.stack_pointer).to eq(:rsp)
    end
  end

  describe "#program_counter" do
    it "returns :rip" do
      expect(arch.program_counter).to eq(:rip)
    end
  end

  describe "#frame_pointer" do
    it "returns :rbp" do
      expect(arch.frame_pointer).to eq(:rbp)
    end
  end

  describe "#flags_register" do
    it "returns :rflags" do
      expect(arch.flags_register).to eq(:rflags)
    end
  end

  describe "#calling_convention" do
    it "returns System V AMD64 ABI convention" do
      convention = arch.calling_convention
      expect(convention).to be_a(Hash)
    end

    it "uses correct argument registers" do
      convention = arch.calling_convention
      expect(convention[:args]).to eq(%i[rdi rsi rdx rcx r8 r9])
    end

    it "uses rax for return value" do
      convention = arch.calling_convention
      expect(convention[:return]).to eq(:rax)
    end

    it "defines callee-saved registers" do
      convention = arch.calling_convention
      expect(convention[:callee_saved]).to eq(%i[rbx rbp r12 r13 r14 r15])
    end
  end

  describe "#syscall_convention" do
    it "returns syscall convention" do
      convention = arch.syscall_convention
      expect(convention).to be_a(Hash)
    end

    it "uses rax for syscall number" do
      convention = arch.syscall_convention
      expect(convention[:number]).to eq(:rax)
    end

    it "uses correct argument registers" do
      convention = arch.syscall_convention
      expect(convention[:args]).to eq(%i[rdi rsi rdx r10 r8 r9])
    end

    it "uses rax for return value" do
      convention = arch.syscall_convention
      expect(convention[:return]).to eq(:rax)
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
    it "returns 64-bit hex format" do
      expect(arch.pointer_format).to eq("0x%016x")
    end
  end
end
