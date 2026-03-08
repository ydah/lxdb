# frozen_string_literal: true

module Lxdb
  module UI
    module TUI
      module Panels
        class Disasm < Base
          BRANCH_MNEMONICS = %w[jmp je jne jz jnz jg jge jl jle ja jae jb jbe call].freeze
          RET_MNEMONICS = %w[ret retf retn].freeze
          STACK_MNEMONICS = %w[push pop].freeze

          def initialize(session, region)
            super(session, region, title: "DISASSEMBLY")
          end

          def draw_content
            clear_content

            unless @session.process&.stopped?
              draw_line(0, "(no process)", color: COLOR_YELLOW)
              return
            end

            frame = @session.current_frame
            return draw_line(0, "(no frame)", color: COLOR_YELLOW) unless frame

            pc = frame.pc
            instructions = disassemble_around(pc)

            instructions.each_with_index do |insn, idx|
              break if idx >= content_region[:height]

              draw_instruction(idx, insn, is_current: insn[:address] == pc)
            end
          end

          private

          def disassemble_around(_pc)
            result = @session.execute_command("disassemble -p -c #{content_region[:height]}")
            parse_disassembly(result)
          end

          def parse_disassembly(output)
            instructions = []
            return instructions if output.nil? || output.empty?

            output.each_line do |line|
              line = line.strip.sub(/^->\s*/, "")
              next if line.empty?

              match = line.match(/^(0x[0-9a-fA-F]+)\s*(?:<[^>]*>)?:?\s*(.*)$/)
              next unless match

              address = match[1].to_i(16)
              instruction_text = match[2].strip
              parts = instruction_text.split(/\s+/, 2)

              instructions << {
                address: address,
                mnemonic: (parts[0] || "").downcase,
                operands: parts[1] || "",
                raw: instruction_text
              }
            end

            instructions
          end

          def draw_instruction(y, insn, is_current: false)
            x = 0
            content = content_region

            # Current instruction arrow
            if is_current
              draw_text(y, x, "=>", color: COLOR_GREEN, bold: true)
            end
            x += 3

            # Address
            addr_str = format("0x%x", insn[:address])
            draw_text(y, x, addr_str, color: COLOR_CYAN)
            x += addr_str.length + 2

            # Mnemonic
            mnemonic_color = mnemonic_color(insn[:mnemonic])
            draw_text(y, x, insn[:mnemonic].ljust(8), color: mnemonic_color, bold: is_current)
            x += 9

            # Operands (simplified - just draw as white)
            remaining = content[:width] - x
            return unless remaining.positive?

            draw_text(y, x, insn[:operands][0...remaining], color: COLOR_WHITE)
          end

          def mnemonic_color(mnemonic)
            case mnemonic
            when *BRANCH_MNEMONICS then COLOR_YELLOW
            when *RET_MNEMONICS then COLOR_RED
            when *STACK_MNEMONICS then COLOR_MAGENTA
            else COLOR_WHITE
            end
          end
        end
      end
    end
  end
end
