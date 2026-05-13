# frozen_string_literal: true

module Lxdb
  module Commands
    class Examine < Base
      command "examine", aliases: %w[x hexdump], description: "Examine memory", category: :memory

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
        region_filter = args[1]
        raise CommandError, "Usage: search <pattern|0xhex>" unless pattern

        bytes = parse_pattern(pattern)
        raise CommandError, "Search pattern is empty" if bytes.empty?

        regions = resolve_search_regions(region_filter)
        raise CommandError, "No memory regions matched the request" if regions.empty?

        max_results = 200
        matches = []
        regions.each do |region_info|
          region_matches = search_region(region_info, bytes)
          matches.concat(region_matches)
          break if matches.size >= max_results
        end
        matches = matches.take(max_results)

        if matches.empty?
          output(c("No matches found for #{format_pattern_preview(bytes)}", :warning))
          return
        end

        output(c("Found #{matches.size} matches for #{format_pattern_preview(bytes)}", :success))
        output("")

        matches.each do |match|
          output(format_match(match))
        end
        output("")
        output(c("Showing first #{max_results} matches", :warning)) if matches.size >= max_results
      end

      private

      def parse_pattern(raw)
        return "".b if raw.nil?

        hex_match = raw.match(/^0x([0-9a-fA-F]+)$/)
        if hex_match
          hex_value = hex_match[1]
          hex_value = "0#{hex_value}" if hex_value.length.odd?
          return [hex_value].pack("H*")
        end

        raw.gsub(/\\x([0-9a-fA-F]{2})/) { [$1].pack("H*") }
      end

      def resolve_search_regions(filter)
        all = parse_memory_regions(session.execute_command("memory region --all"))
        return all unless filter

        selector = filter.to_s.strip
        return [] if selector.empty?

        if (match = selector.match(/^(0x[0-9a-fA-F]+)\s*-\s*(0x[0-9a-fA-F]+)$/i))
          start = match[1].to_i(16)
          finish = match[2].to_i(16)
          return [{
            start: start,
            end: finish,
            size: [finish - start, 0].max,
            permissions: "manual",
            readable: true,
            name: "manual range",
            raw: "manual range"
          }]
        end

        if selector.start_with?("0x")
          address = selector.to_i(16)
          return all.select { |entry| address >= entry[:start] && address < entry[:end] }
        end

        token = selector.downcase
        all.select do |entry|
          entry[:name].to_s.downcase.include?(token) ||
            entry[:raw].to_s.downcase.include?(token) ||
            entry[:permissions].to_s.downcase.include?(token)
        end
      end

      def parse_memory_regions(raw)
        regions = []
        raw.to_s.each_line do |line|
          range_match = line.match(/\[(0x[0-9a-fA-F]+)-(0x[0-9a-fA-F]+)\)/)
          next unless range_match

          start = range_match[1].to_i(16)
          finish = range_match[2].to_i(16)
          permissions = if (perm = line.match(/\b([rwx-]{3,4})\b/))
                          perm[1]
                        else
                          ""
                        end
          name = line.sub(range_match[0], "").strip

          regions << {
            start: start,
            end: finish,
            size: finish - start,
            permissions: permissions,
            readable: permissions.include?("r"),
            writable: permissions.include?("w"),
            executable: permissions.include?("x"),
            name: name,
            raw: line.strip
          }
        end

        regions
      end

      def search_region(region, needle)
        return [] unless region[:readable]
        return [] if region[:size].nil? || region[:size] <= 0

        matches = []
        chunk_size = 0x10000
        overlap = [needle.bytesize - 1, 0].max
        carry = +""
        cursor = 0

        while cursor < region[:size]
          remaining = region[:size] - cursor
          read_size = [chunk_size, remaining].min
          break if read_size <= 0

          result = session.memory&.read_safe(region[:start] + cursor, read_size)
          break unless result&.success?

          chunk = result.data
          break if chunk.nil? || chunk.empty?

          haystack = carry + chunk
          search_pos = 0
          while (pos = haystack.index(needle, search_pos))
            absolute = region[:start] + cursor + pos - carry.bytesize
            matches << { address: absolute, region: region }
            search_pos = pos + 1
          end

          carry = carry_text(haystack, overlap)
          cursor += read_size
        end

        matches
      end

      def carry_text(data, overlap)
        return +"".b if overlap <= 0

        start = [data.bytesize - overlap, 0].max
        data[start, overlap]
      end

      def format_match(match)
        location = c(format_address(match[:address]), :address)
        region = match[:region]
        region_name = region[:name].to_s.empty? ? "memory" : region[:name]
        c("#{location}  #{region_name}", :success)
      end

      def format_pattern_preview(bytes)
        hex = bytes.unpack1("H*")
        if hex.length <= 32
          "0x#{hex}"
        else
          "0x#{hex[0, 32]}..."
        end
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
