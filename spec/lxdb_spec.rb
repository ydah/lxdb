# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb do
  describe "VERSION" do
    it "is defined" do
      expect(described_class::VERSION).not_to be_nil
    end

    it "is a string" do
      expect(described_class::VERSION).to be_a(String)
    end

    it "follows semver format" do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+/)
    end
  end

  describe "Error classes" do
    it "defines Error" do
      expect(described_class::Error).to be < StandardError
    end

    it "defines CommandError" do
      expect(described_class::CommandError).to be < described_class::Error
    end

    it "defines DebuggerError" do
      expect(described_class::DebuggerError).to be < described_class::Error
    end
  end

  describe ".setup_logger" do
    it "creates a logger" do
      output = StringIO.new
      logger = described_class.setup_logger(output)
      expect(logger).to be_a(Logger)
    end

    it "sets the logger accessor" do
      output = StringIO.new
      described_class.setup_logger(output)
      expect(described_class.logger).to be_a(Logger)
    end

    it "uses custom log level" do
      output = StringIO.new
      logger = described_class.setup_logger(output, level: Logger::DEBUG)
      expect(logger.level).to eq(Logger::DEBUG)
    end
  end

  describe ".start" do
    it "creates a session" do
      session = described_class.start
      expect(session).to be_a(Lxdb::Session)
      expect(described_class.current_session).to eq(session)
    end

    it "accepts custom config" do
      config = Lxdb::Config.new(debug: true)
      session = described_class.start(nil, config: config)
      expect(session.config.debug).to be true
    end
  end

  describe "module structure" do
    it "defines Arch module" do
      expect(described_class::Arch).to be_a(Module)
    end

    it "defines Commands module" do
      expect(described_class::Commands).to be_a(Module)
    end

    it "defines Context module" do
      expect(described_class::Context).to be_a(Module)
    end

    it "defines Core module" do
      expect(described_class::Core).to be_a(Module)
    end

    it "defines Heap module" do
      expect(described_class::Heap).to be_a(Module)
    end

    it "defines Plugins module" do
      expect(described_class::Plugins).to be_a(Module)
    end

    it "defines UI module" do
      expect(described_class::UI).to be_a(Module)
    end

    it "defines Color module" do
      expect(described_class::Color).to be_a(Module)
    end
  end
end
