# frozen_string_literal: true

module Lxdb
  module Commands
    # スレッド操作コマンド
    class Thread < Base
      command "thread", aliases: %w[t], description: "Thread operations", category: :navigation

      def execute(args)
        subcommand = args.first
        rest_args = args[1..] || []

        case subcommand
        when "select", "switch", "s"
          select_thread(rest_args)
        when "list", "l"
          list_threads
        when "backtrace", "bt"
          thread_backtrace(rest_args)
        when "all"
          all_threads_backtrace
        when "deadlock", "dl"
          detect_deadlock
        when "info", "i"
          thread_info(rest_args)
        else
          # 数値のみの場合はスレッド選択として扱う
          if subcommand =~ /^\d+$/
            select_thread([subcommand])
          else
            show_thread_help
          end
        end
      end

      private

      def select_thread(args)
        require_process!

        thread_id = args.first&.to_i
        raise CommandError, "Usage: thread select <thread_id>" unless thread_id

        thread = find_thread_by_id(thread_id)
        raise CommandError, "Thread ##{thread_id} not found" unless thread

        session.select_thread(thread_id)
        output(c("Selected thread ##{thread_id}: #{thread_summary(thread)}", :success))

        # 選択したスレッドのバックトレースを表示
        session.context_renderer.render_section(:backtrace)
      end

      def list_threads
        require_process!

        output(c("Threads:", :info))
        output("")

        session.all_threads.each do |thread|
          selected = thread.index_id == session.current_thread&.index_id
          output(format_thread_line(thread, selected))
        end
      end

      def thread_backtrace(args)
        require_process!

        thread_id = args.first&.to_i
        raise CommandError, "Usage: thread backtrace <thread_id>" unless thread_id

        thread = find_thread_by_id(thread_id)
        raise CommandError, "Thread ##{thread_id} not found" unless thread

        output(c("Backtrace for Thread ##{thread_id}:", :info))
        output_thread_backtrace(thread)
      end

      def all_threads_backtrace
        require_process!

        output(c("All Threads Backtrace:", :banner))
        output("")

        session.all_threads.each do |thread|
          selected = thread.index_id == session.current_thread&.index_id
          marker = selected ? c("* ", :current_arrow) : "  "

          output("#{marker}#{c("Thread ##{thread.index_id}", :info)}: #{thread_summary(thread)}")
          output_thread_backtrace(thread, indent: "    ")
          output("")
        end
      end

      def thread_info(args)
        require_process!

        thread_id = args.first&.to_i
        thread = if thread_id
                   find_thread_by_id(thread_id)
                 else
                   session.current_thread
                 end

        raise CommandError, "Thread not found" unless thread

        output(c("Thread ##{thread.index_id} Info:", :info))
        output("  State: #{thread_state_string(thread)}")
        output("  Stop Reason: #{thread.stop_reason}")

        frame = thread.frame_at_index(0)
        if frame&.valid?
          output("  PC: #{c(format_address(frame.pc), :address)}")
          output("  Function: #{c(frame.function_name || "???", :function_name)}")
        end

        output("  Frame Count: #{thread.num_frames}")
      end

      def detect_deadlock
        require_process!

        output(c("Deadlock Detection:", :banner))
        output("")

        threads_info = collect_threads_info

        # 待機状態のスレッドを収集
        waiting_threads = threads_info.select { |t| waiting_state?(t[:state]) }

        if waiting_threads.empty?
          output(c("No threads in waiting state found.", :success))
          output("")
          output("All #{threads_info.size} thread(s) are running or stopped at breakpoints.")
          return
        end

        output(c("Threads in waiting state (#{waiting_threads.size}):", :warning))
        waiting_threads.each do |t|
          state = t[:state].to_s.empty? ? "unknown" : t[:state]
          output("  Thread ##{t[:id]}: #{state}")
          if t[:frame]&.valid?
            output("    at #{c(t[:frame].function_name || "???", :function_name)}")
          end
        end
        output("")

        # デッドロック候補を検出
        deadlock_candidates = detect_deadlock_candidates(threads_info)

        if deadlock_candidates.any?
          output(c("Potential deadlock indicators:", :error))
          deadlock_candidates.each do |candidate|
            output("  - #{candidate}")
          end
        else
          output(c("No obvious deadlock pattern detected.", :success))
        end

        output("")
        output(c("Investigation tips:", :info))
        output("  1. Use 'thread <id>' to inspect individual thread backtraces")
        output("  2. Look for mutex/lock acquisition patterns")
        output("  3. Check if threads are waiting for each other's resources")
        output("  4. Examine variables holding lock objects")
      end

      def show_thread_help
        output(c("Thread commands:", :info))
        output("  thread list          - List all threads (alias: thread l)")
        output("  thread select <id>   - Select a thread (alias: thread s)")
        output("  thread <id>          - Select a thread (shorthand)")
        output("  thread backtrace <id> - Show backtrace for a thread (alias: thread bt)")
        output("  thread all           - Show all threads' backtraces")
        output("  thread info [id]     - Show thread info (alias: thread i)")
        output("  thread deadlock      - Detect potential deadlocks (alias: thread dl)")
      end

      # ヘルパーメソッド

      def find_thread_by_id(thread_id)
        session.all_threads.find { |t| t.index_id == thread_id }
      end

      def format_thread_line(thread, selected)
        marker = selected ? c("* ", :current_arrow) : "  "
        id = c("##{thread.index_id}".ljust(4), :info)
        state = thread_state_string(thread)
        summary = thread_summary(thread)

        "#{marker}#{id} #{state} #{summary}"
      end

      def thread_summary(thread)
        frame = thread.frame_at_index(0)
        return "???" unless frame&.valid?

        func = frame.function_name || frame.symbol&.name || "???"
        addr = format_address(frame.pc)

        "#{func} at #{addr}"
      end

      def thread_state_string(thread)
        reason = begin
          thread.stop_reason_string
        rescue StandardError
          "unknown"
        end
        case reason.to_s.downcase
        when /breakpoint/
          c("[break]".ljust(12), :warning)
        when /signal/
          c("[signal]".ljust(12), :error)
        when /watchpoint/
          c("[watch]".ljust(12), :warning)
        when /step/
          c("[step]".ljust(12), :success)
        when /exception/
          c("[exception]".ljust(12), :error)
        when /exec/
          c("[exec]".ljust(12), :info)
        else
          c("[#{reason}]".ljust(12), :comment)
        end
      end

      def output_thread_backtrace(thread, indent: "")
        max_frames = 10
        num_frames = [thread.num_frames, max_frames].min

        num_frames.times do |i|
          frame = thread.frame_at_index(i)
          next unless frame&.valid?

          frame_num = "##{i}".ljust(3)
          addr = c(format_address(frame.pc), :address)
          func = frame.function_name || "???"
          func_str = c(func, :function_name)

          # ソース位置
          location = ""
          line_entry = frame.line_entry
          if line_entry&.valid?
            file = File.basename(line_entry.file_spec.filename || "")
            line = line_entry.line
            location = " at #{c("#{file}:#{line}", :source_location)}"
          end

          output("#{indent}#{frame_num} #{addr} in #{func_str}#{location}")
        end

        return unless thread.num_frames > max_frames

        remaining = thread.num_frames - max_frames
        output("#{indent}... #{remaining} more frames")
      end

      def collect_threads_info
        session.all_threads.map do |thread|
          {
            id: thread.index_id,
            state: begin
              thread.stop_reason_string
            rescue StandardError
              "unknown"
            end,
            stop_reason: begin
              thread.stop_reason
            rescue StandardError
              nil
            end,
            frame: thread.frame_at_index(0)
          }
        end
      end

      def waiting_state?(state)
        return false if state.nil?

        keywords = %w[wait mutex semaphore condition lock blocked futex pthread_cond pthread_mutex]
        keywords.any? { |keyword| state.to_s.downcase.include?(keyword) }
      end

      def detect_deadlock_candidates(threads_info)
        candidates = []

        # 全スレッドが待機状態の場合
        all_waiting = threads_info.all? { |t| waiting_state?(t[:state]) }
        if all_waiting && threads_info.size > 1
          candidates << "All #{threads_info.size} threads are in waiting state"
        end

        # 同じロック関連関数で停止しているスレッドを検出
        lock_functions = %w[
          pthread_mutex_lock pthread_cond_wait pthread_rwlock
          sem_wait __lll_lock_wait futex_wait
          os_unfair_lock_lock OSSpinLockLock
          dispatch_semaphore_wait
        ]

        waiting_on_lock = threads_info.select do |t|
          frame = t[:frame]
          next false unless frame&.valid?

          func_name = frame.function_name.to_s.downcase
          lock_functions.any? { |lf| func_name.include?(lf.downcase) }
        end

        if waiting_on_lock.size >= 2
          ids = waiting_on_lock.map { |t| "##{t[:id]}" }.join(", ")
          funcs = waiting_on_lock.map { |t| t[:frame]&.function_name }.compact.uniq.join(", ")
          candidates << "Multiple threads waiting on locks: #{ids}"
          candidates << "Lock functions: #{funcs}"
        end

        # 循環依存の兆候（同じスタックパターン）
        if threads_info.size >= 2
          stack_signatures = threads_info.map do |t|
            frames = []
            5.times do |i|
              frame = begin
                t[:frame]&.thread&.frame_at_index(i)
              rescue StandardError
                nil
              end
              frames << frame&.function_name if frame&.valid?
            end
            frames.compact.join(" -> ")
          end

          if stack_signatures.uniq.size == 1 && !stack_signatures.first.empty?
            candidates << "All threads have identical stack patterns (possible contention)"
          end
        end

        candidates
      end
    end
  end
end
