# lxdb

[![Gem Version](https://badge.fury.io/rb/lxdb.svg)](https://badge.fury.io/rb/lxdb)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**lxdb** (LLeXtreme DeBugger) is a powerful, pwndbg-style debugger for Ruby built on top of [lldb-ruby](https://github.com/ydah/lldb-ruby). It provides colorful context displays, heap inspection, exploit development support, and both CLI and TUI interfaces.

## Features

- 🎨 **Colorful Context Display** - pwndbg-style registers, disassembly, stack, and backtrace views
- 🔍 **Heap Analysis** - glibc ptmalloc2 inspection (chunks, arenas, tcache, bins)
- 🛡️ **Exploit Development** - ROP gadget search, pattern generation, checksec
- 🖥️ **Dual Interface** - CLI REPL and curses-based TUI
- 🔌 **Plugin System** - Extensible architecture with Ruby plugins
- 🏗️ **Multi-Architecture** - x86, x86_64, ARM, AArch64, RISC-V support

## Requirements

- Ruby >= 3.0.0
- LLDB (with development headers)
- macOS or Linux

### macOS Setup

```bash
# Install Xcode Command Line Tools (includes LLDB)
xcode-select --install

# Enable developer mode for debugging
sudo DevToolsSecurity -enable
```

### Linux Setup

```bash
# Debian/Ubuntu
sudo apt-get install lldb liblldb-dev

# Fedora
sudo dnf install lldb lldb-devel
```

## Installation

Add to your Gemfile:

```ruby
gem "lxdb"
```

Or install directly:

```bash
gem install lxdb
```

## Quick Start

### CLI Mode

```bash
# Debug a binary
lxdb ./target

# Attach to a running process
lxdb -p 1234

# Execute commands on startup
lxdb -c "break main" -c "run" ./target
```

### TUI Mode

```bash
# Launch with TUI interface
lxdb -t ./target
lxdb --tui ./target
```

### As a Library

```ruby
require "lxdb"

# Start a debugging session
session = Lxdb.start("./target")
session.launch(args: ["arg1", "arg2"])

# Set breakpoints
session.breakpoint_at_name("main")
session.breakpoint_at_address(0x401000)

# Control execution
session.continue
session.step
session.next_line

# Read state
pc = session.read_register("rip")
data = session.read_memory(0x7fff0000, 64)

session.terminate
```

## Commands

### Navigation

| Command | Alias | Description |
|---------|-------|-------------|
| `run [args]` | `r` | Start the program |
| `continue` | `c` | Continue execution |
| `step` | `s` | Step into (source line) |
| `stepi` | `si` | Step into (instruction) |
| `next` | `n` | Step over (source line) |
| `nexti` | `ni` | Step over (instruction) |
| `finish` | `fin` | Run until function returns |

### Breakpoints

| Command | Alias | Description |
|---------|-------|-------------|
| `break <location>` | `b` | Set breakpoint |
| `delete <id>` | `d` | Delete breakpoint |
| `enable <id>` | | Enable breakpoint |
| `disable <id>` | | Disable breakpoint |
| `breakpoints` | `bl` | List breakpoints |

### Memory

| Command | Description |
|---------|-------------|
| `x/<n><fmt><unit> <addr>` | Examine memory (x/16gx $rsp) |
| `telescope <addr> [count]` | Smart pointer chain display |
| `hexdump <addr> <size>` | Hex dump memory region |
| `search <pattern> [region]` | Search memory for pattern; supports `--regex`, `--regex-timeout`, `--encoding`, `--type`, `--align`, and `--perm` filters |

### Context Display

| Command | Description |
|---------|-------------|
| `context` | Show full context (regs, disasm, stack, backtrace) |
| `regs` | Show registers only |
| `disasm [addr] [count]` | Disassembly view |
| `stack [count]` | Stack view |
| `backtrace` / `bt` | Show backtrace |

### Heap (glibc)

| Command | Description |
|---------|-------------|
| `heap [count]` / `heap chunks [arena] [count]` | List heap chunks |
| `heap bins [type] [arena]` | Show bin contents |
| `heap tcache` | Show current thread tcache entries |
| `heap arena [arena]` | Show arena details |
| `heap arenas` | List all arenas |

### Exploit Development

| Command | Description |
|---------|-------------|
| `checksec` | Check binary security features |
| `rop [pattern] [--depth N] [--max N] [--backend auto|lldb|objdump] [--diagnostics]` | Search for ROP gadgets |
| `pattern create <len>` | Create cyclic pattern |
| `pattern offset <value>` | Find pattern offset |
| `vmmap` | Show memory mappings |

### Info

| Command | Description |
|---------|-------------|
| `info registers` | Detailed register info |
| `info mappings` | Memory mappings |
| `info threads` | List threads |
| `info breakpoints` | List breakpoints |

## Batch Mode

```bash
lxdb --batch --command "doctor common"
lxdb ./target --batch --command "help rop"
lxdb ./target --launch --batch --command "rop --max 1" --command "search marker --type string"
lxdb --check-lldb-bindings
```

`--batch` exits after startup commands instead of entering the REPL. `--launch` starts the executable before commands run, so scripted checks can exercise process-backed commands such as `rop`, `got`, and `search`.
`--check-lldb-bindings` is a non-interactive preflight for environments that must run process-backed lxdb integration tests. Set `LXDB_REQUIRE_LLDB_BINDINGS=1` in integration environments to fail instead of skipping those process-backed checks.

## Exploit Tool Diagnostics

`rop --backend auto` prefers `objdump` when available and falls back to LLDB when file-address translation or disassembly boundary validation fails. Use `--backend lldb` to force LLDB.

Mach-O `got` output includes dyld chained fixup metadata: header fields, segment starts, imports, symbol names, and bounded pointer-chain traversal. The traversal limits are configurable with `LXDB_MACHO_*` environment variables when a full dump is needed.
Representative dyld chained pointer formats are decoded for 32-bit, 64-bit, ARM64E, firmware, cache, and kernel-cache styles. Unknown formats are still reported with raw pointer values.

## Testing

```bash
bundle exec rake test
bundle exec rake integration
bundle exec rake ci
```

`rake test` runs the normal unit/spec suite. `rake integration` enables opt-in LLDB integration specs by setting `LXDB_INTEGRATION=1`; specs that need a missing external tool still skip themselves.

Useful environment variables:

| Variable | Description |
|----------|-------------|
| `LXDB_TOOL_TIMEOUT` | External tool timeout in seconds; defaults to `5` |
| `LXDB_TOOL_OUTPUT_LIMIT` | Maximum captured output per external command; defaults to `1048576` bytes |
| `LXDB_REQUIRE_LLDB_BINDINGS` | Require process-backed integration specs to have working LLDB Ruby bindings; defaults to skip-on-missing |
| `LXDB_REGEX_TIMEOUT` | Ruby regex timeout for memory regex search; defaults to `1.0`, use `--no-regex-timeout` per command to disable |
| `LXDB_MACHO_DYLD_ENTRY_LIMIT` | Maximum normalized Mach-O dyld metadata entries; defaults to `128`, set `0` for no limit |
| `LXDB_MACHO_FIXUP_SEGMENT_LIMIT` | Maximum chained-fixup segments parsed; defaults to `256`, set `0` for no limit |
| `LXDB_MACHO_FIXUP_PAGE_LIMIT` | Maximum chained-fixup pages parsed per segment; defaults to `4096`, set `0` for no limit |
| `LXDB_MACHO_FIXUP_IMPORT_LIMIT` | Maximum chained-fixup imports parsed; defaults to `4096`, set `0` for no limit |
| `LXDB_MACHO_FIXUP_POINTER_LIMIT` | Maximum chained pointers traversed; defaults to `4096`, set `0` for no limit |

## Context Display

lxdb provides a pwndbg-style colorful context display:

```
──────────────────────────[ REGISTERS ]──────────────────────────
*RAX  0x0000000000000000
 RBX  0x00007fffffffde38    -> "/home/user/target"
 RCX  0x00007ffff7fa2718    <__libc_csu_fini>
*RSP  0x00007fffffffdd30    -> 0x0000000000000001
*RIP  0x0000555555555149    <main+4>
FLAGS: [ cf pf af ZF sf tf if df of ]

──────────────────────────[ DISASSEMBLY ]────────────────────────
    0x555555555145 <main>:      push   rbp
    0x555555555146 <main+1>:    mov    rbp, rsp
 => 0x555555555149 <main+4>:    mov    edi, 0x1
    0x55555555514e <main+9>:    call   0x555555555030    ; <puts@plt>
    0x555555555153 <main+14>:   mov    eax, 0x0

────────────────────────────[ STACK ]────────────────────────────
   +0|0x7fffffffdd30: 0x0000000000000001 <== $sp
   +8|0x7fffffffdd38: 0x00007fffffffde38 -> 0x00007fffffffe1a8
  +16|0x7fffffffdd40: 0x0000000000000000
```

## TUI Interface

The TUI provides a split-pane interface with:

```
┌─────────────────┬─────────────────┐
│   Registers     │   Disassembly   │
├─────────────────┼─────────────────┤
│   Stack         │   Backtrace     │
├─────────────────┴─────────────────┤
│   Command Input                   │
└───────────────────────────────────┘
```

### Key Bindings

| Key | Function |
|-----|----------|
| `F5` | Run program |
| `F6` | Continue |
| `F10` | Step over |
| `F11` | Step into |
| `F12` / `q` | Quit |

## Plugins

Create custom plugins in `~/.lxdb/plugins/` or `./lxdb_plugins/`:

```ruby
# ~/.lxdb/plugins/my_plugin.rb
module Lxdb
  module Plugins
    class MyPlugin < Base
      plugin name: "my_plugin",
             version: "1.0.0",
             description: "My custom plugin"

      def setup
        register_command "mycommand", description: "My command" do |args, cmd|
          cmd.output("Hello from plugin!")
        end

        on_stop do
          puts "Process stopped!"
        end
      end
    end
  end
end
```

### Plugin API

```ruby
# Available in plugin commands
read_memory(address, size)
read_pointer(address)
read_register(name)
execute_command(cmd)
resolve_symbol(address)
breakpoint_at(location)
step / next_line / continue
current_pc / current_sp
```

## Configuration

Create `~/.lxdbrc` or `.lxdbrc` in your project:

```ruby
# ~/.lxdbrc
Lxdb.configure do |config|
  config.context_sections = [:registers, :disassembly, :stack, :backtrace]
  config.context_width = 100
  config.auto_context = true
  config.show_flags = true
  config.disasm_lines_before = 5
  config.disasm_lines_after = 10
  config.stack_lines = 10
  config.theme = "default"
  config.color_enabled = true
end
```

## Themes

Customize colors in `themes/custom.yml`:

```yaml
banner:
  fg: cyan
  bold: true

register_changed:
  fg: red
  bold: true

mnemonic_call:
  fg: bright_green
  bold: true
```

## Architecture Support

| Architecture | Registers | Status |
|--------------|-----------|--------|
| x86_64 | RAX-R15, RIP, RFLAGS | ✅ Full |
| x86 | EAX-EDI, EIP, EFLAGS | ✅ Full |
| AArch64 | X0-X30, SP, PC, NZCV | ✅ Full |
| ARM | R0-R12, SP, LR, PC, CPSR | ✅ Full |
| RISC-V | x0-x31, PC | ✅ Full |

## Development

```bash
git clone https://github.com/ydah/lxdb.git
cd lxdb
bundle install

# Run tests
bundle exec rspec
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- [pwndbg](https://github.com/pwndbg/pwndbg) - Inspiration for context display and commands
- [GEF](https://github.com/hugsy/gef) - Additional feature inspiration
- [lldb-ruby](https://github.com/ydah/lldb-ruby) - LLDB Ruby bindings

## Tool implementation coverage notes

`Lxdb::Commands.run_external_command` exposes both merged and separated process output. Use `output` when command ordering compatibility matters, and use `stdout`, `stderr`, `stdout_truncated`, and `stderr_truncated` when a caller needs stream-specific diagnostics.

The Mach-O GOT/dyld support is covered by a checked-in binary fixture at `spec/fixtures/macho/minimal_dyld_info.macho` and by `spec/fixtures/macho/chained_pointer_corpus.yml`. The corpus keeps representative chained pointer formats explicit so decoder regressions are visible without depending on host tooling.

`lxdb --check-lldb-bindings` performs an explicit preflight for the LLDB Ruby bindings. Set `LXDB_REQUIRE_LLDB_BINDINGS=1` to make missing bindings fail integration instead of being reported as a pending environment limitation. The `LLDB Ruby bindings` GitHub Actions workflow is intentionally manual so it can be run on a macOS runner with known-good LLDB Ruby bindings.

`ruby-head` is intentionally part of the required CI matrix. Failures there should be triaged as either upstream Ruby regressions or compatibility work in lxdb, not silently ignored as experimental signal.
