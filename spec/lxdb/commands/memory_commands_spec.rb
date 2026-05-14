# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Commands::Search do
  let(:architecture) { instance_double(Lxdb::Arch::X86_64, pointer_size: 8) }
  let(:session) { instance_double(Lxdb::Session, architecture: architecture) }
  subject(:command) { described_class.new(session) }

  describe "#parse_search_args" do
    it "parses typed search options without changing positional arguments" do
      pattern, region, options = command.send(
        :parse_search_args,
        ["0x41414141", "r--", "--type", "u32", "--endian=big", "--limit", "3"]
      )

      expect(pattern).to eq("0x41414141")
      expect(region).to eq("r--")
      expect(options).to include(max_results: 3, type: :u32, endian: :big)
    end

    it "parses alignment and permission filters" do
      pattern, region, options = command.send(
        :parse_search_args,
        ["needle", "--align", "0x10", "--perm", "rw", "--executable"]
      )

      expect(pattern).to eq("needle")
      expect(region).to be_nil
      expect(options).to include(align: 16, permissions: %i[readable writable executable])
    end
  end

  describe "#parse_pattern" do
    it "keeps bytes searches as raw bytes by default" do
      expect(command.send(:parse_pattern, "0x414243", :bytes, :little)).to eq("ABC".b)
    end

    it "packs integer searches with the requested endian" do
      expect(command.send(:parse_pattern, "0x41424344", :u32, :little)).to eq([0x41424344].pack("L<").b)
      expect(command.send(:parse_pattern, "0x41424344", :u32, :big)).to eq([0x41424344].pack("L>").b)
    end

    it "uses the current architecture pointer size for ptr searches" do
      expect(command.send(:parse_pattern, "0x1122334455667788", :ptr, :little))
        .to eq([0x1122334455667788].pack("Q<").b)
    end

    it "rejects out-of-range integer searches" do
      expect do
        command.send(:parse_pattern, "256", :u8, :little)
      end.to raise_error(Lxdb::CommandError, /out of range/)
    end
  end

  describe "#filter_search_regions" do
    it "keeps only regions matching all requested permissions" do
      regions = [
        { permissions: "r--", readable: true, writable: false, executable: false },
        { permissions: "rw-", readable: true, writable: true, executable: false },
        { permissions: "r-x", readable: true, writable: false, executable: true }
      ]

      filtered = command.send(:filter_search_regions, regions, %i[readable executable])

      expect(filtered).to eq([regions[2]])
    end
  end

  describe "#search_region" do
    it "returns only aligned matches when alignment is requested" do
      memory = double("memory")
      read_result = double("read_result", success?: true, data: "AAAA".b)
      region = {
        start: 0x1000,
        end: 0x1004,
        size: 4,
        permissions: "r--",
        readable: true,
        name: "test"
      }

      allow(session).to receive(:memory).and_return(memory)
      allow(memory).to receive(:read_safe).with(0x1000, 4).and_return(read_result)

      matches = command.send(:search_region, region, "A".b, 10, 2)

      expect(matches.map { |match| match[:address] }).to eq([0x1000, 0x1002])
    end
  end
end
