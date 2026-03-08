# frozen_string_literal: true

module Lxdb
  module Platform
    # プラットフォーム検出と共通インターフェースを提供する基底クラス
    class Base
      class << self
        # 現在のプラットフォームを検出して適切なクラスを返す
        def current
          @current ||= detect_platform
        end

        # デバッグに関する制限情報を取得
        def debugging_restrictions
          []
        end

        # プロセスがデバッグ可能かどうかをチェック
        def can_debug_process?(_pid)
          true
        end

        # デバッグ前のチェックと警告
        def pre_debug_check(_pid = nil)
          []
        end

        # バイナリのcodesign状態を確認
        def check_codesign(_binary_path)
          nil
        end

        # ユーザー向けデバッグガイド
        def debugging_guide
          "No platform-specific debugging guide available."
        end

        private

        def detect_platform
          case RUBY_PLATFORM
          when /darwin/
            MacOS
          when /linux/
            Linux
          when /mswin|mingw|cygwin/
            Windows
          else
            Generic
          end
        end
      end
    end

    # Linux向けプレースホルダー
    class Linux < Base
      class << self
        def debugging_restrictions
          restrictions = []

          # ptrace制限のチェック
          if ptrace_restricted?
            restrictions << {
              type: :ptrace,
              severity: :warning,
              message: "ptrace is restricted (Yama security module).",
              details: "Current ptrace_scope: #{ptrace_scope}",
              suggestion: "To allow debugging: echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope"
            }
          end

          restrictions
        end

        private

        def ptrace_restricted?
          ptrace_scope.to_i.positive?
        rescue StandardError
          false
        end

        def ptrace_scope
          File.read("/proc/sys/kernel/yama/ptrace_scope").strip
        rescue StandardError
          "0"
        end
      end
    end

    # Windows向けプレースホルダー
    class Windows < Base
      class << self
        def debugging_restrictions
          [{
            type: :windows,
            severity: :info,
            message: "Windows debugging may require administrator privileges.",
            details: "Some features may be limited without elevation.",
            suggestion: "Run as Administrator for full debugging capabilities."
          }]
        end
      end
    end

    # 汎用プラットフォーム
    class Generic < Base; end
  end
end
