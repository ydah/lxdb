# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      class Region
        attr_accessor :x, :y, :width, :height

        def initialize(x, y, width, height)
          @x = x
          @y = y
          @width = width
          @height = height
        end

        def contains?(px, py)
          px >= @x && px < @x + @width && py >= @y && py < @y + @height
        end
      end

      class Layout
        # レイアウトプリセット
        PRESETS = {
          default: {
            name: "Default",
            description: "標準4パネルレイアウト",
            panels: %i[registers disasm stack backtrace command],
            ratios: { top_height: 0.4, left_width: 0.35 }
          },
          wide_disasm: {
            name: "Wide Disassembly",
            description: "逆アセンブリ重視レイアウト",
            panels: %i[registers disasm stack backtrace command],
            ratios: { top_height: 0.5, left_width: 0.25 }
          },
          compact: {
            name: "Compact",
            description: "コンパクトレイアウト",
            panels: %i[registers disasm stack backtrace command],
            ratios: { top_height: 0.35, left_width: 0.30 }
          },
          source_focus: {
            name: "Source Focus",
            description: "ソースコード重視レイアウト",
            panels: %i[registers source disasm stack backtrace command],
            ratios: { top_height: 0.5, left_width: 0.30 }
          },
          memory_view: {
            name: "Memory View",
            description: "メモリビュー付きレイアウト",
            panels: %i[registers disasm memory stack backtrace command],
            ratios: { top_height: 0.4, left_width: 0.35 }
          }
        }.freeze

        attr_reader :regions, :current_preset
        attr_accessor :top_height_ratio, :left_width_ratio

        def initialize(preset: :default)
          @current_preset = preset
          preset_config = PRESETS[preset] || PRESETS[:default]
          @top_height_ratio = preset_config[:ratios][:top_height]
          @left_width_ratio = preset_config[:ratios][:left_width]
          @active_panels = preset_config[:panels]
          calculate_regions
        end

        def calculate_regions
          height = Curses.lines
          width = Curses.cols

          # Reserve space for command input (3 lines) and status bar (2 lines)
          available_height = height - 5

          # Top row height based on ratio
          top_height = (available_height * @top_height_ratio).to_i
          # Bottom row height
          bottom_height = available_height - top_height

          # Column widths based on ratio
          left_width = (width * @left_width_ratio).to_i
          right_width = width - left_width

          @regions = {
            registers: Region.new(0, 0, left_width, top_height),
            disasm: Region.new(left_width, 0, right_width, top_height),
            stack: Region.new(0, top_height, left_width, bottom_height),
            backtrace: Region.new(left_width, top_height, right_width, bottom_height),
            command: Region.new(0, available_height, width, 3),
            # 追加パネル用（表示時に計算）
            source: Region.new(left_width, 0, right_width, top_height),
            memory: Region.new(0, top_height, left_width, bottom_height),
            watch: Region.new(0, top_height, left_width, bottom_height)
          }
        end

        # パネルサイズの調整（キーボードリサイズ用）
        def resize_left_panel(delta)
          new_ratio = @left_width_ratio + delta
          @left_width_ratio = new_ratio.clamp(0.15, 0.60)
          calculate_regions
        end

        def resize_top_panel(delta)
          new_ratio = @top_height_ratio + delta
          @top_height_ratio = new_ratio.clamp(0.20, 0.70)
          calculate_regions
        end

        # レイアウトプリセットの切り替え
        def apply_preset(preset_name)
          return false unless PRESETS.key?(preset_name)

          @current_preset = preset_name
          preset_config = PRESETS[preset_name]
          @top_height_ratio = preset_config[:ratios][:top_height]
          @left_width_ratio = preset_config[:ratios][:left_width]
          @active_panels = preset_config[:panels]
          calculate_regions
          true
        end

        def next_preset
          presets = PRESETS.keys
          current_index = presets.index(@current_preset) || 0
          next_index = (current_index + 1) % presets.size
          apply_preset(presets[next_index])
          @current_preset
        end

        def preset_info
          PRESETS[@current_preset]
        end

        def active_panels
          @active_panels.dup
        end

        # レイアウト設定の保存/読み込み
        def to_h
          {
            preset: @current_preset,
            top_height_ratio: @top_height_ratio,
            left_width_ratio: @left_width_ratio
          }
        end

        def self.from_h(hash)
          layout = new(preset: hash[:preset] || :default)
          layout.top_height_ratio = hash[:top_height_ratio] if hash[:top_height_ratio]
          layout.left_width_ratio = hash[:left_width_ratio] if hash[:left_width_ratio]
          layout.calculate_regions
          layout
        end
      end
    end
  end
end
