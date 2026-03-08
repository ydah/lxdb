# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Memory < Base
          BYTES_PER_ROW = 16

          def initialize(session, region)
            super(session, region, title: "Memory")
            @address = nil
            @size = 256
            @scroll_offset = 0
            @highlight_address = nil
            @highlight_size = 0
            @previous_data = nil
          end

          attr_accessor :address, :size, :highlight_address, :highlight_size

          def set_address(addr, size = nil)
            @previous_data = @data if @address == addr
            @address = addr
            @size = size if size
            @scroll_offset = 0
          end

          def scroll_up(lines = 1)
            @scroll_offset = [@scroll_offset - lines, 0].max
          end

          def scroll_down(lines = 1)
            max_offset = (@size / BYTES_PER_ROW) - content_region[:height] + 2
            @scroll_offset = [@scroll_offset + lines, [max_offset, 0].max].min
          end

          def draw_content
            clear_content

            unless @address
              draw_no_address
              return
            end

            @data = read_memory_data
            unless @data
              draw_read_error
              return
            end

            draw_header
            draw_hex_dump
          end

          private

          def read_memory_data
            return nil unless @session.memory

            @session.memory.read(@address, @size)
          rescue StandardError
            nil
          end

          def draw_header
            ptr_size = architecture&.pointer_size || 8
            addr_width = ptr_size * 2 + 2

            header = format("%-#{addr_width}s", "Address")
            BYTES_PER_ROW.times do |i|
              header += format(" %02X", i)
            end
            header += "  ASCII"

            draw_line(0, header, color: COLOR_CYAN, bold: true)
          end

          def draw_hex_dump
            content = content_region
            visible_rows = content[:height] - 1 # ヘッダー分を引く
            ptr_size = architecture&.pointer_size || 8

            start_row = @scroll_offset
            end_row = start_row + visible_rows

            rows = (@data.bytesize.to_f / BYTES_PER_ROW).ceil

            (start_row...end_row).each_with_index do |row, y|
              break if row >= rows

              row_addr = @address + row * BYTES_PER_ROW
              row_data = @data[row * BYTES_PER_ROW, BYTES_PER_ROW] || ""

              draw_hex_row(y + 1, row_addr, row_data, ptr_size)
            end
          end

          def draw_hex_row(y_offset, addr, data, ptr_size)
            x = 0
            addr_width = ptr_size * 2 + 2

            # アドレス
            addr_str = format(architecture&.pointer_format || "0x%016x", addr)
            draw_text(y_offset, x, addr_str, color: COLOR_CYAN)
            x += addr_width + 1

            # 16進数バイト
            BYTES_PER_ROW.times do |i|
              if i < data.bytesize
                byte = data.getbyte(i)
                byte_color = get_byte_color(addr + i, byte, i)
                changed = byte_changed?(addr + i, byte)

                draw_text(y_offset, x, format("%02X", byte), color: byte_color, bold: changed)
              else
                draw_text(y_offset, x, "  ", color: COLOR_WHITE)
              end
              x += 3

              # 8バイトごとにスペースを追加
              if i == 7
                draw_text(y_offset, x - 1, " ", color: COLOR_WHITE)
              end
            end

            # ASCII表示
            x += 1
            ascii_str = data.bytes.map { |b| b >= 32 && b < 127 ? b.chr : "." }.join
            ascii_str.ljust(BYTES_PER_ROW)

            BYTES_PER_ROW.times do |i|
              if i < data.bytesize
                byte = data.getbyte(i)
                char = byte >= 32 && byte < 127 ? byte.chr : "."
                char_color = get_byte_color(addr + i, byte, i)
                draw_text(y_offset, x + i, char, color: char_color)
              else
                draw_text(y_offset, x + i, " ", color: COLOR_WHITE)
              end
            end
          end

          def get_byte_color(addr, byte, _offset)
            # ハイライト範囲内
            if @highlight_address && @highlight_size.positive? && addr >= @highlight_address && addr < @highlight_address + @highlight_size
              return COLOR_YELLOW
            end

            # 値に基づく色分け
            case byte
            when 0x00
              COLOR_WHITE  # NULL
            when 0x20..0x7E
              COLOR_GREEN  # 印字可能文字
            when 0xFF
              COLOR_RED    # 0xFF
            else
              COLOR_MAGENTA # その他
            end
          end

          def byte_changed?(addr, current_byte)
            return false unless @previous_data

            offset = addr - @address
            return false if offset.negative? || offset >= @previous_data.bytesize

            @previous_data.getbyte(offset) != current_byte
          end

          def draw_no_address
            messages = [
              "No address set",
              "",
              "Set memory address with:",
              "  memory <address> [size]",
              "",
              "Examples:",
              "  memory $rsp",
              "  memory 0x7fff0000 128"
            ]

            messages.each_with_index do |msg, i|
              break if i >= content_region[:height]

              draw_line(i, msg.center(content_region[:width]), color: COLOR_CYAN)
            end
          end

          def draw_read_error
            messages = [
              "Memory read error",
              "",
              format("Address: 0x%x", @address),
              format("Size: %d bytes", @size),
              "",
              "Cannot read memory at this address."
            ]

            messages.each_with_index do |msg, i|
              break if i >= content_region[:height]

              draw_line(i, msg.center(content_region[:width]), color: COLOR_RED)
            end
          end
        end
      end
    end
  end
end
