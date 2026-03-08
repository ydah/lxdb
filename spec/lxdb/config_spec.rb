# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Lxdb::Config do
  describe "DEFAULTS" do
    it "includes context_sections" do
      expect(described_class::DEFAULTS[:context_sections]).to eq(%i[registers disassembly stack backtrace])
    end

    it "includes context_width" do
      expect(described_class::DEFAULTS[:context_width]).to eq(80)
    end

    it "includes auto_context" do
      expect(described_class::DEFAULTS[:auto_context]).to be true
    end

    it "includes show_flags" do
      expect(described_class::DEFAULTS[:show_flags]).to be true
    end

    it "includes show_simd" do
      expect(described_class::DEFAULTS[:show_simd]).to be false
    end

    it "includes disasm_lines_before" do
      expect(described_class::DEFAULTS[:disasm_lines_before]).to eq(5)
    end

    it "includes disasm_lines_after" do
      expect(described_class::DEFAULTS[:disasm_lines_after]).to eq(10)
    end

    it "includes stack_lines" do
      expect(described_class::DEFAULTS[:stack_lines]).to eq(10)
    end

    it "includes theme" do
      expect(described_class::DEFAULTS[:theme]).to eq("default")
    end

    it "includes color_enabled" do
      expect(described_class::DEFAULTS[:color_enabled]).to be true
    end

    it "includes debug" do
      expect(described_class::DEFAULTS[:debug]).to be false
    end

    it "is frozen" do
      expect(described_class::DEFAULTS).to be_frozen
    end
  end

  describe "#initialize" do
    context "with no arguments" do
      subject(:config) { described_class.new }

      it "uses default values" do
        expect(config.context_width).to eq(80)
        expect(config.auto_context).to be true
        expect(config.theme).to eq("default")
        expect(config.debug).to be false
      end
    end

    context "with custom options" do
      subject(:config) { described_class.new(context_width: 120, debug: true) }

      it "overrides specified values" do
        expect(config.context_width).to eq(120)
        expect(config.debug).to be true
      end

      it "keeps defaults for unspecified values" do
        expect(config.theme).to eq("default")
        expect(config.auto_context).to be true
      end
    end
  end

  describe "#to_h" do
    subject(:config) { described_class.new(context_width: 100) }

    it "returns a hash" do
      expect(config.to_h).to be_a(Hash)
    end

    it "includes all configuration keys" do
      hash = config.to_h
      described_class::DEFAULTS.each_key do |key|
        expect(hash).to have_key(key)
      end
    end

    it "reflects current values" do
      expect(config.to_h[:context_width]).to eq(100)
    end

    it "includes default values" do
      expect(config.to_h[:theme]).to eq("default")
    end
  end

  describe "attribute accessors" do
    subject(:config) { described_class.new }

    it "allows reading and writing context_width" do
      config.context_width = 200
      expect(config.context_width).to eq(200)
    end

    it "allows reading and writing debug" do
      config.debug = true
      expect(config.debug).to be true
    end

    it "allows reading and writing theme" do
      config.theme = "dark"
      expect(config.theme).to eq("dark")
    end
  end

  describe ".load_from_file" do
    context "when file does not exist" do
      it "returns a new config with defaults" do
        config = described_class.load_from_file("/nonexistent/path.yml")
        expect(config).to be_a(described_class)
        expect(config.context_width).to eq(80)
      end
    end

    context "when file exists and is valid YAML" do
      let(:temp_file) { Tempfile.new(["config", ".yml"]) }

      before do
        temp_file.write({ context_width: 150, debug: true }.transform_keys(&:to_s).to_yaml)
        temp_file.close
      end

      after do
        temp_file.unlink
      end

      it "loads configuration from file" do
        config = described_class.load_from_file(temp_file.path)
        expect(config.context_width).to eq(150)
        expect(config.debug).to be true
      end
    end

    context "when file contains invalid YAML" do
      let(:temp_file) { Tempfile.new(["config", ".yml"]) }

      before do
        temp_file.write("invalid: yaml: content: [")
        temp_file.close
      end

      after do
        temp_file.unlink
      end

      it "returns a new config with defaults" do
        config = described_class.load_from_file(temp_file.path)
        expect(config.context_width).to eq(80)
      end

      it "outputs a warning" do
        expect { described_class.load_from_file(temp_file.path) }.to output(/Warning:/).to_stderr
      end
    end
  end
end
