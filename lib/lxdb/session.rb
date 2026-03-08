# frozen_string_literal: true

module Lxdb
  class Session
    attr_reader :debugger, :config, :context_renderer, :memory, :plugin_loader

    def initialize(config = nil)
      @config = config || Config.new
      @debugger = Core::Debugger.new
      @context_renderer = nil
      @memory = nil
      @stop_handlers = []
      @plugin_loader = Plugins::Loader.new(self)

      Color::Theme.current.enabled = @config.color_enabled

      # Auto-load plugins
      @plugin_loader.load_all
    end

    def load_target(executable_path)
      @debugger.create_target(executable_path)
      setup_context_renderer
      self
    end

    def attach(pid)
      process = @debugger.attach_to_pid(pid)
      setup_memory
      process
    end

    def launch(args: [], stop_at_entry: true)
      process = @debugger.launch(args: args)
      setup_memory
      on_stop if stop_at_entry && process.stopped?
      process
    end

    def target
      @debugger.current_target
    end

    def process
      target&.process
    end

    def architecture
      @debugger.architecture
    end

    def current_thread
      process&.selected_thread
    end

    def current_frame
      current_thread&.selected_frame
    end

    # スレッド関連メソッド

    def select_thread(thread_id)
      return nil unless process&.valid?

      thread = all_threads.find { |t| t.index_id == thread_id }
      return nil unless thread

      process.set_selected_thread(thread)
      thread
    end

    def all_threads
      return [] unless process&.valid?

      threads = []
      process.num_threads.times do |i|
        thread = process.thread_at_index(i)
        threads << thread if thread&.valid?
      end
      threads
    end

    def thread_count
      process&.num_threads || 0
    end

    def find_thread(thread_id)
      all_threads.find { |t| t.index_id == thread_id }
    end

    # Navigation commands
    def step
      run_and_wait { current_thread&.step_into }
    end

    def step_instruction
      run_and_wait { current_thread&.step_instruction }
    end

    def next_line
      run_and_wait { current_thread&.step_over }
    end

    def next_instruction
      run_and_wait { current_thread&.step_over_instruction }
    end

    def continue
      run_and_wait { process&.continue }
    end

    def finish
      run_and_wait { current_thread&.step_out }
    end

    # Breakpoints
    def breakpoint_at_address(address)
      target.breakpoint_create_by_address(address)
    end

    def breakpoint_at_name(name)
      target.breakpoint_create_by_name(name)
    end

    def breakpoint_at_line(file, line)
      target.breakpoint_create_by_location(file, line)
    end

    def list_breakpoints
      count = target.num_breakpoints
      (0...count).map { |i| target.breakpoint_at_index(i) }
    end

    def delete_breakpoint(id)
      target.breakpoint_delete(id)
    end

    # Register access
    def read_register(name)
      frame = current_frame
      return nil unless frame

      registers = frame.registers
      registers.each do |reg_set|
        reg_set.each do |reg|
          return reg.value if reg.name.downcase == name.to_s.downcase
        end
      end
      nil
    end

    def read_all_registers
      frame = current_frame
      return {} unless frame

      result = {}
      frame.registers.each do |reg_set|
        reg_set.each do |reg|
          result[reg.name.downcase.to_sym] = parse_register_value(reg.value)
        end
      end
      result
    end

    # Memory access
    def read_memory(address, size)
      @memory&.read(address, size)
    end

    def read_pointer(address)
      @memory&.read_pointer(address)
    end

    def read_string(address, max_length: 1024)
      @memory&.read_string(address, max_length: max_length)
    end

    # Symbol resolution
    def resolve_symbol(address)
      return nil unless target

      addr = target.resolve_load_address(address)
      return nil unless addr&.valid?

      symbol = addr.symbol
      return nil unless symbol&.valid?

      {
        name: symbol.name,
        start: symbol.start_address.load_address,
        end: symbol.end_address.load_address
      }
    end

    # LLDB command execution
    def execute_command(command)
      result = @debugger.execute_command(command)
      result.output
    end

    # Stop handlers
    def add_stop_handler(&block)
      @stop_handlers << block
    end

    def on_stop
      @context_renderer&.render if @config.auto_context
      @stop_handlers.each(&:call)
    end

    def terminate
      @debugger.terminate
    end

    private

    def setup_context_renderer
      @context_renderer = Context::Renderer.new(self)
    end

    def setup_memory
      @memory = Core::Memory.new(process, architecture) if process
    end

    def run_and_wait
      return unless process&.valid?

      yield
      wait_for_stop
      on_stop if process.stopped?
    end

    def wait_for_stop(timeout: 10)
      start_time = Time.now
      while Time.now - start_time < timeout
        state = process.state
        break if %i[stopped exited].include?(state)

        sleep 0.01
      end
    end

    def parse_register_value(value_str)
      return 0 if value_str.nil?

      # Handle hex values
      if value_str =~ /^0x([0-9a-fA-F]+)/
        Regexp.last_match(1).to_i(16)
      else
        value_str.to_i
      end
    end
  end
end
