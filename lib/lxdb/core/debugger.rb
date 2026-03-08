# frozen_string_literal: true

begin
  require "lldb"
  LLDB_LOAD_ERROR = nil
rescue LoadError => e
  LLDB_LOAD_ERROR = e
end

module Lxdb
  module Core
    class Debugger
      attr_reader :lldb_debugger, :targets, :current_target, :architecture

      def initialize
        @targets = []
        @current_target = nil
        @architecture = nil

        return unless self.class.lldb_available?

        LLDB.initialize
        @lldb_debugger = LLDB::Debugger.create
      end

      def create_target(executable_path, arch: nil)
        ensure_lldb_available!
        lldb_target = @lldb_debugger.create_target(executable_path)
        raise DebuggerError, "Failed to create target for: #{executable_path}" unless lldb_target&.valid?

        @architecture = arch ? Arch::Base.for_triple(arch) : detect_architecture(lldb_target)
        @current_target = lldb_target
        @targets << lldb_target
        lldb_target
      end

      def attach_to_pid(pid)
        ensure_lldb_available!
        raise DebuggerError, "No target loaded" unless @current_target

        # プラットフォーム固有のチェック
        platform = Platform::Base.current
        warnings = platform.pre_debug_check(pid)
        warnings.each { |w| Lxdb.logger&.warn(w) }

        unless platform.can_debug_process?(pid)
          raise DebuggerError,
                "Cannot debug process #{pid}. Check SIP status and permissions.\n" \
                "Use 'platform info' command for debugging guide."
        end

        error = LLDB::SBError.new
        process = @current_target.attach_to_process_with_id(@lldb_debugger.listener, pid, error)

        unless error.success?
          error_details = parse_attach_error(error, pid)
          raise DebuggerError, error_details
        end

        process
      end

      def launch(args: [], env: nil, stdin: nil, stdout: nil, stderr: nil, working_dir: nil)
        ensure_lldb_available!
        raise DebuggerError, "No target loaded" unless @current_target

        unless [stdin, stdout, stderr].all?(&:nil?)
          Lxdb.logger&.debug("Custom stdio streams are currently ignored by LLDB launch")
        end

        launch_info = LLDB::LaunchInfo.new
        launch_info.arguments = args unless args.empty?
        launch_info.environment_variables = env if env
        launch_info.working_directory = working_dir if working_dir

        error = LLDB::SBError.new
        process = @current_target.launch(launch_info, error)
        raise DebuggerError, "Failed to launch: #{error}" unless error.success?

        process
      end

      def command_interpreter
        ensure_lldb_available!
        @lldb_debugger.command_interpreter
      end

      def execute_command(command)
        result = LLDB::CommandReturnObject.new
        command_interpreter.handle_command(command, result)
        result
      end

      def terminate
        return unless self.class.lldb_available?

        @targets.each do |target|
          process = target.process
          process&.destroy if process&.valid?
        end
        @lldb_debugger&.destroy
        LLDB.terminate
      end

      def self.lldb_available?
        LLDB_LOAD_ERROR.nil?
      end

      private

      def ensure_lldb_available!
        return if self.class.lldb_available?

        raise DebuggerError,
              "LLDB is not available in this environment: #{LLDB_LOAD_ERROR.message}"
      end

      def detect_architecture(target)
        triple = target.triple
        Arch::Base.for_triple(triple)
      rescue StandardError
        # Default to x86_64
        Arch::X86_64.new
      end

      def parse_attach_error(error, pid)
        message = error.to_s

        case message
        when /attach failed/i, /failed to attach/i
          "Failed to attach to PID #{pid}. " \
          "Possible causes: process doesn't exist, permission denied, or SIP restrictions.\n" \
          "Hint: Check 'csrutil status' and ensure you have debugging privileges."
        when /permission/i, /operation not permitted/i
          "Permission denied attaching to PID #{pid}. " \
          "Try running with sudo or check your debugging entitlements.\n" \
          "On macOS, run: sudo DevToolsSecurity -enable"
        when /no such process/i, /process.*not.*found/i
          "Process #{pid} does not exist or has already terminated."
        when /already being debugged/i
          "Process #{pid} is already being debugged by another debugger."
        else
          "Failed to attach to PID #{pid}: #{message}"
        end
      end
    end
  end
end
