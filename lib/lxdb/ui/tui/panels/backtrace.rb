# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Backtrace < Base
          def initialize(session, region)
            super(session, region, title: "BACKTRACE")
          end

          def draw_content
            clear_content

            unless @session.process&.stopped?
              draw_line(0, "(no process)", color: COLOR_YELLOW)
              return
            end

            thread = @session.current_thread
            return draw_line(0, "(no thread)", color: COLOR_YELLOW) unless thread

            content = content_region
            num_frames = [thread.num_frames, content[:height]].min

            num_frames.times do |i|
              frame = thread.frame_at_index(i)
              next unless frame&.valid?

              draw_frame(i, frame, is_current: i.zero?)
            end
          end

          private

          def draw_frame(y, frame, is_current: false)
            x = 0

            # Frame number
            frame_str = format("#%-2d", frame.idx)
            draw_text(y, x, frame_str, color: COLOR_BLUE, bold: is_current)
            x += 4

            # Address
            addr_str = format("0x%x", frame.pc)
            draw_text(y, x, addr_str, color: COLOR_CYAN)
            x += addr_str.length + 1

            # Function name
            func_name = frame.function_name || frame.symbol&.name || "???"
            # Truncate function name to fit
            max_func_len = content_region[:width] - x - 2
            if func_name.length > max_func_len && max_func_len.positive?
              func_name = "#{func_name[0...max_func_len - 3]}..."
            end
            draw_text(y, x, func_name, color: COLOR_YELLOW, bold: is_current)
          end
        end
      end
    end
  end
end
