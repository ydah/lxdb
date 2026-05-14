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

    it "parses string encoding and case-insensitive options" do
      pattern, region, options = command.send(
        :parse_search_args,
        ["needle", "--encoding", "utf16le", "--ignore-case"]
      )

      expect(pattern).to eq("needle")
      expect(region).to be_nil
      expect(options).to include(encoding: :utf16le, ignore_case: true)
    end

    it "parses regex options" do
      pattern, region, options = command.send(
        :parse_search_args,
        ["user_[0-9]+", "--regex", "--ignore-case", "--regex-window", "0x2000", "--regex-stride", "2"]
      )

      expect(pattern).to eq("user_[0-9]+")
      expect(region).to be_nil
      expect(options).to include(regex: true, ignore_case: true, regex_window: 0x2000, regex_stride: 2)
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

    it "encodes string searches with the requested encoding" do
      expect(command.send(:parse_pattern, "AZ", :string, :little, :utf16le))
        .to eq("AZ".encode(Encoding::UTF_16LE).b)
      expect(command.send(:parse_pattern, "AZ", :string, :little, :utf32be))
        .to eq("AZ".encode(Encoding.find("UTF-32BE")).b)
    end
  end

  describe "#build_search_pattern" do
    it "treats non-UTF-8 encoding as string search" do
      pattern = command.send(
        :build_search_pattern,
        "AZ",
        { type: :bytes, endian: :little, encoding: :utf16be, ignore_case: false }
      )

      expect(pattern[:matcher]).to eq("AZ".encode(Encoding::UTF_16BE).b)
      expect(pattern[:preview]).to eq("AZ".encode(Encoding::UTF_16BE).b)
    end

    it "builds a case-insensitive string matcher" do
      pattern = command.send(
        :build_search_pattern,
        "az",
        { type: :string, endian: :little, encoding: :utf8, ignore_case: true }
      )

      expect(pattern[:matcher]).to include(type: :case_insensitive_string, bytesize: 2)
      expect(pattern[:preview]).to eq("az".b)
    end

    it "builds a regex matcher" do
      pattern = command.send(
        :build_search_pattern,
        "user_[0-9]+",
        { type: :bytes, endian: :little, encoding: :utf8, ignore_case: true, regex: true, regex_window: 64 }
      )

      expect(pattern[:matcher]).to include(type: :regex, bytesize: 65, window: 64, preview: "user_[0-9]+".b)
      expect("USER_123").to match(pattern[:matcher][:regex])
    end

    it "builds an encoded regex matcher" do
      pattern = command.send(
        :build_search_pattern,
        "A.B",
        { type: :bytes, endian: :little, encoding: :utf16le, ignore_case: true, regex: true, regex_window: 64 }
      )

      expect(pattern[:matcher]).to include(type: :encoded_regex, encoding: :utf16le, unit_size: 2, stride: 2)
      expect("a1b").to match(pattern[:matcher][:regex])
    end

    it "rejects invalid regex patterns" do
      expect do
        command.send(
          :build_search_pattern,
          "[",
          { type: :bytes, endian: :little, encoding: :utf8, ignore_case: false, regex: true }
        )
      end.to raise_error(Lxdb::CommandError, /Invalid search regex/)
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

    it "finds case-insensitive UTF-16 string matches" do
      memory = double("memory")
      data = "xxAB".encode(Encoding::UTF_16LE).b
      read_result = double("read_result", success?: true, data: data)
      region = {
        start: 0x2000,
        end: 0x2000 + data.bytesize,
        size: data.bytesize,
        permissions: "r--",
        readable: true,
        name: "test"
      }
      pattern = command.send(
        :build_search_pattern,
        "ab",
        { type: :string, endian: :little, encoding: :utf16le, ignore_case: true }
      )

      allow(session).to receive(:memory).and_return(memory)
      allow(memory).to receive(:read_safe).with(0x2000, data.bytesize).and_return(read_result)

      matches = command.send(:search_region, region, pattern[:matcher], 10, 1)

      expect(matches.map { |match| match[:address] }).to eq([0x2004])
    end

    it "finds non-overlapping regex matches" do
      memory = double("memory")
      data = "abc123 def456".b
      read_result = double("read_result", success?: true, data: data)
      region = {
        start: 0x3000,
        end: 0x3000 + data.bytesize,
        size: data.bytesize,
        permissions: "r--",
        readable: true,
        name: "test"
      }
      pattern = command.send(
        :build_search_pattern,
        "\\d+",
        { type: :bytes, endian: :little, encoding: :utf8, ignore_case: false, regex: true }
      )

      allow(session).to receive(:memory).and_return(memory)
      allow(memory).to receive(:read_safe).with(0x3000, data.bytesize).and_return(read_result)

      matches = command.send(:search_region, region, pattern[:matcher], 10, 1)

      expect(matches.map { |match| match[:address] }).to eq([0x3003, 0x300a])
    end

    it "finds encoded regex matches" do
      memory = double("memory")
      data = "xxA1B".encode(Encoding::UTF_16LE).b
      read_result = double("read_result", success?: true, data: data)
      region = {
        start: 0x4000,
        end: 0x4000 + data.bytesize,
        size: data.bytesize,
        permissions: "r--",
        readable: true,
        name: "test"
      }
      pattern = command.send(
        :build_search_pattern,
        "a.b",
        { type: :bytes, endian: :little, encoding: :utf16le, ignore_case: true, regex: true, regex_window: 64 }
      )

      allow(session).to receive(:memory).and_return(memory)
      allow(memory).to receive(:read_safe).with(0x4000, data.bytesize).and_return(read_result)

      matches = command.send(:search_region, region, pattern[:matcher], 10, 1)

      expect(matches.map { |match| match[:address] }).to eq([0x4004])
    end
  end
end
