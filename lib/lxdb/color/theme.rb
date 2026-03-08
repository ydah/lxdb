# frozen_string_literal: true

module Lxdb
  module Color
    ANSI_COLORS = {
      black: 30, red: 31, green: 32, yellow: 33,
      blue: 34, magenta: 35, cyan: 36, white: 37,
      gray: 90, bright_red: 91, bright_green: 92, bright_yellow: 93,
      bright_blue: 94, bright_magenta: 95, bright_cyan: 96, bright_white: 97
    }.freeze

    ANSI_BG_COLORS = {
      black: 40, red: 41, green: 42, yellow: 43,
      blue: 44, magenta: 45, cyan: 46, white: 47
    }.freeze

    class Theme
      STYLES = {
        # Banner and structure
        banner: { fg: :cyan, bold: true },
        separator: { fg: :gray },

        # Current position indicator
        current_arrow: { fg: :green, bold: true },
        marker: { fg: :yellow, bold: true },

        # Registers
        register_name: { fg: :blue, bold: true },
        register_value: { fg: :white },
        register_changed: { fg: :red, bold: true },
        register_zero: { fg: :gray },

        # Flags
        flag_set: { fg: :green, bold: true },
        flag_unset: { fg: :gray },

        # Disassembly - mnemonics
        mnemonic_branch: { fg: :yellow, bold: true },
        mnemonic_call: { fg: :bright_green, bold: true },
        mnemonic_ret: { fg: :bright_red, bold: true },
        mnemonic_stack: { fg: :magenta },
        mnemonic_data: { fg: :blue },
        mnemonic_compare: { fg: :cyan },
        mnemonic_nop: { fg: :gray },
        mnemonic_syscall: { fg: :bright_yellow, bold: true },
        mnemonic_default: { fg: :white },

        # Disassembly - operands
        operand_register: { fg: :green },
        operand_immediate: { fg: :yellow },
        operand_memory: { fg: :magenta },

        # Addresses and pointers
        address: { fg: :cyan },
        address_code: { fg: :bright_red },
        address_stack: { fg: :bright_yellow },
        address_heap: { fg: :bright_green },
        address_data: { fg: :bright_magenta },

        # Memory values
        pointer: { fg: :cyan },
        value: { fg: :white },
        value_zero: { fg: :gray },
        offset: { fg: :gray },

        # Symbols and strings
        symbol: { fg: :yellow },
        string: { fg: :green },
        comment: { fg: :gray, italic: true },

        # Backtrace
        frame_number: { fg: :blue, bold: true },
        function_name: { fg: :yellow },
        source_location: { fg: :gray },

        # UI elements
        prompt: { fg: :green, bold: true },
        prompt_idle: { fg: :blue },
        error: { fg: :red, bold: true },
        warning: { fg: :yellow },
        info: { fg: :blue },
        success: { fg: :green }
      }.freeze

      class << self
        attr_accessor :current

        def load(name, themes_path = nil)
          @current = if themes_path && File.exist?(File.join(themes_path, "#{name}.yml"))
                       from_file(File.join(themes_path, "#{name}.yml"))
                     else
                       new(STYLES.dup)
                     end
        end

        def from_file(path)
          require "yaml"
          config = YAML.safe_load(File.read(path), symbolize_names: true)
          styles = STYLES.dup
          config.each do |key, value|
            styles[key.to_sym] = value.transform_keys(&:to_sym) if value.is_a?(Hash)
          end
          new(styles)
        rescue StandardError
          new(STYLES.dup)
        end
      end

      attr_reader :styles
      attr_accessor :enabled

      def initialize(styles = STYLES.dup)
        @styles = styles
        @enabled = true
      end

      def colorize(text, style_name)
        return text.to_s unless @enabled

        style = @styles[style_name]
        return text.to_s unless style

        apply_style(text.to_s, style)
      end

      def c(text, style_name)
        colorize(text, style_name)
      end

      private

      def apply_style(text, style)
        codes = []
        codes << ANSI_COLORS[style[:fg]] if style[:fg]
        codes << ANSI_BG_COLORS[style[:bg]] if style[:bg]
        codes << 1 if style[:bold]
        codes << 3 if style[:italic]
        codes << 4 if style[:underline]

        return text if codes.empty?

        "\e[#{codes.join(";")}m#{text}\e[0m"
      end
    end

    # Initialize default theme
    Theme.current = Theme.new
  end
end
