# frozen_string_literal: true

module Lxdb
  module Commands
    class Examine < Base
      command "examine", aliases: %w[x hexdump], description: "Examine memory", category: :memory

      def execute(args)
        require_stopped!

        address = parse_address(args.first)
        raise CommandError, "Usage: examine <address>" unless address

        options = parse_examine_options(args[1..] || [])
        count = options[:count]
        format_spec = options[:format_spec]

        if format_spec
          output(format_memory(address, count.positive? ? count : 1, format_spec))
        else
          output(hexdump(address, count.positive? ? count : 16))
        end
      end

      private

      FORMAT_CHARS = %w[x d u o t a c s i].freeze
      UNIT_SIZES = {
        "b" => 1,
        "h" => 2,
        "w" => 4,
        "g" => 8
      }.freeze
      DEFAULT_HEXDUMP_SIZE = 16
      DEFAULT_FORMAT_COUNT = 1
      DEFAULT_STRING_LENGTH = 256

      def parse_examine_options(args)
        count = nil
        raw_format = nil

        args.each do |arg|
          token = arg.to_s
          if count.nil? && token.match?(/\A\d+\z/)
            count = token.to_i
          elsif raw_format.nil? && format_spec_token?(token)
            raw_format = token
          end
        end

        format_spec = parse_format_spec(raw_format)
        count = default_count(format_spec) unless count&.positive?

        { count: count, format_spec: format_spec }
      end

      def format_spec_token?(token)
        return false if token.empty?

        token.each_char.all? { |char| FORMAT_CHARS.include?(char) || UNIT_SIZES.key?(char) }
      end

      def default_count(format_spec)
        return DEFAULT_HEXDUMP_SIZE unless format_spec
        return DEFAULT_STRING_LENGTH if format_spec[:format] == "s"

        DEFAULT_FORMAT_COUNT
      end

      def parse_format_spec(raw)
        return nil if raw.nil? || raw.empty?

        spec = { format: "x", unit_size: session.architecture.pointer_size }
        raw.each_char do |char|
          if UNIT_SIZES.key?(char)
            spec[:unit_size] = UNIT_SIZES[char]
          elsif FORMAT_CHARS.include?(char)
            spec[:format] = char
          end
        end
        spec
      end

      def format_memory(address, count, spec)
        return disassemble_memory(address, count) if spec[:format] == "i"
        return format_string(address, count) if spec[:format] == "s"

        unit_size = spec[:unit_size]
        data = session.read_memory(address, count * unit_size)
        return c("Failed to read memory at #{format_address(address)}", :error) unless data

        values = data.bytes.each_slice(unit_size).take(count).map.with_index do |bytes, index|
          next if bytes.size < unit_size

          value = unpack_value(bytes.pack("C*"), unit_size)
          [address + (index * unit_size), value]
        end.compact

        values_per_line = [16 / unit_size, 1].max
        values.each_slice(values_per_line).map do |entries|
          line_address = c(format_address(entries.first[0]), :address)
          formatted = entries.map { |_entry_address, value| format_examined_value(value, spec[:format], unit_size) }
          "#{line_address}: #{formatted.join("  ")}"
        end.join("\n")
      end

      def disassemble_memory(address, count)
        session.execute_command("disassemble -s #{address} -c #{count}")
      end

      def format_string(address, count)
        value = session.read_string(address, max_length: count)
        return c("Failed to read string at #{format_address(address)}", :error) unless value

        "#{c(format_address(address), :address)}: #{c(value.inspect, :string)}"
      end

      def unpack_value(data, unit_size)
        case unit_size
        when 1
          data.unpack1("C")
        when 2
          data.unpack1(session.architecture.endian == :little ? "v" : "n")
        when 4
          data.unpack1(session.architecture.endian == :little ? "V" : "N")
        else
          data.unpack1(session.architecture.endian == :little ? "Q<" : "Q>")
        end
      end

      def format_examined_value(value, format_char, unit_size)
        case format_char
        when "d"
          signed_value(value, unit_size).to_s
        when "u"
          value.to_s
        when "o"
          "0#{value.to_s(8)}"
        when "t"
          value.to_s(2)
        when "a"
          format_address(value)
        when "c"
          printable_byte?(value) ? "'#{value.chr}'" : format("0x%02x", value & 0xff)
        else
          format("0x%0#{unit_size * 2}x", value)
        end
      end

      def signed_value(value, unit_size)
        bits = unit_size * 8
        sign_bit = 1 << (bits - 1)
        return value unless (value & sign_bit) != 0

        value - (1 << bits)
      end

      def printable_byte?(value)
        byte = value & 0xff
        byte >= 0x20 && byte <= 0x7e
      end

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

        pattern, region_filter, options = parse_search_args(args)
        raise CommandError, search_usage unless pattern

        search_pattern = build_search_pattern(pattern, options)
        bytes = search_pattern[:preview]
        raise CommandError, "Search pattern is empty" if bytes.empty?

        regions = filter_search_regions(resolve_search_regions(region_filter), options[:permissions])
        raise CommandError, "No memory regions matched the request" if regions.empty?

        matches = []
        regions.each do |region_info|
          region_matches = search_region(region_info, search_pattern[:matcher], options[:max_results] - matches.size, options[:align])
          matches.concat(region_matches)
          break if matches.size >= options[:max_results]
        end
        matches = matches.take(options[:max_results])

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
        output(c("Showing first #{options[:max_results]} matches", :warning)) if matches.size >= options[:max_results]
      end

      private

      def search_usage
        "Usage: search <pattern|0xhex> [region] [--limit N] [--align N] [--perm rwx] [--regex] [--regex-window N] [--encoding utf8|utf16le|utf16be|utf32le|utf32be] [--ignore-case] [--type bytes|string|regex|u8|u16|u32|u64|i8|i16|i32|i64|ptr] [--endian little|big]"
      end

      def parse_search_args(args)
        positional = []
        options = {
          max_results: 200,
          type: :bytes,
          endian: :little,
          align: 1,
          permissions: [],
          encoding: :utf8,
          ignore_case: false,
          regex: false,
          regex_window: 4096
        }
        tokens = args.dup

        until tokens.empty?
          token = tokens.shift.to_s

          case token
          when "--limit", "--max-results"
            options[:max_results] = parse_max_results(tokens.shift)
          when /\A--(?:limit|max-results)=(.+)\z/
            options[:max_results] = parse_max_results(Regexp.last_match(1))
          when /\A(?:limit|max|results)=(.+)\z/i
            options[:max_results] = parse_max_results(Regexp.last_match(1))
          when "--align", "-a"
            options[:align] = parse_alignment(tokens.shift)
          when /\A--align=(.+)\z/i
            options[:align] = parse_alignment(Regexp.last_match(1))
          when /\Aalign=(.+)\z/i
            options[:align] = parse_alignment(Regexp.last_match(1))
          when "--perm", "--perms", "--permissions"
            options[:permissions].concat(parse_permission_filter(tokens.shift))
          when /\A--(?:perm|perms|permissions)=(.+)\z/i
            options[:permissions].concat(parse_permission_filter(Regexp.last_match(1)))
          when /\A(?:perm|perms|permissions)=(.+)\z/i
            options[:permissions].concat(parse_permission_filter(Regexp.last_match(1)))
          when "--readable", "--read"
            options[:permissions] << :readable
          when "--writable", "--write"
            options[:permissions] << :writable
          when "--executable", "--execute", "--exec"
            options[:permissions] << :executable
          when "--encoding", "--enc"
            options[:encoding] = parse_string_encoding(tokens.shift)
          when /\A--(?:encoding|enc)=(.+)\z/i
            options[:encoding] = parse_string_encoding(Regexp.last_match(1))
          when /\A(?:encoding|enc)=(.+)\z/i
            options[:encoding] = parse_string_encoding(Regexp.last_match(1))
          when "--ignore-case", "--case-insensitive", "-i"
            options[:ignore_case] = true
          when "--regex", "--regexp"
            options[:regex] = true
          when "--regex-window"
            options[:regex_window] = parse_regex_window(tokens.shift)
          when /\A--regex-window=(.+)\z/i
            options[:regex_window] = parse_regex_window(Regexp.last_match(1))
          when /\Aregex-window=(.+)\z/i
            options[:regex_window] = parse_regex_window(Regexp.last_match(1))
          when "--type", "-t"
            options[:type] = parse_pattern_type(tokens.shift)
          when /\A--type=(.+)\z/i
            options[:type] = parse_pattern_type(Regexp.last_match(1))
          when /\Atype=(.+)\z/i
            options[:type] = parse_pattern_type(Regexp.last_match(1))
          when "--endian", "-e"
            options[:endian] = parse_endian(tokens.shift)
          when /\A--endian=(.+)\z/i
            options[:endian] = parse_endian(Regexp.last_match(1))
          when /\Aendian=(.+)\z/i
            options[:endian] = parse_endian(Regexp.last_match(1))
          else
            positional << token
          end
        end

        raise CommandError, search_usage if positional.size > 2

        options[:permissions].uniq!
        [positional[0], positional[1], options]
      end

      def parse_max_results(raw)
        value = raw.to_s
        raise CommandError, "Search limit must be a positive integer" unless value.match?(/\A\d+\z/)

        parsed = value.to_i
        raise CommandError, "Search limit must be a positive integer" unless parsed.positive?

        parsed
      end

      def parse_string_encoding(raw)
        case raw.to_s.downcase.tr("_-", "")
        when "utf8", "utf"
          :utf8
        when "utf16", "utf16le"
          :utf16le
        when "utf16be"
          :utf16be
        when "utf32", "utf32le"
          :utf32le
        when "utf32be"
          :utf32be
        else
          raise CommandError, "Search encoding must be utf8, utf16le, utf16be, utf32le, or utf32be"
        end
      end

      def parse_regex_window(raw)
        value = raw.to_s
        parsed = if value.match?(/\A0x[0-9a-fA-F]+\z/)
                   value.to_i(16)
                 elsif value.match?(/\A\d+\z/)
                   value.to_i
                 end
        raise CommandError, "Regex window must be a positive integer" unless parsed&.positive?

        parsed
      end

      def parse_alignment(raw)
        value = raw.to_s
        parsed = if value.match?(/\A0x[0-9a-fA-F]+\z/)
                   value.to_i(16)
                 elsif value.match?(/\A\d+\z/)
                   value.to_i
                 end
        raise CommandError, "Search alignment must be a positive integer" unless parsed&.positive?

        parsed
      end

      def parse_permission_filter(raw)
        value = raw.to_s.downcase.strip
        case value
        when "read", "readable", "r"
          [:readable]
        when "write", "writable", "w"
          [:writable]
        when "exec", "execute", "executable", "x"
          [:executable]
        when /\A[rwx-]+\z/
          permissions = []
          permissions << :readable if value.include?("r")
          permissions << :writable if value.include?("w")
          permissions << :executable if value.include?("x")
          raise CommandError, "Search permission filter must include r, w, or x" if permissions.empty?

          permissions
        else
          raise CommandError, "Search permission filter must be readable, writable, executable, or rwx-style"
        end
      end

      def parse_pattern_type(raw)
        normalized = raw.to_s.downcase.tr("_-", "")
        case normalized
        when "bytes", "byte", "raw", "hex"
          :bytes
        when "string", "str", "text"
          :string
        when "regex", "regexp", "re"
          :regex
        when "ptr", "pointer", "addr", "address"
          :ptr
        when "u8", "uint8", "i8", "int8", "u16", "uint16", "i16", "int16",
             "u32", "uint32", "i32", "int32", "u64", "uint64", "i64", "int64"
          normalized.sub("uint", "u").sub("int", "i").to_sym
        else
          raise CommandError, "Unsupported search type: #{raw}"
        end
      end

      def parse_endian(raw)
        case raw.to_s.downcase
        when "little", "le", "l"
          :little
        when "big", "be", "b"
          :big
        else
          raise CommandError, "Search endian must be little or big"
        end
      end

      def build_search_pattern(raw, options)
        if regex_pattern_search?(options)
          matcher = regex_matcher(raw.to_s, options)
          return { matcher: matcher, preview: matcher[:preview] }
        end

        if string_pattern_search?(raw, options)
          matcher = if options[:ignore_case]
                      case_insensitive_string_matcher(raw.to_s, options[:encoding])
                    else
                      encode_string_pattern(raw.to_s, options[:encoding])
                    end
          preview = matcher.is_a?(Hash) ? matcher[:preview] : matcher
          return { matcher: matcher, preview: preview }
        end

        bytes = parse_pattern(raw, options[:type], options[:endian], options[:encoding])
        { matcher: bytes, preview: bytes }
      end

      def regex_pattern_search?(options)
        options[:regex] || options[:type] == :regex
      end

      def string_pattern_search?(raw, options)
        return true if options[:type] == :string
        return true if options[:encoding] != :utf8

        options[:ignore_case] && !raw.to_s.match?(/^0x[0-9a-fA-F]+$/)
      end

      def parse_pattern(raw, type = :bytes, endian = :little, encoding = :utf8)
        return "".b if raw.nil?

        source = raw.to_s
        return encode_string_pattern(source, encoding) if type == :string
        return parse_integer_pattern(source, type, endian) unless type == :bytes

        hex_match = source.match(/^0x([0-9a-fA-F]+)$/)
        if hex_match
          hex_value = hex_match[1]
          hex_value = "0#{hex_value}" if hex_value.length.odd?
          return [hex_value].pack("H*").b
        end

        decode_escaped_string(source)
      end

      def regex_matcher(source, options)
        return encoded_regex_matcher(source, options) unless options[:encoding] == :utf8

        regex = Regexp.new(source.b, regex_flags(options))
        window = options[:regex_window] || 4096
        {
          type: :regex,
          regex: regex,
          bytesize: window + 1,
          window: window,
          preview: source.b
        }
      rescue RegexpError => e
        raise CommandError, "Invalid search regex: #{e.message}"
      end

      def encoded_regex_matcher(source, options)
        regex = Regexp.new(source, regex_flags(options))
        window = options[:regex_window] || 4096
        {
          type: :encoded_regex,
          regex: regex,
          encoding: options[:encoding],
          unit_size: encoded_regex_unit_size(options[:encoding]),
          bytesize: window + encoded_regex_unit_size(options[:encoding]),
          window: window,
          preview: source.b
        }
      rescue RegexpError => e
        raise CommandError, "Invalid search regex: #{e.message}"
      end

      def regex_flags(options)
        options[:ignore_case] ? Regexp::IGNORECASE : 0
      end

      def encoded_regex_unit_size(encoding)
        case encoding
        when :utf16le, :utf16be
          2
        when :utf32le, :utf32be
          4
        else
          1
        end
      end

      def decode_escaped_string(source)
        source.b.gsub(/\\x([0-9a-fA-F]{2})/) { [Regexp.last_match(1)].pack("H*") }.b
      end

      def encode_string_pattern(source, encoding)
        text = decoded_string_pattern(source)
        text.encode(ruby_string_encoding(encoding)).b
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
        raise CommandError, "String search pattern cannot be encoded as #{encoding}"
      end

      def decoded_string_pattern(source)
        text = decode_escaped_string(source).dup
        text.force_encoding(Encoding::UTF_8)
        raise CommandError, "String search pattern must be valid UTF-8" unless text.valid_encoding?

        text
      end

      def ruby_string_encoding(encoding)
        case encoding
        when :utf8
          Encoding::UTF_8
        when :utf16le
          Encoding::UTF_16LE
        when :utf16be
          Encoding::UTF_16BE
        when :utf32le
          Encoding.find("UTF-32LE")
        when :utf32be
          Encoding.find("UTF-32BE")
        else
          raise CommandError, "Unsupported search encoding: #{encoding}"
        end
      end

      def case_insensitive_string_matcher(source, encoding)
        text = decoded_string_pattern(source)
        units = text.each_char.map { |char| encoded_case_variants(char, encoding) }
        {
          type: :case_insensitive_string,
          units: units,
          bytesize: units.sum { |variants| variants.first.bytesize },
          preview: encode_string_pattern(source, encoding)
        }
      end

      def encoded_case_variants(char, encoding)
        variants = [char, char.downcase, char.upcase].uniq
        encoded = variants.map { |variant| variant.encode(ruby_string_encoding(encoding)).b }.uniq
        return encoded if encoded.map(&:bytesize).uniq.one?

        [char.encode(ruby_string_encoding(encoding)).b]
      end

      def parse_integer_pattern(raw, type, endian)
        resolved_type = type == :ptr ? pointer_search_type : type
        value = parse_integer_value(raw)
        validate_integer_range!(value, resolved_type)

        [value].pack(integer_pack_template(resolved_type, endian)).b
      end

      def pointer_search_type
        session.architecture.pointer_size == 8 ? :u64 : :u32
      end

      def parse_integer_value(raw)
        source = raw.to_s
        return source.to_i(16) if source.match?(/\A-?0x[0-9a-fA-F]+\z/)
        return source.to_i(10) if source.match?(/\A-?\d+\z/)

        raise CommandError, "Integer search pattern must be decimal or 0x-prefixed hex"
      end

      def validate_integer_range!(value, type)
        bits = type.to_s[/\d+/].to_i
        signed = type.to_s.start_with?("i")
        min = signed ? -(1 << (bits - 1)) : 0
        max = signed ? (1 << (bits - 1)) - 1 : (1 << bits) - 1
        return if value >= min && value <= max

        raise CommandError, "#{type} search pattern is out of range"
      end

      def integer_pack_template(type, endian)
        case type
        when :u8 then "C"
        when :i8 then "c"
        when :u16 then endian == :little ? "S<" : "S>"
        when :i16 then endian == :little ? "s<" : "s>"
        when :u32 then endian == :little ? "L<" : "L>"
        when :i32 then endian == :little ? "l<" : "l>"
        when :u64 then endian == :little ? "Q<" : "Q>"
        when :i64 then endian == :little ? "q<" : "q>"
        else
          raise CommandError, "Unsupported search type: #{type}"
        end
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

      def filter_search_regions(regions, permissions)
        return regions if permissions.empty?

        regions.select do |entry|
          permissions.all? { |permission| region_has_permission?(entry, permission) }
        end
      end

      def region_has_permission?(region, permission)
        case permission
        when :readable
          return region[:readable] unless region[:readable].nil?

          region[:permissions].to_s.include?("r")
        when :writable
          return region[:writable] unless region[:writable].nil?

          region[:permissions].to_s.include?("w")
        when :executable
          return region[:executable] unless region[:executable].nil?

          region[:permissions].to_s.include?("x")
        else
          false
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

      def search_region(region, needle, max_results = 200, alignment = 1)
        return [] unless region[:readable]
        return [] if region[:size].nil? || region[:size] <= 0

        matches = []
        chunk_size = 0x10000
        overlap = [needle_bytesize(needle) - 1, 0].max
        carry = +""
        cursor = 0

        while cursor < region[:size] && matches.size < max_results
          remaining = region[:size] - cursor
          read_size = [chunk_size, remaining].min
          break if read_size <= 0

          result = session.memory&.read_safe(region[:start] + cursor, read_size)
          break unless result&.success?

          chunk = result.data&.b
          break if chunk.nil? || chunk.empty?

          haystack = carry + chunk
          search_pos = 0
          while (needle_match = find_needle(haystack, needle, search_pos))
            pos = needle_match[:position]
            length = needle_match[:length]
            search_pos = next_search_position(needle, pos, length)
            next if match_contained_in_carry?(pos, length, carry.bytesize)

            absolute = region[:start] + cursor + pos - carry.bytesize
            if aligned_address?(absolute, alignment)
              matches << { address: absolute, region: region }
              break if matches.size >= max_results
            end
          end

          carry = carry_text(haystack, overlap)
          cursor += read_size
        end

        matches
      end

      def needle_bytesize(needle)
        needle.is_a?(Hash) ? needle[:bytesize] : needle.bytesize
      end

      def find_needle(haystack, needle, search_pos)
        unless needle.is_a?(Hash)
          pos = haystack.index(needle, search_pos)
          return nil unless pos

          return { position: pos, length: needle.bytesize }
        end

        case needle[:type]
        when :case_insensitive_string
          find_case_insensitive_string(haystack, needle, search_pos)
        when :regex
          find_regex(haystack, needle, search_pos)
        when :encoded_regex
          find_encoded_regex(haystack, needle, search_pos)
        end
      end

      def find_case_insensitive_string(haystack, needle, search_pos)
        limit = haystack.bytesize - needle[:bytesize]
        cursor = search_pos
        while cursor <= limit
          return { position: cursor, length: needle[:bytesize] } if case_insensitive_string_at?(haystack, needle, cursor)

          cursor += 1
        end

        nil
      end

      def find_regex(haystack, needle, search_pos)
        cursor = search_pos
        while (match = needle[:regex].match(haystack.b, cursor))
          length = match[0].bytesize
          cursor = match.begin(0) + 1
          next if length.zero?

          return { position: match.begin(0), length: length }
        end

        nil
      end

      def find_encoded_regex(haystack, needle, search_pos)
        limit = haystack.bytesize - needle[:unit_size]
        cursor = search_pos
        while cursor <= limit
          length = encoded_regex_match_length_at?(haystack, needle, cursor)
          return { position: cursor, length: length } if length

          cursor += 1
        end

        nil
      end

      def encoded_regex_match_length_at?(haystack, needle, position)
        usable = haystack.bytesize - position
        usable -= usable % needle[:unit_size]
        return nil if usable <= 0

        encoded = haystack.byteslice(position, usable).dup
        encoded.force_encoding(ruby_string_encoding(needle[:encoding]))
        return nil unless encoded.valid_encoding?

        utf8 = encoded.encode(Encoding::UTF_8)
        match = needle[:regex].match(utf8)
        return nil unless match && match.begin(0).zero? && !match[0].empty?

        match[0].encode(ruby_string_encoding(needle[:encoding])).b.bytesize
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
        nil
      end

      def next_search_position(needle, position, length)
        if needle.is_a?(Hash) && %i[regex encoded_regex].include?(needle[:type])
          position + [length, 1].max
        else
          position + 1
        end
      end

      def match_contained_in_carry?(position, length, carry_size)
        position + length <= carry_size
      end

      def case_insensitive_string_at?(haystack, needle, position)
        offset = 0
        needle[:units].all? do |variants|
          matched = variants.any? do |variant|
            haystack.byteslice(position + offset, variant.bytesize) == variant
          end
          offset += variants.first.bytesize
          matched
        end
      end

      def aligned_address?(address, alignment)
        alignment <= 1 || (address % alignment).zero?
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
