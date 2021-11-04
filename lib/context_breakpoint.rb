class BreakpointContext
  def initialize(bind)
    @local_vars = bind.local_variable_get(:local_vars)
    @bind = bind
  end
  def method_missing(symbol, *args)
    if @local_vars.include? symbol.to_s
      @local_vars[symbol.to_s]
    end
  end
  def contextual_breakpoint
    breakpoint
  end
end
