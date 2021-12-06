def logd(msg, *colors)
  if $debug
    unless colors.length > 0
      pa msg, COLORS[:debug]
    else
      if colors.first == :bb
        pa msg, COLORS[:debug], :bright
      else
        pa msg, *colors
      end
    end
  end
end
alias :dpa :logd

def pout(msg)
  pa msg, COLORS[:out]
end
