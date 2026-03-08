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

    it "follows semantic versioning format" do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+/)
    end

    it "has the expected value" do
      expect(described_class::VERSION).to eq("0.1.0")
    end
  end
end
