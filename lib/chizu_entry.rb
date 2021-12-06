class ChizuEntry
  ##
  # "Chizu" is Japanese for "map".
  # Chizus map bullet point text to specific ruby commands which will be executed.
  # Analagous to Cucumber's "step definition" layer.
  attr_accessor :kkey, :associated_commands
  def initialize(h, c_arr)
    @kkey = h
    @associated_commands = c_arr
  end
  def to_s; return @kkey; end
end
