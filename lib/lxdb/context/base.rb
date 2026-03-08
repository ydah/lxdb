# frozen_string_literal: true

module Lxdb
  module Context
    class Base
      attr_reader :session, :config

      def initialize(session)
        @session = session
        @config = session.config
        @theme = Color::Theme.current
      end

      def render
        raise NotImplementedError, "Subclasses must implement #render"
      end

      protected

      def banner(title)
        width = config.context_width || 80
        title_with_spaces = "[ #{title} ]"
        remaining = width - title_with_spaces.length
        left_padding = remaining / 2
        right_padding = remaining - left_padding

        line = "#{"\u2500" * left_padding}#{title_with_spaces}#{"\u2500" * right_padding}"
        colorize(line, :banner)
      end

      def colorize(text, style)
        @theme.colorize(text, style)
      end

      def c(text, style)
        colorize(text, style)
      end

      def current_frame
        session.current_frame
      end

      def current_thread
        session.current_thread
      end

      def process
        session.process
      end

      def architecture
        session.architecture
      end

      def format_address(address)
        format(architecture.pointer_format, address)
      end

      def valid_pointer?(address)
        session.memory&.valid_pointer?(address)
      end

      def resolve_symbol(address)
        session.resolve_symbol(address)
      end

      def try_read_string(address, max_length: 32)
        return nil unless valid_pointer?(address)

        str = session.read_string(address, max_length: max_length)
        return nil if str.nil? || str.empty?
        return nil unless printable_string?(str)

        str.length > max_length ? "#{str[0...max_length]}..." : str
      rescue StandardError
        nil
      end

      def printable_string?(str)
        return false if str.nil? || str.empty?

        str.bytes.all? { |b| (b >= 0x20 && b <= 0x7E) || [0x09, 0x0A, 0x0D].include?(b) }
      end
    end
  end
end
