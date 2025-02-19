class FutoTestCase
  ##
  # A test case, with a description and associated bullet points.
  # The description won't actually execute code.
  # The associated bullet points will be mapped to ruby commands via "Chizus".
  # BulletPoints will in sequence until a newline is encountered.
  attr_accessor :label
  attr_accessor :associated_commands
  attr_accessor :associated_commands_test_case_level
  attr_accessor :description
  attr_accessor :bullet_points
  def initialize(h, b_arr)
    @description = h
    @bullet_points = b_arr
    @associated_commands = []
    @associated_commands_test_case_level = []
  end
  def to_s; return @description; end
end
