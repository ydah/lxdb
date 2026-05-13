# frozen_string_literal: true

require "curses"

module Lxdb
  module UI
    module TUI
      class Application
        attr_reader :session, :layout, :panels, :running

        # リサイズステップ
        RESIZE_STEP = 0.05

        def initialize(session)
          @session = session
          @running = false
          @focused_panel = nil
          @command_buffer = ""
          @message = nil
          @message_style = :info
          @resize_mode = false
        end

        def run
          setup_curses
          @layout = Layout.new
          @panels = create_panels
          @focused_panel = @panels[:command]

          @running = true
          main_loop
        ensure
          cleanup_curses
        end

        private

        def setup_curses
          Curses.init_screen
          Curses.start_color
          Curses.use_default_colors
          Curses.cbreak
          Curses.noecho
          Curses.curs_set(1)
          Curses.stdscr.keypad(true)
          Curses.timeout = 100

          setup_colors
        end

        def setup_colors
          Curses.init_pair(1, Curses::COLOR_CYAN, -1)
          Curses.init_pair(2, Curses::COLOR_GREEN, -1)
          Curses.init_pair(3, Curses::COLOR_RED, -1)
          Curses.init_pair(4, Curses::COLOR_YELLOW, -1)
          Curses.init_pair(5, Curses::COLOR_BLUE, -1)
          Curses.init_pair(6, Curses::COLOR_MAGENTA, -1)
          Curses.init_pair(7, Curses::COLOR_WHITE, -1)
        end

        def cleanup_curses
          Curses.close_screen
        end

        def create_panels
          panels = {
            registers: Panels::Registers.new(@session, @layout.regions[:registers]),
            disasm: Panels::Disasm.new(@session, @layout.regions[:disasm]),
            stack: Panels::Stack.new(@session, @layout.regions[:stack]),
            backtrace: Panels::Backtrace.new(@session, @layout.regions[:backtrace]),
            command: Panels::Command.new(@session, @layout.regions[:command])
          }

          # オプショナルパネル
          panels[:source] = Panels::Source.new(@session, @layout.regions[:source])
          panels[:memory] = Panels::Memory.new(@session, @layout.regions[:memory])
          panels[:watch] = Panels::Watch.new(@session, @layout.regions[:watch])

          panels
        end

        def main_loop
          while @running
            refresh_all
            handle_input
          end
        end

        def refresh_all
          Curses.clear

          # アクティブなパネルのみ描画
          active_panels = get_active_panels
          active_panels.each { |name| @panels[name]&.draw }

          draw_status_bar
          draw_message if @message
          @panels[:command].position_cursor(@command_buffer)

          Curses.refresh
        end

        def get_active_panels
          case @layout.current_preset
          when :source_focus
            %i[registers source stack backtrace command]
          when :memory_view
            %i[registers disasm memory backtrace command]
          else
            %i[registers disasm stack backtrace command]
          end
        end

        def draw_status_bar
          y = Curses.lines - 2
          status = build_status_text
          Curses.setpos(y, 0)
          Curses.attron(Curses::A_REVERSE)
          Curses.addstr(status.ljust(Curses.cols))
          Curses.attroff(Curses::A_REVERSE)
        end

        def build_status_text
          parts = [" lxdb"]

          if @session.target
            parts << "| #{File.basename(@session.target.executable&.fullpath || "???")}"
          end

          if @session.process&.valid?
            state = @session.process.state.to_s.upcase
            parts << "| #{state}"

            if @session.process.stopped? && @session.current_frame
              pc = format("0x%x", @session.current_frame.pc)
              func = @session.current_frame.function_name || "???"
              parts << "| #{func} (#{pc})"
            end
          end

          # レイアウト情報
          preset_name = @layout.preset_info[:name]
          parts << "| Layout: #{preset_name}"

          parts << if @resize_mode
                     "| [RESIZE MODE: ←→↑↓ to resize, Esc to exit]"
                   else
                     "| F1:Help F2:Layout F3:Resize F5:Run F12:Quit"
                   end

          parts.join(" ")
        end

        def draw_message
          return unless @message

          y = Curses.lines - 1
          Curses.setpos(y, 0)

          color = case @message_style
                  when :error then Curses.color_pair(3)
                  when :success then Curses.color_pair(2)
                  when :warning then Curses.color_pair(4)
                  else Curses.color_pair(7)
                  end

          Curses.attron(color)
          Curses.addstr(@message.ljust(Curses.cols)[0...Curses.cols])
          Curses.attroff(color)
        end

        def handle_input
          key = Curses.getch
          return if key.nil?

          if @resize_mode
            handle_resize_input(key)
          else
            handle_normal_input(key)
          end
        end

        def handle_normal_input(key)
          case key
          when Curses::KEY_F1
            show_help
          when Curses::KEY_F2
            cycle_layout
          when Curses::KEY_F3
            enter_resize_mode
          when Curses::KEY_F4
            toggle_panel(:source)
          when Curses::KEY_F5
            execute_command("run")
          when Curses::KEY_F6
            execute_command("continue")
          when Curses::KEY_F7
            toggle_panel(:watch)
          when Curses::KEY_F8
            toggle_panel(:memory)
          when Curses::KEY_F10
            execute_command("next")
          when Curses::KEY_F11
            execute_command("step")
          when Curses::KEY_F12, "q".ord
            @running = false
          when Curses::KEY_RESIZE
            handle_window_resize
          when 10, 13 # Enter
            execute_command(@command_buffer)
            @command_buffer = ""
          when 127, Curses::KEY_BACKSPACE
            @command_buffer = @command_buffer[0...-1]
          when 27 # Escape
            @command_buffer = ""
            @message = nil
          when String
            @command_buffer << key
          when Integer
            if key >= 32 && key < 127
              @command_buffer << key.chr
            end
          end
        end

        def handle_resize_input(key)
          case key
          when Curses::KEY_LEFT
            @layout.resize_left_panel(-RESIZE_STEP)
            update_panel_regions
            @message = format("Left panel width: %.0f%%", @layout.left_width_ratio * 100)
          when Curses::KEY_RIGHT
            @layout.resize_left_panel(RESIZE_STEP)
            update_panel_regions
            @message = format("Left panel width: %.0f%%", @layout.left_width_ratio * 100)
          when Curses::KEY_UP
            @layout.resize_top_panel(-RESIZE_STEP)
            update_panel_regions
            @message = format("Top panel height: %.0f%%", @layout.top_height_ratio * 100)
          when Curses::KEY_DOWN
            @layout.resize_top_panel(RESIZE_STEP)
            update_panel_regions
            @message = format("Top panel height: %.0f%%", @layout.top_height_ratio * 100)
          when 27, Curses::KEY_F3 # Escape or F3
            exit_resize_mode
          end
        end

        def enter_resize_mode
          @resize_mode = true
          @message = "Resize mode: Use arrow keys to resize panels, Esc to exit"
          @message_style = :warning
        end

        def exit_resize_mode
          @resize_mode = false
          @message = "Resize mode exited"
          @message_style = :info
        end

        def cycle_layout
          @layout.next_preset
          update_panel_regions
          preset_info = @layout.preset_info
          @message = "Layout: #{preset_info[:name]} - #{preset_info[:description]}"
          @message_style = :info
        end

        def toggle_panel(panel_name)
          case panel_name
          when :source
            @layout.apply_preset(@layout.current_preset == :source_focus ? :default : :source_focus)
          when :memory
            @layout.apply_preset(@layout.current_preset == :memory_view ? :default : :memory_view)
          when :watch
            # Watchパネルはスタックの代わりに表示
            # 今回はメッセージのみ
            @message = "Watch panel: Use 'watch <expr>' command to add expressions"
            @message_style = :info
            return
          end
          update_panel_regions
        end

        def update_panel_regions
          @panels.each do |name, panel|
            panel.region = @layout.regions[name] if @layout.regions[name]
          end
        end

        def handle_window_resize
          top_height_ratio = @layout.top_height_ratio
          left_width_ratio = @layout.left_width_ratio

          @layout = Layout.new(preset: @layout.current_preset)
          @layout.top_height_ratio = top_height_ratio
          @layout.left_width_ratio = left_width_ratio
          @layout.calculate_regions
          update_panel_regions
        end

        def execute_command(cmd)
          return if cmd.nil? || cmd.strip.empty?

          @message = nil

          begin
            parts = cmd.strip.split(/\s+/)
            command_name = parts.first
            args = parts[1..] || []
            command_name, args = UI::CommandNormalizer.normalize_x_command(command_name, args)

            # 特別なTUIコマンド
            case command_name
            when "layout"
              handle_layout_command(args)
              return
            when "watch"
              handle_watch_command(args)
              return
            when "memory", "mem"
              handle_memory_command(args)
              return
            when "quit", "q"
              @running = false
              return
            end

            command_class = Commands::Registry.find(command_name)

            if command_class
              command = command_class.new(@session)
              old_stdout = $stdout
              $stdout = StringIO.new
              begin
                command.execute(args)
                output = $stdout.string
                @message = output.lines.first&.strip if output && !output.empty?
                @message_style = :info
              ensure
                $stdout = old_stdout
              end
            else
              result = @session.execute_command(cmd)
              @message = result.lines.first&.strip if result && !result.empty?
              @message_style = :info
            end
          rescue Lxdb::CommandError => e
            @message = "Error: #{e.message}"
            @message_style = :error
          rescue StandardError => e
            @message = "Error: #{e.message}"
            @message_style = :error
          end
        end

        def handle_layout_command(args)
          if args.empty?
            presets = Layout::PRESETS.keys.join(", ")
            @message = "Available layouts: #{presets}"
            @message_style = :info
            return
          end

          preset_name = args.first.to_sym
          if @layout.apply_preset(preset_name)
            update_panel_regions
            @message = "Layout changed to: #{@layout.preset_info[:name]}"
            @message_style = :success
          else
            @message = "Unknown layout: #{args.first}"
            @message_style = :error
          end
        end

        def handle_watch_command(args)
          watch_panel = @panels[:watch]

          if args.empty?
            count = watch_panel.expressions.size
            @message = "Watch expressions: #{count}. Use 'watch <expr>' to add."
            @message_style = :info
            return
          end

          case args.first
          when "clear"
            watch_panel.clear_all
            @message = "All watch expressions cleared"
            @message_style = :success
          when "del", "delete", "remove"
            if args[1]
              index = args[1].to_i
              if watch_panel.remove_at(index)
                @message = "Watch expression #{index} removed"
                @message_style = :success
              else
                @message = "Invalid watch index: #{index}"
                @message_style = :error
              end
            else
              @message = "Usage: watch del <index>"
              @message_style = :warning
            end
          else
            expr = args.join(" ")
            if watch_panel.add_expression(expr)
              @message = "Watching: #{expr}"
              @message_style = :success
            else
              @message = "Already watching: #{expr}"
              @message_style = :warning
            end
          end
        end

        def handle_memory_command(args)
          memory_panel = @panels[:memory]

          if args.empty?
            @message = if memory_panel.address
                         format("Viewing memory at 0x%x (%d bytes)", memory_panel.address, memory_panel.size)
                       else
                         "Usage: memory <address> [size]"
                       end
            @message_style = :info
            return
          end

          # アドレスのパース
          addr_str = args.first
          addr = parse_address(addr_str)

          unless addr
            @message = "Invalid address: #{addr_str}"
            @message_style = :error
            return
          end

          size = args[1] ? args[1].to_i : 256
          memory_panel.set_address(addr, size)

          # メモリビューレイアウトに切り替え
          @layout.apply_preset(:memory_view)
          update_panel_regions

          @message = format("Viewing memory at 0x%x (%d bytes)", addr, size)
          @message_style = :success
        end

        def parse_address(str)
          return nil if str.nil?

          if str.start_with?("$")
            # レジスタ参照
            reg_name = str[1..].to_sym
            @session.read_register(reg_name)
          elsif str =~ /^0x([0-9a-fA-F]+)$/
            Regexp.last_match(1).to_i(16)
          elsif str =~ /^\d+$/
            str.to_i
          else
            str.to_i(16)
          end
        end

        def show_help
          help_text = [
            "F1:Help F2:Layout F3:Resize F4:Source F5:Run F6:Continue",
            "F7:Watch F8:Memory F10:Next F11:Step F12:Quit",
            "Commands: layout, watch, memory"
          ].join(" | ")
          @message = help_text
          @message_style = :info
        end
      end
    end
  end
end
