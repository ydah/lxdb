# frozen_string_literal: true

require "spec_helper"
require "yaml"

RSpec.describe Lxdb::Commands::GOT do
  subject(:command) { described_class.new(nil) }

  describe "Mach-O binary fixtures" do
    let(:fixture_path) { File.expand_path("../../fixtures/macho/minimal_dyld_info.macho", __dir__) }

    it "parses a checked-in Mach-O fixture with dyld info load commands" do
      expect(command.send(:macho_binary?, fixture_path)).to be(true)

      load_commands = command.send(:macho_binary_load_commands, fixture_path)
      dyld_info = load_commands.find do |load_command|
        load_command[:kind] == :dyld_info ||
        load_command.values.any? { |value| value.to_s.include?("DYLD_INFO") } ||
          load_command.values.include?(0x80000022)
      end

      expect(dyld_info).not_to be_nil
      expect(dyld_info.fetch(:bind_off)).to eq(0x100)
      expect(dyld_info.fetch(:bind_size)).to eq(0x10)
    end
  end

  describe "Mach-O chained pointer corpus" do
    corpus_path = File.expand_path("../../fixtures/macho/chained_pointer_corpus.yml", __dir__)

    YAML.safe_load_file(corpus_path).each do |fixture|
      it "decodes #{fixture.fetch("name")}" do
        result = command.send(
          :macho_decode_chained_pointer,
          fixture.fetch("raw"),
          fixture.fetch("format")
        )
        expected = fixture.fetch("expected")

        expect(result.fetch(:kind)).to eq(expected.fetch("kind"))
        expect(result.fetch(:authenticated)).to eq(expected.fetch("authenticated"))
      end
    end
  end
end
