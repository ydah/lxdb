# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Heap::Glibc::MallocChunk do
  let(:mock_memory) { instance_double(Lxdb::Core::Memory) }
  let(:mock_architecture) { instance_double(Lxdb::Arch::X86_64, pointer_size: 8) }
  let(:mock_session) do
    instance_double(
      Lxdb::Session,
      architecture: mock_architecture,
      memory: mock_memory
    )
  end

  describe "Constants" do
    it "defines PREV_INUSE" do
      expect(Lxdb::Heap::Glibc::Constants::PREV_INUSE).to eq(0x1)
    end

    it "defines IS_MMAPPED" do
      expect(Lxdb::Heap::Glibc::Constants::IS_MMAPPED).to eq(0x2)
    end

    it "defines NON_MAIN_ARENA" do
      expect(Lxdb::Heap::Glibc::Constants::NON_MAIN_ARENA).to eq(0x4)
    end

    it "defines SIZE_BITS" do
      expect(Lxdb::Heap::Glibc::Constants::SIZE_BITS).to eq(0x7)
    end
  end

  describe "initialization" do
    before do
      allow(mock_memory).to receive(:read_pointer).and_return(0)
    end

    it "stores the address" do
      chunk = described_class.new(mock_session, 0x1000)
      expect(chunk.address).to eq(0x1000)
    end
  end

  describe "#real_size" do
    before do
      allow(mock_memory).to receive(:read_pointer).and_return(0x21)
    end

    it "masks out the flag bits" do
      chunk = described_class.new(mock_session, 0x1000)
      expect(chunk.real_size).to eq(0x20)
    end
  end

  describe "#prev_inuse?" do
    before do
      allow(mock_memory).to receive(:read_pointer).and_return(0x91)
    end

    it "returns true when PREV_INUSE flag is set" do
      chunk = described_class.new(mock_session, 0x1000)
      expect(chunk.prev_inuse?).to be true
    end
  end

  describe "#is_mmapped?" do
    before do
      allow(mock_memory).to receive(:read_pointer).and_return(0x92)
    end

    it "returns true when IS_MMAPPED flag is set" do
      chunk = described_class.new(mock_session, 0x1000)
      expect(chunk.is_mmapped?).to be true
    end
  end

  describe "#non_main_arena?" do
    before do
      allow(mock_memory).to receive(:read_pointer).and_return(0x94)
    end

    it "returns true when NON_MAIN_ARENA flag is set" do
      chunk = described_class.new(mock_session, 0x1000)
      expect(chunk.non_main_arena?).to be true
    end
  end

  describe "#user_data_address" do
    before do
      allow(mock_memory).to receive(:read_pointer).and_return(0x21)
    end

    it "returns address after chunk header" do
      chunk = described_class.new(mock_session, 0x1000)
      expect(chunk.user_data_address).to eq(0x1010)
    end
  end

  describe "#user_data_size" do
    before do
      allow(mock_memory).to receive(:read_pointer).and_return(0x91)
    end

    it "returns size minus header" do
      chunk = described_class.new(mock_session, 0x1000)
      expect(chunk.user_data_size).to eq(0x90 - 16)
    end
  end

  describe "#fastbin?" do
    context "with small chunk (64-bit)" do
      before do
        allow(mock_memory).to receive(:read_pointer).and_return(0x21)
      end

      it "returns true for chunks <= 0x80" do
        chunk = described_class.new(mock_session, 0x1000)
        expect(chunk.fastbin?).to be true
      end
    end

    context "with large chunk" do
      before do
        allow(mock_memory).to receive(:read_pointer).and_return(0x100)
      end

      it "returns false for chunks > 0x80" do
        chunk = described_class.new(mock_session, 0x1000)
        expect(chunk.fastbin?).to be false
      end
    end
  end

  describe "#to_s" do
    before do
      allow(mock_memory).to receive(:read_pointer).and_return(0x91)
    end

    it "returns formatted string" do
      chunk = described_class.new(mock_session, 0x1000)
      str = chunk.to_s
      expect(str).to include("0x1000")
      expect(str).to include("0x90")
    end
  end
end
