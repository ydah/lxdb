# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Lxdb::Plugins::Loader do
  let(:config) { instance_double(Lxdb::Config, debug: false) }
  let(:session) { instance_double(Lxdb::Session, config: config) }

  before do
    Lxdb::Plugins::Registry.clear
  end

  after do
    Lxdb::Plugins::Registry.clear
  end

  describe "#load_plugin" do
    it "loads a plugin file and instantiates the plugin" do
      Dir.mktmpdir do |dir|
        plugin_path = File.join(dir, "test_plugin.rb")
        File.write(plugin_path, <<~RUBY)
          Class.new(Lxdb::Plugins::Base) do
            plugin name: "test_plugin", version: "1.0.0"
          end
        RUBY

        loader = described_class.new(session, paths: [])

        expect(loader.load_plugin(plugin_path)).to be true
        expect(loader.loaded_plugins.map { |plugin| plugin.class.plugin_info[:name] }).to eq(["test_plugin"])
      end
    end
  end

  describe "#reload_all" do
    it "reloads plugin files from disk" do
      Dir.mktmpdir do |dir|
        plugin_path = File.join(dir, "reloadable_plugin.rb")
        File.write(plugin_path, <<~RUBY)
          Class.new(Lxdb::Plugins::Base) do
            plugin name: "reloadable_plugin", version: "1.0.0"
          end
        RUBY

        loader = described_class.new(session, paths: [dir])
        loader.load_all

        File.write(plugin_path, <<~RUBY)
          Class.new(Lxdb::Plugins::Base) do
            plugin name: "reloadable_plugin", version: "2.0.0"
          end
        RUBY

        loader.reload_all

        expect(loader.loaded_plugins.size).to eq(1)
        expect(loader.loaded_plugins.first.class.plugin_info[:version]).to eq("2.0.0")
      end
    end
  end
end
