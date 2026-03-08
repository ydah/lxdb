# frozen_string_literal: true

require "logger"

require_relative "lxdb/version"
require_relative "lxdb/config"
require_relative "lxdb/color/theme"
require_relative "lxdb/arch/base"
require_relative "lxdb/arch/x86_64"
require_relative "lxdb/arch/x86"
require_relative "lxdb/arch/arm"
require_relative "lxdb/arch/aarch64"
require_relative "lxdb/arch/riscv"
require_relative "lxdb/core/debugger"
require_relative "lxdb/core/memory"
require_relative "lxdb/platform/base"
require_relative "lxdb/platform/macos"
require_relative "lxdb/heap/allocator"
require_relative "lxdb/heap/glibc/constants"
require_relative "lxdb/heap/glibc/malloc_chunk"
require_relative "lxdb/heap/glibc/malloc_state"
require_relative "lxdb/heap/glibc/tcache"
require_relative "lxdb/heap/glibc/ptmalloc"
require_relative "lxdb/context/base"
require_relative "lxdb/context/registers"
require_relative "lxdb/context/disassembly"
require_relative "lxdb/context/stack"
require_relative "lxdb/context/backtrace"
require_relative "lxdb/context/renderer"
require_relative "lxdb/commands/base"
require_relative "lxdb/commands/registry"
require_relative "lxdb/plugins/registry"
require_relative "lxdb/plugins/base"
require_relative "lxdb/plugins/api"
require_relative "lxdb/plugins/loader"
require_relative "lxdb/session"
require_relative "lxdb/ui/cli/repl"
require_relative "lxdb/ui/tui/layout"
require_relative "lxdb/ui/tui/panels/base"
require_relative "lxdb/ui/tui/panels/registers"
require_relative "lxdb/ui/tui/panels/disasm"
require_relative "lxdb/ui/tui/panels/stack"
require_relative "lxdb/ui/tui/panels/backtrace"
require_relative "lxdb/ui/tui/panels/command"
require_relative "lxdb/ui/tui/panels/source"
require_relative "lxdb/ui/tui/panels/watch"
require_relative "lxdb/ui/tui/panels/memory"
require_relative "lxdb/ui/tui/application"

module Lxdb
  class Error < StandardError; end
  class CommandError < Error; end
  class DebuggerError < Error; end

  class << self
    attr_accessor :current_session, :logger

    def setup_logger(output = $stderr, level: Logger::WARN)
      @logger = Logger.new(output)
      @logger.level = level
      @logger.formatter = proc { |severity, _time, _progname, msg|
        "[lxdb:#{severity}] #{msg}\n"
      }
      @logger
    end

    def start(executable_path = nil, config: nil)
      config ||= Config.new
      @current_session = Session.new(config)
      @current_session.load_target(executable_path) if executable_path
      @current_session
    end

    def run(executable_path = nil, tui: false)
      session = start(executable_path)
      if tui
        UI::TUI::Application.new(session).run
      else
        UI::CLI::REPL.new(session).run
      end
    ensure
      session&.terminate
    end
  end
end
