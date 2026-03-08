# frozen_string_literal: true

module Lxdb
  module Core
    class Memory
      # メモリ読み取り結果を表すクラス
      class ReadResult
        attr_reader :data, :error, :address, :size

        def initialize(address:, size:, data: nil, error: nil)
          @data = data
          @error = error
          @address = address
          @size = size
        end

        def success?
          @error.nil? && !@data.nil?
        end

        def failed?
          !success?
        end

        def error_message
          return nil if success?

          @error&.to_s || "Unknown error reading memory at 0x#{@address.to_s(16)}"
        end
      end

      attr_reader :process, :architecture

      # オプション設定
      attr_accessor :raise_on_error, :log_errors

      def initialize(process, architecture)
        @process = process
        @architecture = architecture
        @raise_on_error = true # デフォルトは従来どおり例外を投げる
        @log_errors = true
      end

      # 基本の読み取り（エラー時に例外を投げる従来の動作）
      def read(address, size)
        result = read_safe(address, size)

        if result.failed?
          log_read_error(result) if @log_errors
          raise DebuggerError, result.error_message if @raise_on_error
        end

        result.data
      end

      # 安全な読み取り（例外を投げない、ReadResultを返す）
      def read_safe(address, size)
        if address.nil?
          return ReadResult.new(
            error: "Invalid address (nil)",
            address: 0,
            size: size
          )
        end

        if size.nil? || size <= 0
          return ReadResult.new(
            error: "Invalid size: #{size}",
            address: address,
            size: size || 0
          )
        end

        if address < 0x1000
          return ReadResult.new(
            error: "Address likely unmapped (too low: 0x#{address.to_s(16)})",
            address: address,
            size: size
          )
        end

        error = LLDB::SBError.new
        data = @process.read_memory(address, size, error)

        if error.success? && data
          ReadResult.new(data: data, address: address, size: size)
        else
          ReadResult.new(
            error: parse_memory_error(error, address, size),
            address: address,
            size: size
          )
        end
      end

      # nilを返すバージョン（エラー時）
      def read_or_nil(address, size)
        result = read_safe(address, size)
        result.success? ? result.data : nil
      end

      # デフォルト値を返すバージョン
      def read_or_default(address, size, default:)
        result = read_safe(address, size)
        result.success? ? result.data : default
      end

      def read_pointer(address)
        size = @architecture.pointer_size
        data = read(address, size)
        unpack_pointer(data)
      end

      def read_pointer_safe(address)
        size = @architecture.pointer_size
        result = read_safe(address, size)
        return nil unless result.success?

        unpack_pointer(result.data)
      end

      def read_u8(address)
        read(address, 1).unpack1("C")
      end

      def read_u8_safe(address)
        result = read_safe(address, 1)
        result.success? ? result.data.unpack1("C") : nil
      end

      def read_u16(address)
        format = @architecture.endian == :little ? "v" : "n"
        read(address, 2).unpack1(format)
      end

      def read_u16_safe(address)
        format = @architecture.endian == :little ? "v" : "n"
        result = read_safe(address, 2)
        result.success? ? result.data.unpack1(format) : nil
      end

      def read_u32(address)
        format = @architecture.endian == :little ? "V" : "N"
        read(address, 4).unpack1(format)
      end

      def read_u32_safe(address)
        format = @architecture.endian == :little ? "V" : "N"
        result = read_safe(address, 4)
        result.success? ? result.data.unpack1(format) : nil
      end

      def read_u64(address)
        format = @architecture.endian == :little ? "Q<" : "Q>"
        read(address, 8).unpack1(format)
      end

      def read_u64_safe(address)
        format = @architecture.endian == :little ? "Q<" : "Q>"
        result = read_safe(address, 8)
        result.success? ? result.data.unpack1(format) : nil
      end

      def read_string(address, max_length: 1024)
        result = +""
        offset = 0

        while offset < max_length
          byte = read_u8_safe(address + offset)
          break if byte.nil? || byte.zero?

          result << byte.chr
          offset += 1
        end

        result
      end

      def write(address, data)
        error = LLDB::SBError.new
        bytes_written = @process.write_memory(address, data, error)
        raise DebuggerError, "Failed to write memory at 0x#{address.to_s(16)}: #{error}" unless error.success?

        bytes_written
      end

      # 読み取り可能かどうかをチェック
      def readable?(address, size = 1)
        return false if address.nil? || address < 0x1000

        read_safe(address, size).success?
      end

      def valid_pointer?(address)
        return false if address.nil?
        return false if address.zero?
        return false if address < 0x1000

        readable?(address, 1)
      end

      # メモリ領域情報を取得
      def memory_region_info(address)
        return nil unless @process.respond_to?(:get_memory_region_info)

        region_info = LLDB::SBMemoryRegionInfo.new
        error = LLDB::SBError.new
        @process.get_memory_region_info(address, region_info, error)

        return nil unless error.success?

        {
          base: region_info.region_base,
          end: region_info.region_end,
          readable: region_info.readable?,
          writable: region_info.writable?,
          executable: region_info.executable?
        }
      rescue StandardError
        nil
      end

      def telescope(address, count: 10, max_depth: 5)
        results = []
        pointer_size = @architecture.pointer_size

        count.times do |i|
          current_addr = address + (i * pointer_size)
          chain = resolve_pointer_chain(current_addr, max_depth: max_depth)
          results << { offset: i * pointer_size, address: current_addr, chain: chain }
        end

        results
      end

      def resolve_pointer_chain(address, max_depth: 5, depth: 0)
        chain = []

        value = read_pointer_safe(address)
        return chain if value.nil?

        chain << { type: :pointer, value: value }

        if depth < max_depth && valid_pointer?(value)
          # Try to read as string first
          str = try_read_string(value)
          if str && !str.empty? && printable_string?(str)
            chain << { type: :string, value: str }
          else
            # Continue dereferencing
            sub_chain = resolve_pointer_chain(value, max_depth: max_depth, depth: depth + 1)
            chain.concat(sub_chain) unless sub_chain.empty?
          end
        end

        chain
      end

      private

      def parse_memory_error(lldb_error, address, size)
        message = lldb_error.to_s

        case message
        when /invalid address/i, /bad address/i
          "Invalid memory address: 0x#{address.to_s(16)} (size: #{size})"
        when /unmapped/i
          "Memory region 0x#{address.to_s(16)} is not mapped"
        when /permission/i, /protected/i
          "No permission to read memory at 0x#{address.to_s(16)}"
        when /process.*not.*running/i
          "Cannot read memory - process is not running"
        else
          "Memory read failed at 0x#{address.to_s(16)} (size: #{size}): #{message}"
        end
      end

      def log_read_error(result)
        Lxdb.logger&.debug(
          "Memory read error: address=0x#{result.address.to_s(16)} " \
          "size=#{result.size} error=#{result.error_message}"
        )
      end

      def unpack_pointer(data)
        format = if @architecture.pointer_size == 8
                   @architecture.endian == :little ? "Q<" : "Q>"
                 else
                   @architecture.endian == :little ? "V" : "N"
                 end
        data.unpack1(format)
      end

      def try_read_string(address, max_length: 64)
        read_string(address, max_length: max_length)
      rescue StandardError
        nil
      end

      def printable_string?(str)
        return false if str.nil? || str.empty?
        return false if str.length < 2

        str.bytes.all? { |b| (b >= 0x20 && b <= 0x7E) || b == 0x09 || b == 0x0A || b == 0x0D }
      end
    end
  end
end
