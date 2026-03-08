# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Arch::Base do
  describe ".for_triple" do
    context "with x86_64 architecture" do
      it "returns X86_64 for x86_64-linux-gnu" do
        arch = described_class.for_triple("x86_64-linux-gnu")
        expect(arch).to be_a(Lxdb::Arch::X86_64)
      end

      it "returns X86_64 for x86_64-apple-darwin" do
        arch = described_class.for_triple("x86_64-apple-darwin")
        expect(arch).to be_a(Lxdb::Arch::X86_64)
      end

      it "returns X86_64 for amd64-unknown-freebsd" do
        arch = described_class.for_triple("amd64-unknown-freebsd")
        expect(arch).to be_a(Lxdb::Arch::X86_64)
      end
    end

    context "with x86 architecture" do
      it "returns X86 for i386-linux-gnu" do
        arch = described_class.for_triple("i386-linux-gnu")
        expect(arch).to be_a(Lxdb::Arch::X86)
      end

      it "returns X86 for i686-pc-linux-gnu" do
        arch = described_class.for_triple("i686-pc-linux-gnu")
        expect(arch).to be_a(Lxdb::Arch::X86)
      end

      it "returns X86 for x86-unknown" do
        arch = described_class.for_triple("x86-unknown")
        expect(arch).to be_a(Lxdb::Arch::X86)
      end
    end

    context "with unsupported architecture" do
      it "raises DebuggerError" do
        expect { described_class.for_triple("unknown-arch-triple") }
          .to raise_error(Lxdb::DebuggerError, /Unsupported architecture/)
      end
    end

    context "with mixed case" do
      it "handles uppercase x86_64" do
        arch = described_class.for_triple("X86_64-linux-gnu")
        expect(arch).to be_a(Lxdb::Arch::X86_64)
      end
    end
  end

  describe "instance methods" do
    subject(:base) { described_class.new }

    describe "#name" do
      it "raises NotImplementedError" do
        expect { base.name }.to raise_error(NotImplementedError)
      end
    end

    describe "#pointer_size" do
      it "raises NotImplementedError" do
        expect { base.pointer_size }.to raise_error(NotImplementedError)
      end
    end

    describe "#endian" do
      it "returns :little by default" do
        expect(base.endian).to eq(:little)
      end
    end

    describe "#general_purpose_registers" do
      it "raises NotImplementedError" do
        expect { base.general_purpose_registers }.to raise_error(NotImplementedError)
      end
    end

    describe "#stack_pointer" do
      it "raises NotImplementedError" do
        expect { base.stack_pointer }.to raise_error(NotImplementedError)
      end
    end

    describe "#program_counter" do
      it "raises NotImplementedError" do
        expect { base.program_counter }.to raise_error(NotImplementedError)
      end
    end

    describe "#frame_pointer" do
      it "raises NotImplementedError" do
        expect { base.frame_pointer }.to raise_error(NotImplementedError)
      end
    end

    describe "#flags_register" do
      it "raises NotImplementedError" do
        expect { base.flags_register }.to raise_error(NotImplementedError)
      end
    end

    describe "#calling_convention" do
      it "raises NotImplementedError" do
        expect { base.calling_convention }.to raise_error(NotImplementedError)
      end
    end

    describe "#syscall_convention" do
      it "raises NotImplementedError" do
        expect { base.syscall_convention }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "#pointer_format" do
    context "with 8-byte pointer" do
      let(:arch) { Lxdb::Arch::X86_64.new }

      it "returns 16-character hex format" do
        expect(arch.pointer_format).to eq("0x%016x")
      end
    end

    context "with 4-byte pointer" do
      let(:arch) { Lxdb::Arch::X86.new }

      it "returns 8-character hex format" do
        expect(arch.pointer_format).to eq("0x%08x")
      end
    end
  end
end
