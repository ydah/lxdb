# frozen_string_literal: true

module Lxdb
  module Context
    class Renderer
      DEFAULT_SECTIONS = %i[registers disassembly stack backtrace].freeze

      attr_reader :session, :contexts

      def initialize(session)
        @session = session
        @contexts = {
          registers: Registers.new(session),
          disassembly: Disassembly.new(session),
          stack: Stack.new(session),
          backtrace: Backtrace.new(session)
        }
      end

      def render(sections: nil)
        return unless session.process&.stopped?

        sections ||= session.config.context_sections || DEFAULT_SECTIONS

        output = sections.filter_map do |section|
          context = @contexts[section]
          context&.render
        end

        puts output.join("\n\n") unless output.empty?
      end

      def render_section(section)
        context = @contexts[section]
        output = context&.render
        puts output if output
      end

      def on_stop
        render if session.config.auto_context
      end

      def add_section(name, context_instance)
        @contexts[name.to_sym] = context_instance
      end

      def remove_section(name)
        @contexts.delete(name.to_sym)
      end
    end
  end
end
