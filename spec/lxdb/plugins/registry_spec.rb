# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Plugins::Registry do
  after do
    described_class.clear
  end

  describe ".plugins" do
    it "returns a hash" do
      expect(described_class.plugins).to be_a(Hash)
    end
  end

  describe ".register" do
    it "registers a plugin class with plugin_info" do
      plugin_class = Class.new do
        def self.plugin_info
          { name: "test_plugin", version: "1.0.0" }
        end
      end

      described_class.register(plugin_class)
      expect(described_class.find("test_plugin")).to eq(plugin_class)
    end

    it "does not register if plugin_info has no name" do
      plugin_class = Class.new do
        def self.plugin_info
          { version: "1.0.0" }
        end
      end

      described_class.register(plugin_class)
      expect(described_class.plugins).to be_empty
    end
  end

  describe ".find" do
    it "returns nil for unknown plugin" do
      expect(described_class.find("nonexistent")).to be_nil
    end

    it "finds registered plugin" do
      plugin_class = Class.new do
        def self.plugin_info
          { name: "findable", version: "1.0.0" }
        end
      end

      described_class.register(plugin_class)
      expect(described_class.find("findable")).to eq(plugin_class)
    end
  end

  describe ".all" do
    it "returns all registered plugins" do
      plugin1 = Class.new do
        def self.plugin_info
          { name: "plugin1", version: "1.0.0" }
        end
      end
      plugin2 = Class.new do
        def self.plugin_info
          { name: "plugin2", version: "1.0.0" }
        end
      end

      described_class.register(plugin1)
      described_class.register(plugin2)
      expect(described_class.all.size).to eq(2)
    end
  end

  describe ".pending_plugins" do
    it "returns plugins added to pending list" do
      plugin_class = Class.new do
        def self.plugin_info
          { name: "pending_test", version: "1.0.0" }
        end
      end

      described_class.register(plugin_class)
      expect(described_class.pending_plugins).to include(plugin_class)
    end
  end

  describe ".clear_pending" do
    it "clears pending plugins list" do
      plugin_class = Class.new do
        def self.plugin_info
          { name: "to_clear", version: "1.0.0" }
        end
      end

      described_class.register(plugin_class)
      described_class.clear_pending
      expect(described_class.pending_plugins).to be_empty
    end
  end

  describe ".clear" do
    it "clears all plugins and pending" do
      plugin_class = Class.new do
        def self.plugin_info
          { name: "to_clear_all", version: "1.0.0" }
        end
      end

      described_class.register(plugin_class)
      described_class.clear
      expect(described_class.plugins).to be_empty
      expect(described_class.pending_plugins).to be_empty
    end
  end
end
