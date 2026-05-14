# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "timeout"

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

  def run_lldb_commands(*commands)
    args = ["lldb", "-b"]
    commands.each do |command|
      args.concat(["-o", command])
    end

    Timeout.timeout(10) do
      IO.popen(args, err: [:child, :out], &:read)
    end
  end

  before do
    skip "set LXDB_INTEGRATION=1 to run LLDB integration specs" unless integration_enabled?
    skip "lldb is not available on PATH" unless command_available?("lldb")
  end

  it "can invoke the LLDB command-line tool" do
    output = Timeout.timeout(10) do
      IO.popen(["lldb", "--version"], err: [:child, :out], &:read)
    end

    expect(output).to match(/lldb/i)
  end

  it "can inspect a real target image for GOT/search primitives" do
    target = "/bin/echo"
    skip "#{target} is not executable" unless File.executable?(target)

    output = run_lldb_commands(
      "target create #{target}",
      "image list",
      "image dump sections"
    )

    expect(output).to match(/echo/)
    expect(output).to match(/(?:__TEXT|\.text|Section)/i)
  end

  it "can run the LLDB disassembly primitive used by ROP search" do
    skip "cc is not available on PATH" unless command_available?("cc")

    Dir.mktmpdir do |dir|
      source = File.join(dir, "target.c")
      target = File.join(dir, "target")
      File.write(source, "int main(void) { return 0; }\n")

      compile_output = Timeout.timeout(10) do
        IO.popen(["cc", "-g", "-O0", source, "-o", target], err: [:child, :out], &:read)
      end
      skip "failed to build debug target: #{compile_output}" unless $?.success? && File.executable?(target)

      output = run_lldb_commands(
        "target create #{target}",
        "disassemble -n main -c 1"
      )

      expect(output).to match(/disassembly|0x[0-9a-f]+/i)
    end
  end
end
