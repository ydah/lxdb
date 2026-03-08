# frozen_string_literal: true

module Lxdb
  module Context
    class Disassembly < Base
      BRANCH_MNEMONICS = %w[
        jmp je jne jz jnz jg jge jl jle ja jae jb jbe
        jo jno js jns jp jnp jcxz jecxz jrcxz
        loop loope loopne loopz loopnz
      ].freeze

      CALL_MNEMONICS = %w[call].freeze
      RET_MNEMONICS = %w[ret retf retn iret iretd iretq].freeze
      STACK_MNEMONICS = %w[push pop pusha pushad popa popad pushf pushfd popf popfd enter leave].freeze
      DATA_MNEMONICS = %w[mov movsx movsxd movzx lea xchg].freeze
      COMPARE_MNEMONICS = %w[cmp test].freeze
      NOP_MNEMONICS = %w[nop].freeze
      SYSCALL_MNEMONICS = %w[syscall sysenter int].freeze

      def render
        frame = current_frame
        return nil unless frame

        pc = frame.pc
        output = [banner("DISASSEMBLY")]

        instructions = disassemble_around(pc)
        instructions.each do |insn|
          output << format_instruction(insn, is_current: insn[:address] == pc)
        end

        output.join("\n")
      end

      private

      def disassemble_around(pc)
        lines_before = config.disasm_lines_before
        lines_after = config.disasm_lines_after
        total_lines = lines_before + lines_after + 1

        # Use LLDB's disassemble command
        result = session.execute_command("disassemble -p -c #{total_lines}")
        parse_disassembly(result, pc, lines_before)
      end

      def parse_disassembly(output, _pc, _lines_before)
        instructions = []
        return instructions if output.nil? || output.empty?

        output.each_line do |line|
          # Parse lines like: "0x555555555149 <+4>:  mov    edi, 0x1"
          # or: "->  0x555555555149 <+4>:  mov    edi, 0x1"
          line = line.strip
          next if line.empty?

          # Remove arrow indicator if present
          line = line.sub(/^->\s*/, "")

          # Match address, optional symbol, and instruction
          match = line.match(/^(0x[0-9a-fA-F]+)\s*(?:<[^>]*>)?:?\s*(.*)$/)
          next unless match

          address = match[1].to_i(16)
          instruction_text = match[2].strip

          # Split mnemonic and operands
          parts = instruction_text.split(/\s+/, 2)
          mnemonic = parts[0] || ""
          operands = parts[1] || ""

          instructions << {
            address: address,
            mnemonic: mnemonic.downcase,
            operands: operands,
            raw: instruction_text
          }
        end

        instructions
      end

      def format_instruction(insn, is_current: false)
        # Arrow for current instruction
        arrow = is_current ? c(" => ", :current_arrow) : "    "

        # Address
        addr_str = c(format_address(insn[:address]), :address)

        # Mnemonic with syntax highlighting
        mnemonic_str = colorize_mnemonic(insn[:mnemonic])

        # Operands with syntax highlighting
        operands_str = colorize_operands(insn[:operands])

        # Comment/annotation
        comment = generate_comment(insn)

        "#{arrow}#{addr_str}: #{mnemonic_str.ljust(10)} #{operands_str}#{comment}"
      end

      def colorize_mnemonic(mnemonic)
        style = case mnemonic.downcase
                when *CALL_MNEMONICS
                  :mnemonic_call
                when *RET_MNEMONICS
                  :mnemonic_ret
                when *BRANCH_MNEMONICS
                  :mnemonic_branch
                when *STACK_MNEMONICS
                  :mnemonic_stack
                when *DATA_MNEMONICS
                  :mnemonic_data
                when *COMPARE_MNEMONICS
                  :mnemonic_compare
                when *NOP_MNEMONICS
                  :mnemonic_nop
                when *SYSCALL_MNEMONICS
                  :mnemonic_syscall
                else
                  :mnemonic_default
                end
        c(mnemonic, style)
      end

      def colorize_operands(operands)
        return "" if operands.nil? || operands.empty?

        # Simple colorization - could be made more sophisticated
        result = operands.dup

        # Colorize registers
        architecture.general_purpose_registers.each do |reg|
          reg_pattern = /\b(#{reg}|#{reg.to_s.upcase})\b/
          result = result.gsub(reg_pattern) { c(Regexp.last_match(1), :operand_register) }
        end

        # Colorize immediate values (0x...)
        result = result.gsub(/(0x[0-9a-fA-F]+)/) { c(Regexp.last_match(1), :operand_immediate) }

        # Colorize decimal numbers
        result = result.gsub(/\b(\d+)\b/) { c(Regexp.last_match(1), :operand_immediate) }

        # Colorize memory references [...]
        result.gsub(/(\[[^\]]+\])/) { c(Regexp.last_match(1), :operand_memory) }
      end

      def generate_comment(insn)
        comments = []
        mnemonic = insn[:mnemonic].downcase

        # For call/branch instructions, try to resolve target
        # Extract target address from operands
        if (CALL_MNEMONICS.include?(mnemonic) || BRANCH_MNEMONICS.include?(mnemonic)) && (match = insn[:operands].match(/0x([0-9a-fA-F]+)/))
          target = match[1].to_i(16)
          if (sym = resolve_symbol(target))
            comments << "<#{sym[:name]}>"
          end
        end

        return "" if comments.empty?

        c("    ; #{comments.join(", ")}", :comment)
      end
    end
  end
end
