# frozen_string_literal: true

module Lxdb
  module Plugins
    # Public API for plugins to interact with lxdb
    module API
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Get current session
        def current_session
          Lxdb.current_session
        end

        # Register a command dynamically
        def register_command(name, &block)
          Commands::Registry.register_dynamic(name, block)
        end
      end

      # Instance methods available to plugins

      def read_memory(address, size)
        session.read_memory(address, size)
      end

      def read_pointer(address)
        session.read_pointer(address)
      end

      def read_string(address, max_length: 1024)
        session.read_string(address, max_length: max_length)
      end

      def read_register(name)
        session.read_register(name)
      end

      def execute_command(cmd)
        session.execute_command(cmd)
      end

      def resolve_symbol(address)
        session.resolve_symbol(address)
      end

      def breakpoint_at(location)
        if location.is_a?(Integer)
          session.breakpoint_at_address(location)
        else
          session.breakpoint_at_name(location.to_s)
        end
      end

      def step
        session.step
      end

      def next_line
        session.next_line
      end

      def continue
        session.continue
      end

      def current_pc
        session.current_frame&.pc
      end

      def current_sp
        session.read_register(architecture.stack_pointer)
      end
    end
  end
end
