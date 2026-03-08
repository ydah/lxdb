# frozen_string_literal: true

module Lxdb
  module Context
    class Stack < Base
      def render
        frame = current_frame
        return nil unless frame

        sp = session.read_register(architecture.stack_pointer)
        return nil unless sp

        output = [banner("STACK")]
        output << render_telescope(sp)
        output.join("\n")
      end

      private

      def render_telescope(sp)
        lines = []
        count = config.stack_lines
        pointer_size = architecture.pointer_size

        count.times do |i|
          current_addr = sp + (i * pointer_size)
          line = format_stack_entry(current_addr, i, sp)
          lines << line
        end

        lines.join("\n")
      end

      def format_stack_entry(address, index, _sp)
        pointer_size = architecture.pointer_size
        offset = index * pointer_size

        # Offset from SP
        offset_str = c(format("%+5d", offset), :offset)

        # Address
        addr_str = c(format_address(address), :address)

        # Read value at this address
        begin
          value = session.read_pointer(address)
          value_str = format_value(value)

          # Pointer chain
          chain = resolve_chain(value)

          # SP marker
          marker = index.zero? ? c(" <== $sp", :marker) : ""

          "#{offset_str}|#{addr_str}: #{value_str}#{chain}#{marker}"
        rescue StandardError
          "#{offset_str}|#{addr_str}: #{c("(unreadable)", :error)}"
        end
      end

      def format_value(value)
        if value.zero?
          c(format_address(value), :value_zero)
        else
          c(format_address(value), :value)
        end
      end

      def resolve_chain(value, depth: 0, max_depth: 4)
        return "" if depth >= max_depth
        return "" if value.zero?
        return "" unless valid_pointer?(value)

        chain = []

        # Try to resolve as symbol
        if (sym = resolve_symbol(value))
          chain << c(" -> ", :pointer)
          chain << c("<#{sym[:name]}>", :symbol)
          return chain.join
        end

        # Try to read as string
        if (str = try_read_string(value, max_length: 32))
          chain << c(" -> ", :pointer)
          escaped = str.gsub("\n", "\\n").gsub("\t", "\\t")
          chain << c("\"#{escaped}\"", :string)
          return chain.join
        end

        # Continue dereferencing
        begin
          next_value = session.read_pointer(value)
          chain << c(" -> ", :pointer)
          chain << format_value(next_value)
          chain << resolve_chain(next_value, depth: depth + 1, max_depth: max_depth)
        rescue StandardError
          # Can't read further
        end

        chain.join
      end
    end
  end
end
