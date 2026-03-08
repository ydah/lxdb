# frozen_string_literal: true

module Lxdb
  class Config
    DEFAULTS = {
      # Context display
      context_sections: %i[registers disassembly stack backtrace],
      context_width: 80,
      auto_context: true,

      # Registers
      show_flags: true,
      show_simd: false,

      # Disassembly
      disasm_lines_before: 5,
      disasm_lines_after: 10,

      # Stack
      stack_lines: 10,

      # Theme
      theme: "default",
      color_enabled: true,

      # Debug
      debug: false
    }.freeze

    attr_accessor(*DEFAULTS.keys)

    def initialize(options = {})
      DEFAULTS.merge(options).each do |key, value|
        send(:"#{key}=", value)
      end
    end

    def to_h
      DEFAULTS.keys.each_with_object({}) do |key, hash|
        hash[key] = send(key)
      end
    end

    def self.load_from_file(path)
      return new unless File.exist?(path)

      require "yaml"
      config_data = YAML.safe_load(File.read(path), symbolize_names: true)
      new(config_data)
    rescue StandardError => e
      warn "Warning: Failed to load config from #{path}: #{e.message}"
      new
    end
  end
end
