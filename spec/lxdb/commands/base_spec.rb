# frozen_string_literal: true

require "spec_helper"

RSpec.describe Lxdb::Commands::Base do
  let(:mock_session) { instance_double(Lxdb::Session, config: Lxdb::Config.new) }

  describe ".command" do
    it "sets command metadata" do
      test_class = Class.new(described_class) do
        command "test_cmd", aliases: ["tc"], description: "Test command", category: :test
      end

      expect(test_class.command_name).to eq("test_cmd")
      expect(test_class.aliases).to eq(["tc"])
      expect(test_class.description).to eq("Test command")
      expect(test_class.category).to eq(:test)
    end
  end

  describe ".argument" do
    it "defines command arguments" do
      test_class = Class.new(described_class) do
        command "test_cmd"
        argument :address, type: :integer, required: true, description: "Memory address"
        argument :count, type: :integer, required: false, default: 10
      end

      expect(test_class.arguments).to be_an(Array)
      expect(test_class.arguments.size).to eq(2)
      expect(test_class.arguments.first[:name]).to eq(:address)
    end
  end

  describe "#initialize" do
    it "stores the session" do
      command = described_class.new(mock_session)
      expect(command.session).to eq(mock_session)
    end
  end

  describe "#execute" do
    it "raises NotImplementedError" do
      command = described_class.new(mock_session)
      expect { command.execute([]) }.to raise_error(NotImplementedError)
    end
  end

  describe "#help" do
    it "returns command help text" do
      test_class = Class.new(described_class) do
        command "mycommand", description: "Does something"
      end

      command = test_class.new(mock_session)
      expect(command.help).to eq("mycommand: Does something")
    end
  end

  describe "#parse_address" do
    let(:command) { described_class.new(mock_session) }

    it "parses hex addresses with 0x prefix" do
      expect(command.send(:parse_address, "0x1234")).to eq(0x1234)
    end

    it "parses uppercase hex addresses" do
      expect(command.send(:parse_address, "0xDEADBEEF")).to eq(0xDEADBEEF)
    end

    it "parses decimal numbers" do
      expect(command.send(:parse_address, "1000")).to eq(1000)
    end

    it "returns nil for nil input" do
      expect(command.send(:parse_address, nil)).to be_nil
    end
  end
end
