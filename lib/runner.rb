module Runner
  class << self
    def run(spec)
      exec_cases(spec) unless $dry_run
      if spec.unmatched.length > 0
        output_unmatched_commands(spec)
      end
    end

    def run_commands_in_block_context(bullet)
      local_vars = {}
      bullet.associated_commands.each do |cmd|
        begin
          pa "  #{cmd}", COLORS[:support] if cmd != 'breakpoint' # agb ignore
          bind = binding
          local_vars.each_pair do |kk, vv|
            bind.local_variable_set(kk, vv)
          end
          unless cmd == 'breakpoint'
            result = bind.eval(cmd)
          else
            c = BreakpointContext.new(bind)
            c.contextual_breakpoint
          end
          dpa "result: #{result}"
          if cmd.include? '='
            new_var = cmd.split('=').first.rstrip
            unless new_var.include? '@' or new_var.include? '$'
              # don't store @ vars as a local var
              local_vars.store(new_var, result)
            end
          end
        rescue RSpec::Expectations::ExpectationNotMetError => e
          pa e, COLORS[:error], :bright
          raise e
        end
      end
    end

    def exec_cases(spec)
      puts; puts
      spec.cases.each do |test_case|
        title = "case: #{test_case.description}"
        pa "\u22EF" * ( title.length + 5 ), COLORS[:exec]
        pa "  case: #{test_case.description}", COLORS[:exec], :bright
        puts
        test_case.bullet_points.each do |bullet|
          pa "\u229A #{bullet}", COLORS[:exec]
          run_commands_in_block_context(bullet)
        end
      end
      puts; puts; puts
    end

    def output_unmatched_commands(spec)
      puts
      pa "Missing chizu entries:", COLORS[:missing], :bright
      puts
      spec.unmatched.each do |unm|
        pa "On '#{unm.summary}' do", COLORS[:missing]
        unm.bullet_points.each do |bp|
          pa "  # #{bp}", COLORS[:missing]
        end
        pa '  # TODO', COLORS[:missing]
        pa 'end', COLORS[:missing]
        puts
      end
    end
  end
end
