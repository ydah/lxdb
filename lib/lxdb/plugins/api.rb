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
        def register_command(name, aliases: [], description: "", category: :plugin, &block)
          Commands::Registry.register_dynamic(
            name,
            block,
            aliases: aliases,
            description: description,
            category: category,
            owner: plugin_name
          )
        end

        def plugin_name
          respond_to?(:plugin_info) ? plugin_info&.fetch(:name, nil) : nil
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

    Base.include(API) if const_defined?(:Base)
  end
end
