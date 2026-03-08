# frozen_string_literal: true

require "reline"

module Lxdb
  module UI
    module CLI
      class REPL
        BANNER = <<~BANNER.freeze
          ╦  ═══╗ ╔═══╗ ╔════╗
          ║     ╚═╝   ╠═╣    ║
          ╩═════╝ ╚═══╝ ╚════╝
          LLeXtreme DeBugger v#{Lxdb::VERSION}
        BANNER

        attr_reader :session

        def initialize(session)
          @session = session
          @theme = Color::Theme.current
          @history = []
          @running = true
        end

        def run
          print_banner
          setup_readline
          main_loop
        end

        private

        def print_banner
          puts @theme.colorize(BANNER, :info)
          puts
        end

        def setup_readline
          Reline.completion_proc = method(:complete)
          Reline.completion_append_character = " "
        end

        def main_loop
          catch(:quit) do
            while @running
              begin
                line = read_line
                break if line.nil?

                next if line.strip.empty?

                @history << line
                execute_line(line)
              rescue Interrupt
                puts "\nInterrupted. Type 'quit' to exit."
              rescue StandardError => e
                puts @theme.colorize("Error: #{e.message}", :error)
                puts e.backtrace.first(5).join("\n") if @session.config.debug
              end
            end
          end

          puts @theme.colorize("Goodbye!", :info)
        end

        def read_line
          prompt = generate_prompt
          Reline.readline(prompt, true)
        end

        def generate_prompt
          process = @session.process
          if process&.stopped?
            frame = @session.current_frame
            location = if frame
                         name = frame.function_name
                         name ? truncate(name, 20) : format("0x%x", frame.pc)
                       else
                         "stopped"
                       end
            @theme.colorize("[lxdb:#{location}]> ", :prompt)
          elsif process&.running?
            @theme.colorize("[lxdb:running]> ", :warning)
          else
            @theme.colorize("[lxdb]> ", :prompt_idle)
          end
        end

        def truncate(str, max_length)
          str.length > max_length ? "#{str[0...max_length - 3]}..." : str
        end

        def execute_line(line)
          # Handle repeat last command with empty line (like GDB)
          if line.strip.empty? && @history.any?
            line = @history.last
          end

          parts = parse_line(line)
          command_name = parts.first
          args = parts[1..] || []

          # Find command in registry
          command_class = Commands::Registry.find(command_name)

          if command_class
            command = command_class.new(@session)
            command.execute(args)
          else
            # Fall back to LLDB command
            result = @session.execute_command(line)
            puts result unless result.nil? || result.empty?
          end
        end

        def parse_line(line)
          # Simple tokenizer - split by spaces but respect quotes
          tokens = []
          current = +""
          in_quotes = false
          quote_char = nil

          line.each_char do |char|
            if in_quotes
              if char == quote_char
                in_quotes = false
                tokens << current unless current.empty?
                current = +""
              else
                current << char
              end
            elsif ['"', "'"].include?(char)
              in_quotes = true
              quote_char = char
            elsif [" ", "\t"].include?(char)
              tokens << current unless current.empty?
              current = +""
            else
              current << char
            end
          end

          tokens << current unless current.empty?
          tokens
        end

        def complete(input)
          # Complete command names
          all_commands = Commands::Registry.command_names
          matches = all_commands.select { |cmd| cmd.start_with?(input) }

          # Also add LLDB commands
          lldb_commands = %w[
            expression print po call frame thread process target
            breakpoint watchpoint memory register script platform
            settings log type language version
          ]
          matches += lldb_commands.select { |cmd| cmd.start_with?(input) }

          matches.uniq.sort
        end
      end
    end
  end
end
