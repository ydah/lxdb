# frozen_string_literal: true

module Lxdb
  module Commands
    class Run < Base
      command "run", aliases: ["r"], description: "Start the program", category: :navigation

      def execute(args)
        require_target!
        session.launch(args: args)
        output(c("Process started", :success))
      end
    end

    class Continue < Base
      command "continue", aliases: %w[c cont], description: "Continue execution", category: :navigation

      def execute(_args)
        require_stopped!
        session.continue
      end
    end

    class Step < Base
      command "step", aliases: ["s"], description: "Step into (source level)", category: :navigation

      def execute(_args)
        require_stopped!
        session.step
      end
    end

    class StepInstruction < Base
      command "stepi", aliases: ["si"], description: "Step one instruction", category: :navigation

      def execute(_args)
        require_stopped!
        session.step_instruction
      end
    end

    class Next < Base
      command "next", aliases: ["n"], description: "Step over (source level)", category: :navigation

      def execute(_args)
        require_stopped!
        session.next_line
      end
    end

    class NextInstruction < Base
      command "nexti", aliases: ["ni"], description: "Step over one instruction", category: :navigation

      def execute(_args)
        require_stopped!
        session.next_instruction
      end
    end

    class Finish < Base
      command "finish", aliases: ["fin"], description: "Execute until current function returns", category: :navigation

      def execute(_args)
        require_stopped!
        session.finish
      end
    end

    class Kill < Base
      command "kill", aliases: ["k"], description: "Kill the running process", category: :navigation

      def execute(_args)
        require_process!
        session.process.kill
        output(c("Process killed", :warning))
      end
    end
  end
end
