# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Source < Base
          CONTEXT_LINES = 5

          def initialize(session, region)
            super(session, region, title: "Source")
            @current_file = nil
            @current_line = nil
            @file_cache = {}
            @breakpoint_lines = Set.new
          end

          def draw_content
            clear_content
            frame = @session.current_frame
            return draw_no_source unless frame

            source_info = get_source_info(frame)
            return draw_no_source unless source_info

            @current_file = source_info[:file]
            @current_line = source_info[:line]

            lines = load_source_file(@current_file)
            return draw_no_source if lines.empty?

            update_breakpoints
            draw_source_lines(lines, @current_line)
          end

          private

          def get_source_info(frame)
            line_entry = frame.line_entry
            return nil unless line_entry&.valid?

            file_spec = line_entry.file_spec
            return nil unless file_spec&.valid?

            {
              file: file_spec.fullpath || file_spec.filename,
              line: line_entry.line,
              column: line_entry.column
            }
          rescue StandardError
            nil
          end

          def load_source_file(path)
            return @file_cache[path] if @file_cache.key?(path)

            return [] unless path && File.exist?(path)

            lines = File.readlines(path, chomp: true)
            @file_cache[path] = lines
            lines
          rescue StandardError
            []
          end

          def update_breakpoints
            @breakpoint_lines.clear
            return unless @session.target && @current_file

            @session.list_breakpoints.each do |bp|
              next unless bp&.valid?

              bp.num_locations.times do |i|
                loc = bp.location_at_index(i)
                next unless loc&.valid?

                addr = loc.address
                next unless addr&.valid?

                line_entry = addr.line_entry
                next unless line_entry&.valid?

                file_spec = line_entry.file_spec
                next unless file_spec&.valid?

                bp_file = file_spec.fullpath || file_spec.filename
                if bp_file == @current_file
                  @breakpoint_lines.add(line_entry.line)
                end
              end
            end
          rescue StandardError
            # ブレークポイント情報取得失敗は無視
          end

          def draw_source_lines(lines, current_line)
            content = content_region
            visible_lines = content[:height]

            # 現在行を中央に表示
            start_line = [current_line - visible_lines / 2, 1].max
            end_line = [start_line + visible_lines - 1, lines.size].min

            # ファイル名表示
            draw_file_header

            y_offset = 1
            (start_line..end_line).each do |line_num|
              break if y_offset >= visible_lines

              line_content = lines[line_num - 1] || ""
              is_current = line_num == current_line
              has_breakpoint = @breakpoint_lines.include?(line_num)

              draw_source_line(y_offset, line_num, line_content, is_current, has_breakpoint)
              y_offset += 1
            end
          end

          def draw_file_header
            return unless @current_file

            filename = File.basename(@current_file)
            header = " #{filename}:#{@current_line} "
            draw_line(0, header.center(content_region[:width], "─"), color: COLOR_CYAN)
          end

          def draw_source_line(y_offset, line_num, content, is_current, has_breakpoint)
            line_num_width = 6
            marker_width = 3
            code_width = content_region[:width] - line_num_width - marker_width

            # 行番号
            line_num_str = format("%#{line_num_width - 1}d ", line_num)
            draw_text(y_offset, 0, line_num_str, color: COLOR_CYAN)

            # マーカー（現在行/ブレークポイント）
            marker = if is_current && has_breakpoint
                       "B=>"
                     elsif is_current
                       "=>"
                     elsif has_breakpoint
                       " B "
                     else
                       "   "
                     end

            marker_color = if is_current
                             COLOR_GREEN
                           elsif has_breakpoint
                             COLOR_RED
                           else
                             COLOR_WHITE
                           end
            draw_text(y_offset, line_num_width, marker, color: marker_color, bold: is_current || has_breakpoint)

            # ソースコード（シンタックスハイライト付き）
            highlighted_content = highlight_syntax(content, code_width)
            draw_highlighted_line(y_offset, line_num_width + marker_width, highlighted_content, is_current)
          end

          def highlight_syntax(content, max_width)
            truncated = content[0...max_width] || ""

            # 簡易シンタックスハイライト
            tokens = []

            # キーワード、文字列、コメントなどをトークン化
            remaining = truncated
            pos = 0

            while pos < remaining.length
              case remaining[pos..]
              when %r{\A(//.*|#.*)} # 行コメント
                tokens << { text: Regexp.last_match(1), color: COLOR_CYAN }
                pos += Regexp.last_match(1).length
              when /\A("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/ # 文字列
                tokens << { text: Regexp.last_match(1), color: COLOR_GREEN }
                pos += Regexp.last_match(1).length
              when /\A\b(if|else|for|while|return|break|continue|switch|case|default|struct|class|public|private|protected|void|int|char|long|short|unsigned|signed|float|double|bool|const|static|extern|typedef|sizeof|NULL|nullptr|true|false|fn|let|mut|pub|use|mod|impl|trait|enum|match|loop|async|await|def|end|do|module|require|include|unless)\b/
                tokens << { text: Regexp.last_match(1), color: COLOR_YELLOW, bold: true }
                pos += Regexp.last_match(1).length
              when /\A\b(\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|0x[0-9a-fA-F]+)\b/ # 数値
                tokens << { text: Regexp.last_match(1), color: COLOR_MAGENTA }
                pos += Regexp.last_match(1).length
              when /\A([a-zA-Z_]\w*)\s*\(/ # 関数呼び出し
                tokens << { text: Regexp.last_match(1), color: COLOR_BLUE }
                pos += Regexp.last_match(1).length
              else
                # 通常のテキスト（次の特殊トークンまで）
                match = remaining[pos..].match(%r{\A([^"'#/\d\w]+|[a-zA-Z_]\w*|\d+|.)})
                if match
                  tokens << { text: match[1], color: COLOR_WHITE }
                  pos += match[1].length
                else
                  pos += 1
                end
              end
            end

            tokens
          end

          def draw_highlighted_line(y_offset, x_offset, tokens, is_current)
            current_x = x_offset
            content = content_region

            tokens.each do |token|
              break if current_x >= content[:width]

              text = token[:text]
              color = token[:color]
              bold = token[:bold] || is_current

              max_len = content[:width] - current_x
              display_text = text[0...max_len]

              draw_text(y_offset, current_x, display_text, color: color, bold: bold)
              current_x += display_text.length
            end

            # 残りを空白で埋める
            return unless current_x < content[:width]

            remaining = content[:width] - current_x
            draw_text(y_offset, current_x, " " * remaining, color: COLOR_WHITE)
          end

          def draw_no_source
            messages = [
              "No source available",
              "",
              "Source code cannot be displayed.",
              "Possible reasons:",
              "  - No debug symbols",
              "  - Source file not found",
              "  - Process not running"
            ]

            messages.each_with_index do |msg, i|
              draw_line(i, msg.center(content_region[:width]), color: COLOR_CYAN)
            end
          end
        end
      end
    end
  end
end
