# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Session do
  subject(:session) { described_class.new(config) }

  let(:config) { Lxdb::Config.new }

  describe "#initialize" do
    it "creates a debugger" do
      expect(session.debugger).to be_a(Lxdb::Core::Debugger)
    end

    it "uses provided config" do
      custom_config = Lxdb::Config.new(debug: true)
      custom_session = described_class.new(custom_config)
      expect(custom_session.config.debug).to be true
    end

    it "creates default config if none provided" do
      default_session = described_class.new
      expect(default_session.config).to be_a(Lxdb::Config)
    end

    it "creates a plugin loader" do
      expect(session.plugin_loader).to be_a(Lxdb::Plugins::Loader)
    end
  end

  describe "#config" do
    it "returns the config" do
      expect(session.config).to eq(config)
    end
  end

  describe "#target" do
    it "returns nil when no target loaded" do
      expect(session.target).to be_nil
    end
  end

  describe "#process" do
    it "returns nil when no process" do
      expect(session.process).to be_nil
    end
  end

  describe "#architecture" do
    it "returns nil when no target loaded" do
      expect(session.architecture).to be_nil
    end
  end

  describe "#current_thread" do
    it "returns nil when no process" do
      expect(session.current_thread).to be_nil
    end
  end

  describe "#current_frame" do
    it "returns nil when no process" do
      expect(session.current_frame).to be_nil
    end
  end

  describe "#all_threads" do
    it "returns empty array when no process" do
      expect(session.all_threads).to eq([])
    end
  end

  describe "#thread_count" do
    it "returns 0 when no process" do
      expect(session.thread_count).to eq(0)
    end
  end

  describe "#read_register" do
    it "returns nil when no frame" do
      expect(session.read_register(:rip)).to be_nil
    end
  end

  describe "#read_all_registers" do
    it "returns empty hash when no frame" do
      expect(session.read_all_registers).to eq({})
    end
  end

  describe "#read_memory" do
    it "returns nil when no memory object" do
      expect(session.read_memory(0x1000, 16)).to be_nil
    end
  end

  describe "#resolve_symbol" do
    it "returns nil when no target" do
      expect(session.resolve_symbol(0x1000)).to be_nil
    end
  end

  describe "#add_stop_handler" do
    it "adds a handler" do
      called = false
      session.add_stop_handler { called = true }
      session.on_stop
      expect(called).to be true
    end

    it "can add multiple handlers" do
      calls = []
      session.add_stop_handler { calls << 1 }
      session.add_stop_handler { calls << 2 }
      session.on_stop
      expect(calls).to eq([1, 2])
    end
  end

  describe "#terminate" do
    it "calls terminate on the debugger" do
      expect(session.debugger).to receive(:terminate)
      session.terminate
    end
  end

  describe "private #parse_register_value" do
    it "parses hex values" do
      result = session.send(:parse_register_value, "0x1234")
      expect(result).to eq(0x1234)
    end

    it "parses decimal values" do
      result = session.send(:parse_register_value, "1000")
      expect(result).to eq(1000)
    end

    it "returns 0 for nil" do
      result = session.send(:parse_register_value, nil)
      expect(result).to eq(0)
    end
  end
end
