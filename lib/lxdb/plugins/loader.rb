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
        return false unless File.exist?(path)

        loaded_from_file = []
        initialized_from_file = []
        new_plugins = []
        begin
          path = File.expand_path(path)

          # Load the plugin file
          load path

          # Find newly defined plugin classes
          new_plugins = Registry.pending_plugins
          new_plugins.each do |plugin_class|
            plugin = plugin_class.new(@session)
            initialized_from_file << plugin
            plugin.setup
            @loaded_plugins << plugin
            loaded_from_file << plugin
            puts "Loaded plugin: #{plugin_class.plugin_info[:name]}" if @session.config.debug
          end

          true
        rescue StandardError => e
          cleanup_failed_load(new_plugins, initialized_from_file, loaded_from_file)
          warn "Failed to load plugin #{path}: #{e.message}"
          false
        ensure
          Registry.clear_pending
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

        teardown_plugin(plugin)
        Commands::Registry.unregister_owner(plugin_name)
        @loaded_plugins.delete(plugin)
        true
      end

      def reload_all
        @loaded_plugins.each do |plugin|
          teardown_plugin(plugin)
          Commands::Registry.unregister_owner(plugin.class.plugin_info[:name])
        end
        @loaded_plugins.clear
        Registry.clear
        load_all
      end

      private

      def teardown_plugin(plugin)
        plugin.teardown if plugin.respond_to?(:teardown)
      rescue StandardError
        nil
      end

      def normalize_plugin_name(name)
        name.to_s
      end

      def cleanup_failed_load(plugin_classes, initialized_plugins, loaded_plugins)
        initialized_plugins.each do |plugin|
          plugin.teardown if plugin.respond_to?(:teardown)
        rescue StandardError
          nil
        end

        loaded_plugins.each do |plugin|
          @loaded_plugins.delete(plugin)
        end

        plugin_classes.each do |plugin_class|
          plugin_name = normalize_plugin_name(plugin_class.plugin_info[:name])
          Commands::Registry.unregister_owner(plugin_name)
          Registry.unregister(plugin_name)
        end
      end
    end
  end
end
