# frozen_string_literal: true

module Lxdb
  module Plugins
    class Registry
      @plugins = {}
      @pending = []

      class << self
        attr_reader :plugins

        def register(plugin_class)
          plugin_info = plugin_class.plugin_info
          return unless plugin_info.is_a?(Hash)

          name = plugin_info[:name]
          return unless name

          @plugins[name] = plugin_class
          @pending << plugin_class unless @pending.include?(plugin_class)
        end

        def find(name)
          @plugins[name]
        end

        def all
          @plugins.values
        end

        def pending_plugins
          @pending.dup
        end

        def clear_pending
          @pending.clear
        end

        def clear
          @plugins.clear
          @pending.clear
        end
      end
    end
  end
end
