# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Base
          attr_accessor :region
          attr_reader :session, :title

          COLOR_CYAN = 1
          COLOR_GREEN = 2
          COLOR_RED = 3
          COLOR_YELLOW = 4
          COLOR_BLUE = 5
          COLOR_MAGENTA = 6
          COLOR_WHITE = 7

          def initialize(session, region, title: "Panel")
            @session = session
            @region = region
            @title = title
            @scroll_offset = 0
          end

          def draw
            draw_border
            draw_title
            draw_content
          end

          def draw_border
            # Top border
            Curses.setpos(@region.y, @region.x)
            Curses.attron(Curses.color_pair(COLOR_CYAN))
            Curses.addstr("\u250C#{"\u2500" * (@region.width - 2)}\u2510")

            # Side borders
            (@region.height - 2).times do |i|
              Curses.setpos(@region.y + 1 + i, @region.x)
              Curses.addstr("\u2502")
              Curses.setpos(@region.y + 1 + i, @region.x + @region.width - 1)
              Curses.addstr("\u2502")
            end

            # Bottom border
            Curses.setpos(@region.y + @region.height - 1, @region.x)
            Curses.addstr("\u2514#{"\u2500" * (@region.width - 2)}\u2518")
            Curses.attroff(Curses.color_pair(COLOR_CYAN))
          end

          def draw_title
            title_str = "[ #{@title} ]"
            x = @region.x + (@region.width - title_str.length) / 2
            Curses.setpos(@region.y, x)
            Curses.attron(Curses.color_pair(COLOR_CYAN) | Curses::A_BOLD)
            Curses.addstr(title_str)
            Curses.attroff(Curses.color_pair(COLOR_CYAN) | Curses::A_BOLD)
          end

          def draw_content
            # Override in subclasses
          end

          protected

          def content_region
            {
              x: @region.x + 1,
              y: @region.y + 1,
              width: @region.width - 2,
              height: @region.height - 2
            }
          end

          def draw_line(y_offset, text, color: COLOR_WHITE, bold: false)
            content = content_region
            return if y_offset >= content[:height]

            Curses.setpos(content[:y] + y_offset, content[:x])

            attrs = Curses.color_pair(color)
            attrs |= Curses::A_BOLD if bold

            Curses.attron(attrs)
            # Truncate text to fit
            display_text = text[0...content[:width]].ljust(content[:width])
            Curses.addstr(display_text)
            Curses.attroff(attrs)
          end

          def draw_text(y_offset, x_offset, text, color: COLOR_WHITE, bold: false)
            content = content_region
            return if y_offset >= content[:height]

            Curses.setpos(content[:y] + y_offset, content[:x] + x_offset)

            attrs = Curses.color_pair(color)
            attrs |= Curses::A_BOLD if bold

            Curses.attron(attrs)
            max_len = content[:width] - x_offset
            Curses.addstr(text[0...max_len]) if max_len.positive?
            Curses.attroff(attrs)
          end

          def clear_content
            content = content_region
            content[:height].times do |i|
              Curses.setpos(content[:y] + i, content[:x])
              Curses.addstr(" " * content[:width])
            end
          end

          def architecture
            @session.architecture
          end

          def format_address(addr)
            format(architecture&.pointer_format || "0x%016x", addr)
          end
        end
      end
    end
  end
end
