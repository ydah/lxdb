# frozen_string_literal: true

module Lxdb
  module Context
    class Registers < Base
      def initialize(session)
        super
        @previous_registers = {}
      end

      def render
        frame = current_frame
        return nil unless frame

        registers = session.read_all_registers
        output = [banner("REGISTERS")]

        # General purpose registers
        output << render_general_purpose(registers)

        # Flags
        output << render_flags(registers) if config.show_flags

        @previous_registers = registers.dup
        output.compact.join("\n")
      end

      private

      def render_general_purpose(registers)
        reg_names = architecture.general_purpose_registers
        lines = []

        reg_names.each_slice(2) do |pair|
          line_parts = pair.map do |name|
            format_register(name, registers[name])
          end
          lines << line_parts.join("  ")
        end

        lines.join("\n")
      end

      def format_register(name, value)
        value ||= 0
        prev_value = @previous_registers[name]
        changed = prev_value && prev_value != value

        # Register name
        name_str = c(name.to_s.upcase.rjust(4), :register_name)

        # Register value
        value_style = if changed
                        :register_changed
                      elsif value.zero?
                        :register_zero
                      else
                        :register_value
                      end
        value_str = c(format_address(value), value_style)

        # Change indicator
        change_marker = changed ? c("*", :register_changed) : " "

        # Annotation
        annotation = generate_annotation(value)

        "#{change_marker}#{name_str} #{value_str}#{annotation}"
      end

      def generate_annotation(value)
        return "" if value.zero?

        annotations = []

        # Try to resolve symbol
        if (sym = resolve_symbol(value))
          annotations << c(" <#{sym[:name]}>", :symbol)
        elsif (str = try_read_string(value))
          escaped = str.gsub("\n", "\\n").gsub("\t", "\\t")
          annotations << c(" \"#{escaped}\"", :string)
        end

        annotations.join
      end

      def render_flags(registers)
        flags_reg = architecture.flags_register
        flags_value = registers[flags_reg]
        return nil unless flags_value

        flags_bits = architecture.flags_bits
        flags_str = flags_bits.map do |name, bit|
          set = (flags_value & (1 << bit)) != 0
          if set
            c(name.to_s, :flag_set)
          else
            c(name.to_s.downcase, :flag_unset)
          end
        end.join(" ")

        "FLAGS: [ #{flags_str} ]"
      end
    end
  end
end
