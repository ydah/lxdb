# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Plugins::Base do
  let(:mock_session) { instance_double(Lxdb::Session) }

  after do
    Lxdb::Plugins::Registry.clear
  end

  describe ".plugin" do
    it "sets plugin info on the class" do
      expect(described_class).to respond_to(:plugin)
    end

    it "registers subclasses after plugin metadata is defined" do
      plugin_class = Class.new(described_class) do
        plugin name: "registered_plugin", version: "1.0.0"
      end

      expect(Lxdb::Plugins::Registry.find("registered_plugin")).to eq(plugin_class)
    end
  end

  describe ".plugin_info" do
    it "returns nil for base class" do
      expect(described_class.plugin_info).to be_nil
    end
  end

  describe "#initialize" do
    it "stores the session" do
      plugin = described_class.new(mock_session)
      expect(plugin.session).to eq(mock_session)
    end
  end

  describe "#setup" do
    it "can be called without error" do
      plugin = described_class.new(mock_session)
      expect { plugin.setup }.not_to raise_error
    end
  end

  describe "#teardown" do
    it "can be called without error" do
      plugin = described_class.new(mock_session)
      expect { plugin.teardown }.not_to raise_error
    end
  end

  describe "#output" do
    it "prints text to stdout" do
      plugin = described_class.new(mock_session)
      expect { plugin.send(:output, "test output") }.to output("test output\n").to_stdout
    end
  end

  describe "#colorize" do
    it "colorizes text using the current theme" do
      plugin = described_class.new(mock_session)
      result = plugin.send(:colorize, "test", :error)
      expect(result).to include("test")
    end
  end

  describe "helper methods" do
    let(:plugin) { described_class.new(mock_session) }

    it "has process accessor" do
      allow(mock_session).to receive(:process).and_return(nil)
      expect(plugin.send(:process)).to be_nil
    end

    it "has target accessor" do
      allow(mock_session).to receive(:target).and_return(nil)
      expect(plugin.send(:target)).to be_nil
    end

    it "has memory accessor" do
      allow(mock_session).to receive(:memory).and_return(nil)
      expect(plugin.send(:memory)).to be_nil
    end

    it "has architecture accessor" do
      allow(mock_session).to receive(:architecture).and_return(nil)
      expect(plugin.send(:architecture)).to be_nil
    end
  end
end
