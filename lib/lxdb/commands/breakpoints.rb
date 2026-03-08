# frozen_string_literal: true

module Lxdb
  module Commands
    class Break < Base
      command "break", aliases: %w[b bp], description: "Set a breakpoint", category: :breakpoints

      def execute(args)
        require_target!

        location = args.first
        raise CommandError, "Usage: break <address|function|file:line>" if location.nil?

        bp = if location =~ /^0x[0-9a-fA-F]+$/
               # Address
               session.breakpoint_at_address(location.to_i(16))
             elsif location =~ /^(.+):(\d+)$/
               # file:line
               session.breakpoint_at_line(Regexp.last_match(1), Regexp.last_match(2).to_i)
             else
               # Function name
               session.breakpoint_at_name(location)
             end

        if bp&.valid?
          output(c("Breakpoint #{bp.id} set", :success))
        else
          output(c("Failed to set breakpoint at #{location}", :error))
        end
      end
    end

    class DeleteBreakpoint < Base
      command "delete", aliases: %w[d del], description: "Delete a breakpoint", category: :breakpoints

      def execute(args)
        require_target!

        id = args.first&.to_i
        raise CommandError, "Usage: delete <breakpoint-id>" if id.nil? || id.zero?

        if session.delete_breakpoint(id)
          output(c("Breakpoint #{id} deleted", :success))
        else
          output(c("Breakpoint #{id} not found", :error))
        end
      end
    end

    class ListBreakpoints < Base
      command "breakpoints", aliases: ["bl"], description: "List all breakpoints", category: :breakpoints

      def execute(_args)
        require_target!

        breakpoints = session.list_breakpoints
        if breakpoints.empty?
          output("No breakpoints set")
          return
        end

        output(c("Breakpoints:", :info))
        breakpoints.each do |bp|
          next unless bp.valid?

          status = bp.enabled? ? c("enabled", :success) : c("disabled", :warning)
          hits = bp.hit_count

          locations = []
          bp.num_locations.times do |i|
            loc = bp.location_at_index(i)
            next unless loc&.valid?

            addr = loc.address
            locations << format_address(addr.load_address)
          end

          output("  #{c("##{bp.id}", :frame_number)} #{locations.join(", ")} [#{status}] hits: #{hits}")
        end
      end
    end

    class EnableBreakpoint < Base
      command "enable", aliases: ["en"], description: "Enable a breakpoint", category: :breakpoints

      def execute(args)
        require_target!

        id = args.first&.to_i
        raise CommandError, "Usage: enable <breakpoint-id>" if id.nil? || id.zero?

        bp = session.target.find_breakpoint_by_id(id)
        if bp&.valid?
          bp.enabled = true
          output(c("Breakpoint #{id} enabled", :success))
        else
          output(c("Breakpoint #{id} not found", :error))
        end
      end
    end

    class DisableBreakpoint < Base
      command "disable", aliases: ["dis"], description: "Disable a breakpoint", category: :breakpoints

      def execute(args)
        require_target!

        id = args.first&.to_i
        raise CommandError, "Usage: disable <breakpoint-id>" if id.nil? || id.zero?

        bp = session.target.find_breakpoint_by_id(id)
        if bp&.valid?
          bp.enabled = false
          output(c("Breakpoint #{id} disabled", :success))
        else
          output(c("Breakpoint #{id} not found", :error))
        end
      end
    end
  end
end
