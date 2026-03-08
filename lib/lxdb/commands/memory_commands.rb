# frozen_string_literal: true

module Lxdb
  module Commands
    class Examine < Base
      command "examine", aliases: %w[x], description: "Examine memory", category: :memory

      def execute(args)
        require_stopped!

        address = parse_address(args.first)
        raise CommandError, "Usage: examine <address>" unless address

        count = (args[1] || 16).to_i

        output(hexdump(address, count))
      end

      private

      def hexdump(address, size)
        lines = []
        bytes_per_line = 16

        data = session.read_memory(address, size)
        return c("Failed to read memory at #{format_address(address)}", :error) unless data

        data.bytes.each_slice(bytes_per_line).with_index do |chunk, i|
          addr = address + (i * bytes_per_line)
          addr_str = c(format_address(addr), :address)

          # Hex bytes
          hex_str = chunk.map { |b| format("%02x", b) }.join(" ")
          hex_str = hex_str.ljust(bytes_per_line * 3 - 1)

          # ASCII representation
          ascii_str = chunk.map { |b| b >= 0x20 && b <= 0x7E ? b.chr : "." }.join
          ascii_str = c(ascii_str, :string)

          lines << "#{addr_str}  #{hex_str}  |#{ascii_str}|"
        end

        lines.join("\n")
      end
    end

    class Telescope < Base
      command "telescope", aliases: %w[tel dereference], description: "Recursively dereference pointers", category: :memory

      def execute(args)
        require_stopped!

        address = if args.empty?
                    # Default to $sp
                    session.read_register(session.architecture.stack_pointer)
                  else
                    parse_address(args.first)
                  end

        raise CommandError, "Invalid address" unless address

        count = (args[1] || 10).to_i

        output(format_telescope(address, count))
      end

      private

      def format_telescope(address, count)
        lines = []
        pointer_size = session.architecture.pointer_size

        count.times do |i|
          current_addr = address + (i * pointer_size)
          lines << format_entry(current_addr, i)
        end

        lines.join("\n")
      end

      def format_entry(address, index)
        offset_str = c(format("%02d:", index), :offset)
        addr_str = c(format_address(address), :address)

        begin
          value = session.read_pointer(address)
          value_str = c(format_address(value), :value)
          chain = resolve_chain(value)

          "#{offset_str} #{addr_str} -> #{value_str}#{chain}"
        rescue StandardError
          "#{offset_str} #{addr_str} -> #{c("(unreadable)", :error)}"
        end
      end

      def resolve_chain(value, depth: 0, max_depth: 4)
        return "" if depth >= max_depth
        return "" if value.zero?
        return "" unless session.memory&.valid_pointer?(value)

        chain = []

        # Try symbol
        if (sym = session.resolve_symbol(value))
          chain << c(" -> ", :pointer)
          chain << c("<#{sym[:name]}>", :symbol)
          return chain.join
        end

        # Try string
        str = session.read_string(value, max_length: 32)
        if str && !str.empty? && printable?(str)
          chain << c(" -> ", :pointer)
          chain << c("\"#{str}\"", :string)
          return chain.join
        end

        # Continue chain
        begin
          next_value = session.read_pointer(value)
          chain << c(" -> ", :pointer)
          chain << c(format_address(next_value), :value)
          chain << resolve_chain(next_value, depth: depth + 1)
        rescue StandardError
          # Stop here
        end

        chain.join
      end

      def printable?(str)
        str.bytes.all? { |b| (b >= 0x20 && b <= 0x7E) || [0x09, 0x0A, 0x0D].include?(b) }
      end
    end

    class Search < Base
      command "search", aliases: %w[find], description: "Search memory for a pattern", category: :memory

      def execute(args)
        require_stopped!

        pattern = args.first
        raise CommandError, "Usage: search <pattern|0xhex>" unless pattern

        # Convert pattern to bytes
        bytes = if pattern =~ /^0x([0-9a-fA-F]+)$/
                  [Regexp.last_match(1)].pack("H*")
                else
                  pattern
                end

        output(c("Searching for: #{bytes.inspect}", :info))
        output(c("(Memory search not fully implemented yet)", :warning))
      end
    end

    class Vmmap < Base
      command "vmmap", aliases: ["maps"], description: "Show memory mappings", category: :memory

      def execute(_args)
        require_process!

        result = session.execute_command("memory region --all")
        output(result)
      end
    end
  end
end
