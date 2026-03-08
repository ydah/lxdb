# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Commands::Registry do
  around do |example|
    original_commands = described_class.commands.dup
    original_aliases = described_class.aliases.dup

    example.run
  ensure
    described_class.instance_variable_set(:@commands, original_commands)
    described_class.instance_variable_set(:@aliases, original_aliases)
  end

  describe ".commands" do
    it "returns a hash" do
      expect(described_class.commands).to be_a(Hash)
    end
  end

  describe ".aliases" do
    it "returns a hash" do
      expect(described_class.aliases).to be_a(Hash)
    end
  end

  describe ".register" do
    after do
      described_class.commands.delete("test_cmd")
      described_class.aliases.delete("tc")
    end

    it "registers a command class" do
      test_class = Class.new(Lxdb::Commands::Base) do
        @command_name = "test_cmd"
        @aliases = ["tc"]

        class << self
          attr_reader :command_name
        end

        class << self
          attr_reader :aliases
        end
      end

      described_class.register(test_class)
      expect(described_class.find("test_cmd")).to eq(test_class)
    end

    it "registers aliases" do
      test_class = Class.new(Lxdb::Commands::Base) do
        @command_name = "test_cmd"
        @aliases = ["tc"]

        class << self
          attr_reader :command_name
        end

        class << self
          attr_reader :aliases
        end
      end

      described_class.register(test_class)
      expect(described_class.find("tc")).to eq(test_class)
    end
  end

  describe ".find" do
    it "finds built-in commands" do
      expect(described_class.find("run")).to eq(Lxdb::Commands::Run)
      expect(described_class.find("r")).to eq(Lxdb::Commands::Run)
    end

    context "with nil" do
      it "returns nil" do
        expect(described_class.find(nil)).to be_nil
      end
    end

    context "with unknown command" do
      it "returns nil" do
        expect(described_class.find("nonexistent_command_xyz")).to be_nil
      end
    end
  end

  describe ".all" do
    it "returns an array" do
      commands = described_class.all
      expect(commands).to be_an(Array)
    end

    it "returns unique command classes" do
      commands = described_class.all
      expect(commands.uniq.size).to eq(commands.size)
    end
  end

  describe ".command_names" do
    it "returns an array" do
      names = described_class.command_names
      expect(names).to be_an(Array)
    end
  end

  describe ".by_category" do
    it "groups commands by category" do
      by_category = described_class.by_category
      expect(by_category).to be_a(Hash)
    end
  end

  describe ".clear" do
    it "clears commands and aliases" do
      described_class.clear
      expect(described_class.commands).to be_empty
      expect(described_class.aliases).to be_empty
    end
  end
end
