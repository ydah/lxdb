# frozen_string_literal: true

module Lxdb
  module Commands
    class Registry
      @commands = {}
      @aliases = {}
      @command_owners = {}

      class << self
        attr_reader :commands, :aliases

        def register(command_class, owner: nil)
          return if command_class == Base

          name = command_class.command_name&.to_s&.downcase
          return unless name

          remove_aliases_for(name)
          @commands[name] = command_class
          @command_owners[name] = owner_key(owner) if owner

          command_class.aliases&.each do |alias_name|
            @aliases[alias_name.to_s.downcase] = name
          end
        end

        def register_dynamic(name, block = nil, aliases: [], description: "", category: :plugin, owner: nil, &command_block)
          callback = block || command_block
          raise CommandError, "Dynamic command requires a block" unless callback

          command_class = Class.new(Base) do
            command name, aliases: aliases, description: description, category: category

            define_method(:execute) do |args|
              case callback.arity
              when 0
                instance_exec(&callback)
              when 1
                callback.call(args)
              else
                callback.call(args, self)
              end
            end
          end

          register(command_class, owner: owner)
          command_class
        end

        def unregister(name)
          command_name = name.to_s.downcase
          command_name = @aliases[command_name] if @aliases.key?(command_name)
          return unless command_name

          @commands.delete(command_name)
          @command_owners.delete(command_name)
          remove_aliases_for(command_name)
        end

        def unregister_owner(owner)
          target_owner = owner_key(owner)
          command_names = @command_owners.select { |_name, command_owner| command_owner == target_owner }.keys
          command_names.each { |command_name| unregister(command_name) }
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
          @command_owners = {}
        end

        private

        def remove_aliases_for(command_name)
          @aliases.delete_if { |_alias_name, alias_target| alias_target == command_name }
        end

        def owner_key(owner)
          owner.to_s
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
