require 'paint/pa'

def logd(msg, color=nil)
  if ENV.has_key? 'DEBUG'
    if ENV.fetch('DEBUG') == 'true'
      unless color
        puts msg
      else
        pa msg, color
      end
    end
  end
end
