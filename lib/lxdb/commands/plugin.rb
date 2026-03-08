# frozen_string_literal: true

module Lxdb
  module Commands
    class PluginCommand < Base
      command "plugin", aliases: ["plugins"], description: "Manage plugins", category: :info

      def execute(args)
        subcommand = args.first

        case subcommand
        when "list", "ls"
          list_plugins
        when "load"
          load_plugin(args[1])
        when "unload"
          unload_plugin(args[1])
        when "reload"
          reload_plugins
        else
          show_help
        end
      end

      private

      def list_plugins
        loader = session.plugin_loader
        plugins = loader&.loaded_plugins || []

        if plugins.empty?
          output(c("No plugins loaded", :info))
          return
        end

        output(c("Loaded Plugins:", :banner))
        output("")

        plugins.each do |plugin|
          info = plugin.class.plugin_info
          name = c(info[:name].to_s.ljust(20), :function_name)
          version = c("v#{info[:version]}", :comment)
          desc = info[:description]
          output("  #{name} #{version}")
          output("    #{desc}") unless desc.empty?
        end
      end

      def load_plugin(path)
        if path.nil?
          output(c("Usage: plugin load <path>", :error))
          return
        end

        loader = session.plugin_loader
        if loader&.load_plugin(File.expand_path(path))
          output(c("Plugin loaded: #{path}", :success))
        else
          output(c("Failed to load plugin: #{path}", :error))
        end
      end

      def unload_plugin(name)
        if name.nil?
          output(c("Usage: plugin unload <name>", :error))
          return
        end

        loader = session.plugin_loader
        if loader&.unload_plugin(name)
          output(c("Plugin unloaded: #{name}", :success))
        else
          output(c("Plugin not found: #{name}", :error))
        end
      end

      def reload_plugins
        loader = session.plugin_loader
        loader&.reload_all
        output(c("Plugins reloaded", :success))
      end

      def show_help
        output(c("Plugin commands:", :info))
        output("  plugin list           - List loaded plugins")
        output("  plugin load <path>    - Load a plugin")
        output("  plugin unload <name>  - Unload a plugin")
        output("  plugin reload         - Reload all plugins")
      end
    end
  end
end
