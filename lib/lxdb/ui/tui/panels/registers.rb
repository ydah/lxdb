# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Registers < Base
          def initialize(session, region)
            super(session, region, title: "REGISTERS")
            @previous_registers = {}
          end

          def draw_content
            clear_content

            unless @session.process&.stopped?
              draw_line(0, "(no process)", color: COLOR_YELLOW)
              return
            end

            registers = @session.read_all_registers
            return draw_line(0, "(no registers)", color: COLOR_YELLOW) if registers.empty?

            reg_names = architecture&.general_purpose_registers || []
            content = content_region

            reg_names.each_with_index do |name, idx|
              break if idx >= content[:height]

              value = registers[name] || 0
              prev_value = @previous_registers[name]
              changed = prev_value && prev_value != value

              # Register name
              draw_text(idx, 0, name.to_s.upcase.rjust(4), color: COLOR_BLUE, bold: true)

              # Value
              value_color = if changed
                              COLOR_RED
                            elsif value.zero?
                              COLOR_WHITE
                            else
                              COLOR_CYAN
                            end
              draw_text(idx, 5, format_address(value), color: value_color, bold: changed)

              # Change marker
              draw_text(idx, 0, "*", color: COLOR_RED, bold: true) if changed
            end

            @previous_registers = registers.dup
          end
        end
      end
    end
  end
end
