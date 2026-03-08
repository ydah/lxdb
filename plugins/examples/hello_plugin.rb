# frozen_string_literal: true

# Example lxdb plugin
# Place this file in ~/.lxdb/plugins/ to auto-load

module Lxdb
  module Plugins
    class HelloPlugin < Base
      plugin name: "hello",
             version: "1.0.0",
             description: "Example plugin that adds a hello command",
             author: "lxdb"

      def setup
        register_command "hello", description: "Say hello", category: :misc do |args, cmd|
          name = args.first || "World"
          cmd.output(cmd.colorize("Hello, #{name}!", :success))
        end

        register_command "whereami", description: "Show current location", category: :misc do |_args, cmd|
          if cmd.session.current_frame
            frame = cmd.session.current_frame
            pc = format("0x%x", frame.pc)
            func = frame.function_name || "???"
            cmd.output(cmd.colorize("You are at #{pc} in #{func}", :info))
          else
            cmd.output(cmd.colorize("No current frame", :warning))
          end
        end
      end
    end
  end
end
