# frozen_string_literal: true

require "spec_helper"

RSpec.describe "LLDB integration", :integration do
  def integration_enabled?
    ENV["LXDB_INTEGRATION"] == "1"
  end

  def command_available?(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
      path = File.join(dir, name)
      File.file?(path) && File.executable?(path)
    end
  end

  before do
    skip "set LXDB_INTEGRATION=1 to run LLDB integration specs" unless integration_enabled?
    skip "lldb is not available on PATH" unless command_available?("lldb")
  end

  it "can invoke the LLDB command-line tool" do
    output = IO.popen(["lldb", "--version"], err: [:child, :out], &:read)

    expect(output).to match(/lldb/i)
  end
end
