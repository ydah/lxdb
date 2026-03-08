# frozen_string_literal: true

module Lxdb
  module Plugins
    class Base
      class << self
        attr_reader :plugin_info

        def plugin(name:, version: "1.0.0", description: "", author: "")
          @plugin_info = {
            name: name,
            version: version,
            description: description,
            author: author
          }
          Registry.register(self)
        end
      end

      attr_reader :session

      def initialize(session)
        @session = session
      end

      def setup
        # Override in subclass to initialize plugin
        # Register commands, add context sections, etc.
      end

      def teardown
        # Override in subclass to cleanup
      end

      protected

      # Helper to register a new command
      def register_command(name, aliases: [], description: "", category: :plugin, &block)
        command_class = Class.new(Commands::Base) do
          command name, aliases: aliases, description: description, category: category

          define_method(:execute) do |args|
            block.call(args, self)
          end
        end

        Commands::Registry.register(command_class)
      end

      # Helper to add a context section
      def add_context_section(name, &block)
        context_class = Class.new(Context::Base) do
          define_method(:render) do
            instance_exec(&block)
          end
        end

        session.context_renderer.add_section(name, context_class.new(session))
      end

      # Helper to add a stop handler
      def on_stop(&block)
        session.add_stop_handler(&block)
      end

      # Access to session components
      def process
        session.process
      end

      def target
        session.target
      end

      def memory
        session.memory
      end

      def architecture
        session.architecture
      end

      def output(text)
        puts text
      end

      def colorize(text, style)
        Color::Theme.current.colorize(text, style)
      end
    end
  end
end
