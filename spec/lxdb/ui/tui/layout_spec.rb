# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::UI::TUI::Layout do
  before do
    allow(Curses).to receive(:lines).and_return(40)
    allow(Curses).to receive(:cols).and_return(120)
  end

  describe "PRESETS" do
    it "defines default preset" do
      expect(described_class::PRESETS[:default]).to be_a(Hash)
    end

    it "defines wide_disasm preset" do
      expect(described_class::PRESETS[:wide_disasm]).to be_a(Hash)
    end

    it "defines compact preset" do
      expect(described_class::PRESETS[:compact]).to be_a(Hash)
    end

    it "defines source_focus preset" do
      expect(described_class::PRESETS[:source_focus]).to be_a(Hash)
    end

    it "defines memory_view preset" do
      expect(described_class::PRESETS[:memory_view]).to be_a(Hash)
    end
  end

  describe "#initialize" do
    it "creates with default preset" do
      layout = described_class.new
      expect(layout.current_preset).to eq(:default)
    end

    it "creates with specified preset" do
      layout = described_class.new(preset: :wide_disasm)
      expect(layout.current_preset).to eq(:wide_disasm)
    end

    it "calculates regions" do
      layout = described_class.new
      expect(layout.regions).to be_a(Hash)
      expect(layout.regions[:registers]).to be_a(Lxdb::UI::TUI::Region)
    end
  end

  describe "#resize_left_panel" do
    subject(:layout) { described_class.new }

    it "increases left panel width" do
      original = layout.left_width_ratio
      layout.resize_left_panel(0.05)
      expect(layout.left_width_ratio).to be > original
    end

    it "decreases left panel width" do
      original = layout.left_width_ratio
      layout.resize_left_panel(-0.05)
      expect(layout.left_width_ratio).to be < original
    end

    it "clamps to minimum 15%" do
      layout.resize_left_panel(-1.0)
      expect(layout.left_width_ratio).to eq(0.15)
    end

    it "clamps to maximum 60%" do
      layout.resize_left_panel(1.0)
      expect(layout.left_width_ratio).to eq(0.60)
    end
  end

  describe "#resize_top_panel" do
    subject(:layout) { described_class.new }

    it "increases top panel height" do
      original = layout.top_height_ratio
      layout.resize_top_panel(0.05)
      expect(layout.top_height_ratio).to be > original
    end

    it "decreases top panel height" do
      original = layout.top_height_ratio
      layout.resize_top_panel(-0.05)
      expect(layout.top_height_ratio).to be < original
    end

    it "clamps to minimum 20%" do
      layout.resize_top_panel(-1.0)
      expect(layout.top_height_ratio).to eq(0.20)
    end

    it "clamps to maximum 70%" do
      layout.resize_top_panel(1.0)
      expect(layout.top_height_ratio).to eq(0.70)
    end
  end

  describe "#apply_preset" do
    subject(:layout) { described_class.new }

    it "applies a valid preset" do
      expect(layout.apply_preset(:wide_disasm)).to be true
      expect(layout.current_preset).to eq(:wide_disasm)
    end

    it "returns false for invalid preset" do
      expect(layout.apply_preset(:nonexistent)).to be false
    end

    it "updates ratios when applying preset" do
      layout.apply_preset(:compact)
      expect(layout.top_height_ratio).to eq(0.35)
      expect(layout.left_width_ratio).to eq(0.30)
    end
  end

  describe "#next_preset" do
    subject(:layout) { described_class.new }

    it "cycles to next preset" do
      first = layout.current_preset
      layout.next_preset
      expect(layout.current_preset).not_to eq(first)
    end

    it "cycles back to first preset" do
      preset_count = described_class::PRESETS.size
      preset_count.times { layout.next_preset }
      expect(layout.current_preset).to eq(:default)
    end
  end

  describe "#preset_info" do
    subject(:layout) { described_class.new }

    it "returns info for current preset" do
      info = layout.preset_info
      expect(info[:name]).to be_a(String)
      expect(info[:description]).to be_a(String)
    end
  end

  describe "#to_h" do
    subject(:layout) { described_class.new }

    it "serializes layout settings" do
      hash = layout.to_h
      expect(hash[:preset]).to eq(:default)
      expect(hash[:top_height_ratio]).to be_a(Float)
      expect(hash[:left_width_ratio]).to be_a(Float)
    end
  end

  describe ".from_h" do
    it "restores layout from hash" do
      allow(Curses).to receive(:lines).and_return(40)
      allow(Curses).to receive(:cols).and_return(120)

      hash = { preset: :wide_disasm, top_height_ratio: 0.5, left_width_ratio: 0.25 }
      layout = described_class.from_h(hash)

      expect(layout.current_preset).to eq(:wide_disasm)
      expect(layout.top_height_ratio).to eq(0.5)
      expect(layout.left_width_ratio).to eq(0.25)
    end
  end
end

RSpec.describe Lxdb::UI::TUI::Region do
  describe "#initialize" do
    it "stores position and size" do
      region = described_class.new(10, 20, 30, 40)
      expect(region.x).to eq(10)
      expect(region.y).to eq(20)
      expect(region.width).to eq(30)
      expect(region.height).to eq(40)
    end
  end

  describe "#contains?" do
    subject(:region) { described_class.new(10, 10, 20, 20) }

    it "returns true for point inside" do
      expect(region.contains?(15, 15)).to be true
    end

    it "returns true for point on top-left edge" do
      expect(region.contains?(10, 10)).to be true
    end

    it "returns false for point outside right" do
      expect(region.contains?(30, 15)).to be false
    end

    it "returns false for point outside bottom" do
      expect(region.contains?(15, 30)).to be false
    end
  end
end
