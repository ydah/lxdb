# frozen_string_literal: true

module Lxdb
  module Commands
    class Base
      class << self
        attr_accessor :command_name, :aliases, :description, :category, :arguments

        def inherited(subclass)
          super
          Registry.register(subclass)
        end

        def command(name, aliases: [], description: "", category: :general)
          @command_name = name
          @aliases = aliases
          @description = description
          @category = category
          Registry.register(self)
        end

        def argument(name, type: :string, required: true, default: nil, description: "")
          @arguments ||= []
          @arguments << {
            name: name,
            type: type,
            required: required,
            default: default,
            description: description
          }
        end
      end

      attr_reader :session

      def initialize(session)
        @session = session
        @theme = Color::Theme.current
      end

      def execute(args)
        raise NotImplementedError, "Subclasses must implement #execute"
      end

      def help
        "#{self.class.command_name}: #{self.class.description}"
      end

      protected

      def require_target!
        raise CommandError, "No target loaded. Use 'file <path>' to load a binary." unless session.target
      end

      def require_process!
        require_target!
        raise CommandError, "No process running. Use 'run' to start." unless session.process&.valid?
      end

      def require_stopped!
        require_process!
        raise CommandError, "Process is not stopped." unless session.process.stopped?
      end

      def output(text)
        puts text
      end

      def colorize(text, style)
        @theme.colorize(text, style)
      end

      def c(text, style)
        colorize(text, style)
      end

      def parse_address(arg)
        return nil if arg.nil?

        case arg
        when /^0x([0-9a-fA-F]+)$/
          Regexp.last_match(1).to_i(16)
        when /^\$(\w+)$/
          # Register reference
          session.read_register(Regexp.last_match(1).to_sym)
        when /^\d+$/
          arg.to_i
        else
          # Try to resolve as symbol
          # For now, just try parsing as hex without prefix
          arg.to_i(16)
        end
      end

      def format_address(address)
        format(session.architecture.pointer_format, address)
      end
    end
  end
end
