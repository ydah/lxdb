# frozen_string_literal: true

module Lxdb
  module Commands
    class Context < Base
      command "context", aliases: ["ctx"], description: "Show context display", category: :info

      def execute(_args)
        require_stopped!
        session.context_renderer.render
      end
    end

    class Registers < Base
      command "registers", aliases: %w[regs reg], description: "Show registers", category: :info

      def execute(_args)
        require_stopped!
        session.context_renderer.render_section(:registers)
      end
    end

    class Disassemble < Base
      command "disassemble", aliases: %w[disas dis disasm u], description: "Disassemble", category: :info

      def execute(args)
        require_stopped!

        if args.empty?
          session.context_renderer.render_section(:disassembly)
        else
          # Disassemble at specific address
          address = parse_address(args.first)
          count = (args[1] || 20).to_i
          result = session.execute_command("disassemble -s #{address} -c #{count}")
          output(result)
        end
      end
    end

    class Stack < Base
      command "stack", aliases: ["st"], description: "Show stack", category: :info

      def execute(_args)
        require_stopped!
        session.context_renderer.render_section(:stack)
      end
    end

    class Backtrace < Base
      command "backtrace", aliases: %w[bt where], description: "Show backtrace", category: :info

      def execute(_args)
        require_stopped!
        session.context_renderer.render_section(:backtrace)
      end
    end

    class Info < Base
      command "info", aliases: ["i"], description: "Show various information", category: :info

      def execute(args)
        subcommand = args.first
        case subcommand
        when "registers", "reg", "r"
          Registers.new(session).execute([])
        when "breakpoints", "break", "b"
          ListBreakpoints.new(session).execute([])
        when "threads", "thread", "t"
          show_threads
        when "frame", "f"
          show_frame
        when "mappings", "map", "maps", "vmmap"
          show_mappings
        when "target"
          show_target
        else
          show_help
        end
      end

      private

      def show_threads
        require_process!

        output(c("Threads:", :info))
        session.process.num_threads.times do |i|
          thread = session.process.thread_at_index(i)
          next unless thread&.valid?

          selected = thread.index_id == session.current_thread&.index_id
          marker = selected ? c("* ", :current_arrow) : "  "
          frame = thread.selected_frame

          func = frame&.function_name || "???"
          output("#{marker}Thread ##{thread.index_id}: #{func}")
        end
      end

      def show_frame
        require_stopped!

        frame = session.current_frame
        return output(c("No frame selected", :warning)) unless frame

        output(c("Frame ##{frame.idx}:", :info))
        output("  PC: #{c(format_address(frame.pc), :address)}")
        output("  SP: #{c(format_address(frame.sp), :address)}")
        output("  FP: #{c(format_address(frame.fp), :address)}")
        output("  Function: #{c(frame.function_name || "???", :function_name)}")

        return unless frame.line_entry&.valid?

        file = frame.line_entry.file_spec.filename
        line = frame.line_entry.line
        output("  Location: #{c("#{file}:#{line}", :source_location)}")
      end

      def show_target
        target = session.target
        return output(c("No target loaded", :warning)) unless target

        output(c("Target:", :info))
        output("  Path: #{target.executable&.fullpath}")
        output("  Triple: #{target.triple}")
        output("  Architecture: #{session.architecture.name}")
      end

      def show_mappings
        result = session.execute_command("memory region --all")
        if result.to_s.empty?
          output(c("No mapping information available", :warning))
        else
          output(result)
        end
      end

      def show_help
        output(c("info subcommands:", :info))
        output("  info registers  - Show registers")
        output("  info breakpoints - List breakpoints")
        output("  info threads    - List threads")
        output("  info frame      - Show current frame")
        output("  info mappings   - Show memory mappings")
        output("  info target     - Show target info")
      end
    end

    class File < Base
      command "file", aliases: ["target"], description: "Load a binary file", category: :info

      def execute(args)
        path = args.first
        raise CommandError, "Usage: file <path>" unless path

        session.load_target(path)
        output(c("Loaded: #{path}", :success))
        output("Architecture: #{session.architecture.name}")
      end
    end

    class Quit < Base
      command "quit", aliases: %w[q exit], description: "Exit lxdb", category: :info

      def execute(_args)
        throw :quit
      end
    end

    class Help < Base
      command "help", aliases: ["h", "?"], description: "Show help", category: :info

      def execute(args)
        if args.empty?
          show_all_commands
        else
          show_command_help(args.first)
        end
      end

      private

      def show_all_commands
        output(c("lxdb - LLeXtreme DeBugger", :info))
        output("")

        by_category = Registry.by_category
        category_order = %i[navigation breakpoints memory info heap exploit plugin]

        category_order.each do |cat|
          commands = by_category[cat]
          next unless commands && !commands.empty?

          output(c("#{cat.to_s.capitalize}:", :banner))
          commands.each do |cmd|
            name = cmd.command_name.ljust(12)
            aliases = cmd.aliases&.any? ? "(#{cmd.aliases.join(", ")})" : ""
            output("  #{c(name, :function_name)} #{aliases.ljust(15)} #{cmd.description}")
          end
          output("")
        end

        output("Type 'help <command>' for detailed help on a command.")
        output("Commands not recognized are passed to LLDB.")
      end

      def show_command_help(name)
        cmd_class = Registry.find(name)
        if cmd_class
          output(c(cmd_class.command_name, :function_name))
          output("  Aliases: #{cmd_class.aliases&.join(", ") || "none"}")
          output("  Description: #{cmd_class.description}")
          output("  Category: #{cmd_class.category}")
        else
          output(c("Unknown command: #{name}", :error))
        end
      end
    end
  end
end
