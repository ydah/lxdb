# frozen_string_literal: true

require "English"

module Lxdb
  module Platform
    # macOS固有のデバッグサポート
    # SIP (System Integrity Protection)、codesign、デバッグ権限の処理
    class MacOS < Base
      class << self
        # macOS環境かどうか判定
        def macos?
          RUBY_PLATFORM.include?("darwin")
        end

        # SIPの状態を確認
        def sip_status
          return :not_macos unless macos?

          output = `csrutil status 2>&1`.strip
          case output
          when /enabled/i
            :enabled
          when /disabled/i
            :disabled
          when /unknown/i, /not recognized/i
            :unknown
          else
            :unknown
          end
        rescue Errno::ENOENT
          :command_not_found
        end

        # SIPが有効かどうか
        def sip_enabled?
          sip_status == :enabled
        end

        # デバッグ制限に関する警告を取得
        def debugging_restrictions
          return [] unless macos?

          restrictions = []

          if sip_enabled?
            restrictions << {
              type: :sip,
              severity: :warning,
              message: "System Integrity Protection (SIP) is enabled.",
              details: "Some debugging features may be restricted. " \
                       "System binaries and processes cannot be debugged.",
              suggestion: "To debug system processes, you may need to disable SIP. " \
                          "Reboot to Recovery Mode and run: csrutil disable"
            }
          end

          unless developer_mode_enabled?
            restrictions << {
              type: :developer_mode,
              severity: :info,
              message: "Developer mode may not be enabled.",
              details: "You may be prompted for password when attaching to processes.",
              suggestion: "Enable with: sudo DevToolsSecurity -enable"
            }
          end

          unless debugserver_available?
            restrictions << {
              type: :debugserver,
              severity: :warning,
              message: "debugserver may not be properly configured.",
              details: "Some remote debugging features may not work.",
              suggestion: "Ensure Xcode Command Line Tools are installed: " \
                          "xcode-select --install"
            }
          end

          restrictions
        end

        # プロセスがデバッグ可能かチェック
        def can_debug_process?(pid)
          return true unless macos?

          # 自分自身のプロセスは常にデバッグ可能
          return true if pid == Process.pid

          # プロセスの存在確認
          begin
            Process.kill(0, pid)
          rescue Errno::ESRCH
            return false # プロセスが存在しない
          rescue Errno::EPERM
            # 権限エラーの場合はさらに調査が必要
          end

          # システムプロセスかどうか確認
          if system_process?(pid) && sip_enabled?
            return false
          end

          true
        end

        # デバッグ前のチェックと警告表示
        def pre_debug_check(pid = nil)
          return [] unless macos?

          warnings = []

          # SIP警告
          if sip_enabled?
            warnings << "SIP is enabled - some debugging may be restricted"
          end

          # 特定のPIDに対するチェック
          if pid && !can_debug_process?(pid)
            warnings << "Process #{pid} may not be debuggable (check permissions/SIP)"
          end

          warnings
        end

        # codesign状態を確認
        def check_codesign(binary_path)
          return nil unless macos?
          return nil unless File.exist?(binary_path)

          output = `codesign -dv "#{binary_path}" 2>&1`

          if $CHILD_STATUS.success?
            parse_codesign_output(output)
          else
            { signed: false, error: output.strip }
          end
        rescue Errno::ENOENT
          { signed: false, error: "codesign command not found" }
        end

        # デバッグに必要なentitlementがあるかチェック
        def has_debug_entitlement?(binary_path)
          return nil unless macos?
          return nil unless File.exist?(binary_path)

          output = `codesign -d --entitlements :- "#{binary_path}" 2>&1`
          return false unless $CHILD_STATUS.success?

          output.include?("com.apple.security.cs.debugger") ||
            output.include?("com.apple.security.get-task-allow")
        rescue StandardError
          false
        end

        # ユーザー向けガイダンス
        def debugging_guide
          <<~GUIDE
            macOS Debugging Guide
            =====================

            1. SIP (System Integrity Protection)
               - Check status: csrutil status
               - SIP protects system binaries from debugging
               - Disable in Recovery Mode (not recommended for regular use)
               - Current status: #{sip_status}

            2. Developer Mode
               - Enable: sudo DevToolsSecurity -enable
               - Allows debugging without password prompts
               - Status: #{developer_mode_enabled? ? "enabled" : "unknown/disabled"}

            3. Code Signing
               - Ensure your debugger has proper entitlements
               - Use: codesign -d --entitlements :- /path/to/binary
               - Required entitlement: com.apple.security.cs.debugger

            4. Common Issues
               - "attach failed": Check process exists and permissions
               - "Operation not permitted": SIP or entitlement issue
               - Try running with sudo (not recommended for production)

            5. Xcode Command Line Tools
               - Install: xcode-select --install
               - Required for full LLDB functionality
          GUIDE
        end

        # 現在のシステム情報を取得
        def system_info
          {
            platform: :macos,
            sip_status: sip_status,
            developer_mode: developer_mode_enabled?,
            xcode_tools: xcode_tools_installed?,
            debugserver: debugserver_available?,
            architecture: detect_architecture
          }
        end

        private

        def developer_mode_enabled?
          output = `DevToolsSecurity -status 2>&1`
          output.include?("enabled")
        rescue StandardError
          false
        end

        def debugserver_available?
          system("which debugserver > /dev/null 2>&1") ||
            File.exist?("/Library/Developer/CommandLineTools/Library/PrivateFrameworks/LLDB.framework/Versions/A/Resources/debugserver") ||
            File.exist?("/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Versions/A/Resources/debugserver")
        end

        def xcode_tools_installed?
          system("xcode-select -p > /dev/null 2>&1")
        end

        def system_process?(pid)
          # システムプロセスかどうかの簡易判定

          info = `ps -p #{pid} -o user= 2>/dev/null`.strip
          %w[root _windowserver _hidd _mds _spotlight _coreaudiod].include?(info)
        rescue StandardError
          false
        end

        def detect_architecture
          arch = `uname -m`.strip
          case arch
          when "arm64"
            :arm64
          when "x86_64"
            :x86_64
          else
            arch.to_sym
          end
        rescue StandardError
          :unknown
        end

        def parse_codesign_output(output)
          result = { signed: true }

          if output =~ /Identifier=(\S+)/
            result[:identifier] = ::Regexp.last_match(1)
          end

          if output =~ /Authority=(.+?)$/m
            result[:authority] = ::Regexp.last_match(1).strip
          end

          if output =~ /TeamIdentifier=(\S+)/
            result[:team_id] = ::Regexp.last_match(1)
          end

          result
        end
      end
    end
  end
end
