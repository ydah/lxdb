# frozen_string_literal: true

module Lxdb
  module UI
    module CommandNormalizer
      module_function

      def normalize_x_command(command_name, args)
        return [command_name, args] unless command_name&.start_with?("x/")

        match = command_name.match(/\Ax\/(\d+)?(?:[a-zA-Z]+)?\z/)
        return ["examine", args] unless match

        count = match[1]&.to_i
        return ["examine", []] if args.empty?

        normalized = [args[0]]
        normalized << count.to_s if count && count.positive?
        normalized += args[1..] if args.length > 1
        ["examine", normalized]
      end
    end
  end
end
