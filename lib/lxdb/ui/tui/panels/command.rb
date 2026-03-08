# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Command < Base
          def initialize(session, region)
            super(session, region, title: "COMMAND")
          end

          def draw_content
            clear_content
            # The prompt is drawn, and cursor positioned by Application
            draw_text(0, 0, "lxdb> ", color: COLOR_GREEN, bold: true)
          end

          def position_cursor(buffer)
            content = content_region
            prompt_len = 6 # "lxdb> "
            cursor_x = content[:x] + prompt_len + buffer.length
            cursor_y = content[:y]

            # Make sure cursor is within bounds
            max_x = content[:x] + content[:width] - 1
            cursor_x = max_x if cursor_x > max_x

            Curses.setpos(cursor_y, cursor_x)

            # Also draw the current buffer
            max_buffer_len = content[:width] - prompt_len
            display_buffer = buffer.length > max_buffer_len ? buffer[-max_buffer_len..] : buffer

            Curses.setpos(cursor_y, content[:x] + prompt_len)
            Curses.attron(Curses.color_pair(COLOR_WHITE))
            Curses.addstr(display_buffer.ljust(max_buffer_len))
            Curses.attroff(Curses.color_pair(COLOR_WHITE))

            # Reposition cursor
            Curses.setpos(cursor_y, content[:x] + prompt_len + buffer.length)
          end
        end
      end
    end
  end
end
