# frozen_string_literal: true

module Lxdb
  module Plugins
    class Loader
      DEFAULT_PLUGIN_PATHS = [
        File.expand_path("~/.lxdb/plugins"),
        File.expand_path("./lxdb_plugins")
      ].freeze

      attr_reader :loaded_plugins, :plugin_paths

      def initialize(session, paths: nil)
        @session = session
        @plugin_paths = paths || DEFAULT_PLUGIN_PATHS
        @loaded_plugins = []
      end

      def load_all
        @plugin_paths.each do |path|
          load_from_directory(path) if Dir.exist?(path)
        end
        @loaded_plugins
      end

      def load_plugin(path)
        return unless File.exist?(path)

        begin
          path = File.expand_path(path)

          # Load the plugin file
          load path

          # Find newly defined plugin classes
          new_plugins = Registry.pending_plugins
          new_plugins.each do |plugin_class|
            plugin = plugin_class.new(@session)
            plugin.setup
            @loaded_plugins << plugin
            puts "Loaded plugin: #{plugin_class.plugin_info[:name]}" if @session.config.debug
          end
          Registry.clear_pending

          true
        rescue StandardError => e
          warn "Failed to load plugin #{path}: #{e.message}"
          false
        end
      end

      def load_from_directory(dir)
        Dir.glob(File.join(dir, "*.rb")).each do |file|
          load_plugin(file)
        end

        # Also load plugins from subdirectories with init.rb
        Dir.glob(File.join(dir, "*", "init.rb")).each do |file|
          load_plugin(file)
        end
      end

      def unload_plugin(name)
        plugin_name = normalize_plugin_name(name)
        plugin = @loaded_plugins.find { |p| normalize_plugin_name(p.class.plugin_info[:name]) == plugin_name }
        return false unless plugin

        plugin.teardown if plugin.respond_to?(:teardown)
        Commands::Registry.unregister_owner(plugin_name)
        @loaded_plugins.delete(plugin)
        true
      end

      def reload_all
        @loaded_plugins.each do |plugin|
          plugin.teardown if plugin.respond_to?(:teardown)
          Commands::Registry.unregister_owner(plugin.class.plugin_info[:name])
        end
        @loaded_plugins.clear
        Registry.clear
        load_all
      end

      private

      def normalize_plugin_name(name)
        name.to_s
      end
    end
  end
end
