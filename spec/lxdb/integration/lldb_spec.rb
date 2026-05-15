# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
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

  def run_lxdb(*args)
    exe = File.expand_path("../../../exe/lxdb", __dir__)
    lib = File.expand_path("../../../lib", __dir__)
    command = [RbConfig.ruby, "-I#{lib}", exe, *args]

    Timeout.timeout(15) do
      IO.popen(command, err: [:child, :out], &:read)
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

  it "can invoke the lxdb CLI without entering the REPL" do
    version = run_lxdb("--version")
    help = run_lxdb("--help")

    expect(version).to match(/lxdb version/i)
    expect(help).to match(/--batch/)
  end

  it "can execute lxdb batch commands end-to-end" do
    output = run_lxdb(
      "--no-color",
      "--batch",
      "--command", "doctor common",
      "--command", "help rop",
      "--command", "help got",
      "--command", "help search"
    )

    expect(output).to match(/External tool diagnostics/)
    expect(output).to match(/^rop$/)
    expect(output).to match(/^got$/)
    expect(output).to match(/^search$/)
  end

  it "can execute lxdb commands against a launched process" do
    skip "cc is not available on PATH" unless command_available?("cc")

    Dir.mktmpdir do |dir|
      source = File.join(dir, "target.c")
      target = File.join(dir, "target")
      File.write(source, <<~C)
        #include <stdio.h>
        volatile const char *marker = "LXDB_E2E_MARKER";
        int main(void) {
          puts((const char *)marker);
          return 0;
        }
      C

      compile_output = Timeout.timeout(10) do
        IO.popen(["cc", "-g", "-O0", source, "-o", target], err: [:child, :out], &:read)
      end
      skip "failed to build debug target: #{compile_output}" unless $?.success? && File.executable?(target)

      output = run_lxdb(
        "--no-color",
        "--launch",
        "--batch",
        "--command", "rop --max 1 --depth 8 --backend lldb --diagnostics",
        "--command", "search LXDB_E2E_MARKER --type string --limit 1",
        "--command", "got",
        target
      )
      skip "lxdb LLDB Ruby bindings are unavailable" if output.match?(/LLDB is not available/i)

      expect(output).to include("> rop --max 1 --depth 8 --backend lldb --diagnostics")
      expect(output).to include("> search LXDB_E2E_MARKER --type string --limit 1")
      expect(output).to include("> got")
      expect(output).not_to match(/(?:NameError|NoMethodError|uninitialized constant|Error:)/)
    end
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
