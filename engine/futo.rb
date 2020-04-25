require 'byebug'; alias :breakpoint :byebug
require 'selenium-webdriver'

CHIZU_FILE = 'chizu/futo_map.rb'
PLATFORM = :cli
#PLATFORM = :appium
#PLATFORM = :selenium

class FutoBullet
  attr_accessor :title, :commands
  def initialize(t, cmds)
    @title = t
    @commands = cmds
  end
end

class FutoCase
  attr_accessor :description, :bullet_points
  def initialize(t, b_arr)
    @description = t
    @bullets = b_arr
    @commands = Array.new
  end
end

class ChizuEntry
  attr_accessor :title, :commands
  def initialize(t, c_arr)
    @title = t
    @commands = c_arr
  end
end

class FutoSpec
  attr_accessor :cases, :chizu

  #def initialize(desc, steps)
  def initialize(desc_file)
    #@description = desc
    #@steps = steps
    @cases = Array.new
    @chizu = Array.new
    load_test_cases(desc_file)
    load_chizu
    match_cases_to_chizu
  end

  def begin_new_case
    @new_case_description = ''
    @new_case_bullets = Array.new
  end

  def add_case_to_spec
    @cases << FutoCase.new(@new_case_description, @new_case_bullets)
  end

  def load_test_cases(fn)
    begin_new_case

    File.open(fn) do |file|
      lines = file.readlines

      lines.each do |ll|
        if ll == "\n"
          add_case_to_spec
          begin_new_case
        elsif ll.lstrip.start_with? '-'
          # bullet point for case in progress
          @new_case_bullets << ll.split('-').last.chomp.lstrip
        else
          # new case, description
          @new_case_description = ll.chomp.lstrip
        end
      end
    end

    add_case_to_spec
  end

  def single_quoted_line?(line)
    single = false
    line.chars.each do |char|
      if char == '"'
        break
      end
      if char == "'"
        single = true
        break
      end
    end
    return single
  end

  def load_chizu
    File.open(CHIZU_FILE) do |file|
      lines = file.readlines
      title = ''
      commands = Array.new
      lines.each do |ll|
        using_single_quotes = single_quoted_line?(ll)
        if ll.start_with? 'On'
          if using_single_quotes
            title = ll.split("'")[1].chomp
          else
            title = ll.split('"')[1].chomp
          end
        elsif ll.start_with? 'end'
          @chizu << ChizuEntry.new(title, commands)
          title = ''
          commands = Array.new
        elsif ll == "\n"
          next
        else
          commands << ll.lstrip.chomp
        end
      end
    end
  end

  def match_cases_to_chizu
    breakpoint
    @cases.each do |test_case|
      @chizu.each do |chizu_entry|
        if test_case.title == chizu_entry.title
          test_case.commands = chizu_entry.commands
        end
      end
    end
  end

  def match_step_with_command(st)
    @chizu.each do |entry|
      if entry.title == st
        entry.commands.each do |cmd|
          eval cmd
        end
      end
    end
  end

  def run
    if PLATFORM == :selenium
      init_browser
      puts 'browser loaded, beginning test...'
    end
    exec_cases
  end

  def exec_cases
    @cases.each do |test_case|
      test_case.steps.each |st|
      match_step_with_command(st)
    end
  end

  def init_browser
    #$driver = Selenium::WebDriver.for :firefox
    $driver = Selenium::WebDriver.for :chrome
    $driver.navigate.to 'http://localhost:3000'
  require 'byebug'; alias :breakpoint :byebug
  end
end

fs = FutoSpec.new('basics.futo')
fs.run
