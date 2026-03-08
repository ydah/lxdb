# frozen_string_literal: true

module Lxdb
  module Context
    class Backtrace < Base
      MAX_FRAMES = 10

      def render
        thread = current_thread
        return nil unless thread

        output = [banner("BACKTRACE")]
        output << thread_info(thread)

        frames = get_frames(thread)
        frames.each_with_index do |frame, index|
          output << format_frame(frame, index)
        end

        output.join("\n")
      end

      # 全スレッドのバックトレースを表示
      def render_all_threads
        return nil unless process

        output = [banner("ALL THREADS BACKTRACE")]
        output << ""

        session.all_threads.each_with_index do |thread, idx|
          output << thread_header(thread)

          frames = get_frames(thread)
          frames.each_with_index do |frame, index|
            output << format_frame(frame, index, indent: "  ")
          end

          if thread.num_frames > MAX_FRAMES
            remaining = thread.num_frames - MAX_FRAMES
            output << "  ... #{remaining} more frames"
          end

          output << "" if idx < session.thread_count - 1
        end

        output.join("\n")
      end

      private

      def thread_info(thread)
        selected_marker = c("*", :current_arrow)
        state = thread_state(thread)
        "#{selected_marker} Thread ##{thread.index_id}: #{state}"
      end

      def thread_header(thread)
        current = thread.index_id == current_thread&.index_id
        marker = current ? c("* ", :current_arrow) : "  "
        state = thread_state(thread)

        "#{marker}#{c("Thread ##{thread.index_id}", :info)}: #{state}"
      end

      def thread_state(thread)
        reason = begin
          thread.stop_reason_string
        rescue StandardError
          "unknown"
        end
        frame = thread.frame_at_index(0)
        func = frame&.function_name || "???"
        "#{reason} in #{c(func, :function_name)}"
      end

      def get_frames(thread)
        frames = []
        num_frames = [thread.num_frames, MAX_FRAMES].min

        num_frames.times do |i|
          frame = thread.frame_at_index(i)
          frames << frame if frame&.valid?
        end

        frames
      end

      def format_frame(frame, index, indent: "")
        # Frame number
        frame_num = c(format("#%-2d", index), :frame_number)

        # PC address
        pc = c(format_address(frame.pc), :address)

        # Function name
        func_name = frame.function_name || frame.symbol&.name || "???"
        func_str = c(func_name, :function_name)

        # Source location if available
        line_entry = frame.line_entry
        location = if line_entry&.valid?
                     file = File.basename(line_entry.file_spec.filename || "")
                     line = line_entry.line
                     c(" at #{file}:#{line}", :source_location)
                   else
                     ""
                   end

        # Module name
        module_name = frame.module&.file_spec&.filename
        module_str = module_name ? c(" (#{File.basename(module_name)})", :comment) : ""

        "#{indent}#{frame_num} #{pc} in #{func_str}#{location}#{module_str}"
      end
    end
  end
end
