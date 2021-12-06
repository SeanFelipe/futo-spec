class FutoBulletPoint
  attr_accessor :label, :associated_commands
  def initialize(h)
    @label = h
    @associated_commands = Array.new
  end
  def to_s; return @label; end
end


