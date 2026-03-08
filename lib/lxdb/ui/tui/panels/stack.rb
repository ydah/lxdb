# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Stack < Base
          def initialize(session, region)
            super(session, region, title: "STACK")
          end

          def draw_content
            clear_content

            unless @session.process&.stopped?
              draw_line(0, "(no process)", color: COLOR_YELLOW)
              return
            end

            sp = @session.read_register(architecture&.stack_pointer)
            return draw_line(0, "(no stack pointer)", color: COLOR_YELLOW) unless sp

            pointer_size = architecture&.pointer_size || 8
            content = content_region

            content[:height].times do |i|
              addr = sp + (i * pointer_size)
              draw_stack_entry(i, addr, i.zero?)
            end
          end

          private

          def draw_stack_entry(y, address, is_sp)
            x = 0
            pointer_size = architecture&.pointer_size || 8
            offset = y * pointer_size

            # Offset
            draw_text(y, x, format("%+5d", offset), color: COLOR_WHITE)
            x += 6

            # Address
            addr_str = format_address(address)
            draw_text(y, x, addr_str, color: COLOR_CYAN)
            x += addr_str.length + 1

            # Try to read value
            begin
              value = @session.read_pointer(address)
              value_str = format_address(value)

              value_color = value.zero? ? COLOR_WHITE : COLOR_CYAN
              draw_text(y, x, "-> #{value_str}", color: value_color)
              x += value_str.length + 4

              # SP marker
              if is_sp
                draw_text(y, x, "<=$sp", color: COLOR_GREEN, bold: true)
              end
            rescue StandardError
              draw_text(y, x, "-> (unreadable)", color: COLOR_RED)
            end
          end
        end
      end
    end
  end
end
