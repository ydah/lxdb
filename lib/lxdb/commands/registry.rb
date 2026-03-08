# frozen_string_literal: true

module Lxdb
  module Commands
    class Registry
      @commands = {}
      @aliases = {}

      class << self
        attr_reader :commands, :aliases

        def register(command_class)
          return if command_class == Base

          name = command_class.command_name
          return unless name

          @commands[name] = command_class

          command_class.aliases&.each do |alias_name|
            @aliases[alias_name] = name
          end
        end

        def find(name)
          return nil if name.nil?

          name = name.to_s.downcase
          @commands[name] || @commands[@aliases[name]]
        end

        def all
          @commands.values.uniq
        end

        def by_category
          all.group_by(&:category)
        end

        def command_names
          @commands.keys + @aliases.keys
        end

        def clear
          @commands = {}
          @aliases = {}
        end
      end
    end
  end
end

# Load built-in commands
require_relative "navigation"
require_relative "breakpoints"
require_relative "memory_commands"
require_relative "info"
require_relative "thread"
require_relative "heap"
require_relative "exploit"
require_relative "plugin"
