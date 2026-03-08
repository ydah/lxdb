# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Watch < Base
          def initialize(session, region)
            super(session, region, title: "Watch")
            @expressions = []
            @values = {}
            @previous_values = {}
          end

          def add_expression(expr)
            return false if @expressions.include?(expr)

            @expressions << expr
            evaluate_expression(expr)
            true
          end

          def remove_expression(expr)
            @expressions.delete(expr)
            @values.delete(expr)
            @previous_values.delete(expr)
          end

          def remove_at(index)
            return false if index.negative? || index >= @expressions.size

            expr = @expressions.delete_at(index)
            @values.delete(expr)
            @previous_values.delete(expr)
            true
          end

          def clear_all
            @expressions.clear
            @values.clear
            @previous_values.clear
          end

          def expressions
            @expressions.dup
          end

          def update_all
            @previous_values = @values.dup
            @expressions.each { |expr| evaluate_expression(expr) }
          end

          def draw_content
            clear_content
            update_all

            if @expressions.empty?
              draw_empty_message
              return
            end

            visible_lines = content_region[:height]
            @expressions.each_with_index do |expr, i|
              break if i >= visible_lines

              draw_watch_entry(i, expr)
            end
          end

          private

          def evaluate_expression(expr)
            frame = @session.current_frame
            unless frame
              @values[expr] = { value: "<no frame>", error: true }
              return
            end

            begin
              result = frame.evaluate_expression(expr)
              if result&.valid? && !result.error?
                @values[expr] = {
                  value: format_value(result),
                  type: result.type_name,
                  error: false
                }
              else
                error_msg = result&.error&.to_s || "evaluation failed"
                @values[expr] = { value: error_msg, error: true }
              end
            rescue StandardError => e
              @values[expr] = { value: e.message, error: true }
            end
          end

          def format_value(result)
            return "nil" unless result

            # 値の取得を試みる
            value_str = result.value.to_s

            # 長すぎる場合は切り詰め
            max_len = content_region[:width] - 30
            if value_str.length > max_len
              value_str = "#{value_str[0...max_len - 3]}..."
            end

            value_str
          rescue StandardError
            begin
              result.summary || result.value.to_s
            rescue StandardError
              "<error>"
            end
          end

          def draw_watch_entry(y_offset, expr)
            info = @values[expr] || { value: "<pending>", error: false }
            changed = value_changed?(expr)

            # インデックス
            idx_str = format("[%d] ", y_offset)
            draw_text(y_offset, 0, idx_str, color: COLOR_CYAN)

            # 式の名前
            expr_width = [expr.length, 20].min
            expr_display = expr.length > 20 ? "#{expr[0...17]}..." : expr
            name_color = info[:error] ? COLOR_RED : COLOR_YELLOW
            draw_text(y_offset, idx_str.length, expr_display, color: name_color, bold: true)

            # 等号
            eq_pos = idx_str.length + expr_width + 1
            draw_text(y_offset, eq_pos, " = ", color: COLOR_WHITE)

            # 値
            value_pos = eq_pos + 3
            value_color = if info[:error]
                            COLOR_RED
                          elsif changed
                            COLOR_RED
                          else
                            COLOR_GREEN
                          end

            value_str = info[:value].to_s
            max_value_len = content_region[:width] - value_pos
            value_str = "#{value_str[0...max_value_len - 3]}..." if value_str.length > max_value_len

            draw_text(y_offset, value_pos, value_str, color: value_color, bold: changed)
          end

          def value_changed?(expr)
            return false unless @previous_values.key?(expr) && @values.key?(expr)

            prev = @previous_values[expr]
            curr = @values[expr]
            prev[:value] != curr[:value]
          end

          def draw_empty_message
            messages = [
              "No watch expressions",
              "",
              "Add expressions with:",
              "  watch <expression>",
              "",
              "Examples:",
              "  watch argc",
              "  watch *ptr",
              "  watch array[0]"
            ]

            messages.each_with_index do |msg, i|
              break if i >= content_region[:height]

              draw_line(i, msg.center(content_region[:width]), color: COLOR_CYAN)
            end
          end
        end
      end
    end
  end
end
