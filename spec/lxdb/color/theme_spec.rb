# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"
require "yaml"

RSpec.describe Lxdb::Color::Theme do
  describe "STYLES" do
    it "defines banner style" do
      expect(described_class::STYLES[:banner]).to eq({ fg: :cyan, bold: true })
    end

    it "defines separator style" do
      expect(described_class::STYLES[:separator]).to eq({ fg: :gray })
    end

    it "defines register_name style" do
      expect(described_class::STYLES[:register_name]).to eq({ fg: :blue, bold: true })
    end

    it "defines error style" do
      expect(described_class::STYLES[:error]).to eq({ fg: :red, bold: true })
    end

    it "defines comment style with italic" do
      expect(described_class::STYLES[:comment]).to eq({ fg: :gray, italic: true })
    end

    it "is frozen" do
      expect(described_class::STYLES).to be_frozen
    end
  end

  describe "#initialize" do
    context "with default styles" do
      subject(:theme) { described_class.new }

      it "uses STYLES as default" do
        expect(theme.styles).to eq(described_class::STYLES)
      end

      it "is enabled by default" do
        expect(theme.enabled).to be true
      end
    end

    context "with custom styles" do
      let(:custom_styles) { { banner: { fg: :red, bold: false } } }
      subject(:theme) { described_class.new(custom_styles) }

      it "uses the provided styles" do
        expect(theme.styles).to eq(custom_styles)
      end
    end
  end

  describe "#enabled=" do
    subject(:theme) { described_class.new }

    it "allows disabling colors" do
      theme.enabled = false
      expect(theme.enabled).to be false
    end

    it "allows enabling colors" do
      theme.enabled = false
      theme.enabled = true
      expect(theme.enabled).to be true
    end
  end

  describe "#colorize" do
    subject(:theme) { described_class.new }

    context "when enabled" do
      it "applies color codes for known style" do
        result = theme.colorize("test", :banner)
        expect(result).to include("\e[")
        expect(result).to include("test")
        expect(result).to end_with("\e[0m")
      end

      it "applies foreground color" do
        result = theme.colorize("test", :separator)
        expect(result).to include("\e[90m")
      end

      it "applies bold style" do
        result = theme.colorize("test", :banner)
        expect(result).to include("1")
      end

      it "applies italic style" do
        result = theme.colorize("test", :comment)
        expect(result).to include("3")
      end

      it "returns plain text for unknown style" do
        result = theme.colorize("test", :unknown_style)
        expect(result).to eq("test")
      end

      it "converts non-string input to string" do
        result = theme.colorize(123, :banner)
        expect(result).to include("123")
      end
    end

    context "when disabled" do
      before { theme.enabled = false }

      it "returns plain text" do
        result = theme.colorize("test", :banner)
        expect(result).to eq("test")
      end

      it "does not include ANSI codes" do
        result = theme.colorize("test", :banner)
        expect(result).not_to include("\e[")
      end

      it "converts non-string input to string" do
        result = theme.colorize(456, :banner)
        expect(result).to eq("456")
      end
    end
  end

  describe "#c" do
    subject(:theme) { described_class.new }

    it "is an alias for colorize" do
      expect(theme.c("test", :banner)).to eq(theme.colorize("test", :banner))
    end
  end

  describe ".current" do
    it "is accessible" do
      expect(described_class.current).to be_a(described_class)
    end

    it "is assignable" do
      original = described_class.current
      new_theme = described_class.new
      described_class.current = new_theme
      expect(described_class.current).to eq(new_theme)
      described_class.current = original
    end
  end

  describe ".load" do
    context "without themes_path" do
      it "returns a theme with default styles" do
        described_class.load("default")
        expect(described_class.current).to be_a(described_class)
        expect(described_class.current.styles).to eq(described_class::STYLES)
      end
    end

    context "with non-existent themes_path" do
      it "returns a theme with default styles" do
        described_class.load("custom", "/nonexistent/path")
        expect(described_class.current.styles).to eq(described_class::STYLES)
      end
    end

    context "with existing theme file" do
      let(:temp_dir) { Dir.mktmpdir }
      let(:theme_file) { File.join(temp_dir, "test.yml") }

      before do
        File.write(theme_file, "banner:\n  fg: red\n")
      end

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it "loads the theme from file" do
        described_class.load("test", temp_dir)
        expect(described_class.current.styles[:banner]).to eq({ fg: "red" })
      end
    end
  end

  describe ".from_file" do
    context "with valid YAML file" do
      let(:temp_file) { Tempfile.new(["theme", ".yml"]) }

      before do
        temp_file.write("banner:\n  fg: magenta\n  bold: true\n")
        temp_file.close
      end

      after do
        temp_file.unlink
      end

      it "loads styles from file" do
        theme = described_class.from_file(temp_file.path)
        expect(theme.styles[:banner]).to eq({ fg: "magenta", bold: true })
      end

      it "keeps default styles for undefined keys" do
        theme = described_class.from_file(temp_file.path)
        expect(theme.styles[:separator]).to eq(described_class::STYLES[:separator])
      end
    end

    context "with invalid YAML file" do
      let(:temp_file) { Tempfile.new(["theme", ".yml"]) }

      before do
        temp_file.write("invalid: yaml: [")
        temp_file.close
      end

      after do
        temp_file.unlink
      end

      it "returns a theme with default styles" do
        theme = described_class.from_file(temp_file.path)
        expect(theme.styles).to eq(described_class::STYLES)
      end
    end
  end
end

RSpec.describe Lxdb::Color do
  describe "ANSI_COLORS" do
    it "defines standard colors" do
      expect(described_class::ANSI_COLORS[:red]).to eq(31)
      expect(described_class::ANSI_COLORS[:green]).to eq(32)
      expect(described_class::ANSI_COLORS[:blue]).to eq(34)
    end

    it "defines bright colors" do
      expect(described_class::ANSI_COLORS[:bright_red]).to eq(91)
      expect(described_class::ANSI_COLORS[:bright_green]).to eq(92)
    end

    it "is frozen" do
      expect(described_class::ANSI_COLORS).to be_frozen
    end
  end

  describe "ANSI_BG_COLORS" do
    it "defines background colors" do
      expect(described_class::ANSI_BG_COLORS[:red]).to eq(41)
      expect(described_class::ANSI_BG_COLORS[:blue]).to eq(44)
    end

    it "is frozen" do
      expect(described_class::ANSI_BG_COLORS).to be_frozen
    end
  end
end
