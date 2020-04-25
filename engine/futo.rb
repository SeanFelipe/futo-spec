require 'byebug'; alias :breakpoint :byebug
require 'selenium-webdriver'
require 'paint/pa'

CHIZU_FILE = 'chizu/futo_map.rb'
PLATFORM = :cli
#PLATFORM = :appium
#PLATFORM = :selenium

class FutoBullet
  attr_accessor :heading, :commands
  def initialize(h, cmds)
    @heading = h
    @commands = cmds
  end
end

class FutoCase
  attr_accessor :heading, :bullets, :commands
  def initialize(h, b_arr)
    @heading = h
    @bullets = b_arr
    @commands = Array.new
  end
end

class ChizuEntry
  attr_accessor :heading, :commands
  def initialize(h, c_arr)
    @heading = h
    @commands = c_arr
  end
end

class FutoSpec
  attr_accessor :cases, :chizu

  #def initialize(desc, steps)
  def initialize(desc_file)
    @cases = Array.new
    @chizu = Array.new
    load_test_cases(desc_file)
    load_chizu
    match_cases_to_chizu
  end

  def begin_new_case
    @new_case_heading = ''
    @new_case_bullets = Array.new
  end

  def add_case_to_spec
    @cases << FutoCase.new(@new_case_heading, @new_case_bullets)
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
          @new_case_bullets << ll.split('-').last.chomp.lstrip
        else
          @new_case_heading = ll.chomp.lstrip
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
      heading = ''
      commands = Array.new
      lines.each do |ll|
        using_single_quotes = single_quoted_line?(ll)
        if ll.start_with? 'On'
          if using_single_quotes
            heading = ll.split("'")[1].chomp
          else
            heading = ll.split('"')[1].chomp
          end
        elsif ll.start_with? 'end'
          @chizu << ChizuEntry.new(heading, commands)
          heading = ''
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
    @cases.each do |test_case|
      @chizu.each do |chizu_entry|
        if test_case.heading == chizu_entry.heading
          test_case.commands = chizu_entry.commands
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

  def missing_commands(test_case)
    puts
    pa "Missing chizu for test case:", :green
    puts
    pa  test_case.heading, :cyan
    test_case.bullets.each do |bul|
      pa "- #{bul}", :cyan
    end
    puts; puts
    pa "Sample chizu entries:", :green
    puts
    test_case.bullets.each do |bul|
      pa "On '#{bul}' do", :yellow
      pa '  # TODO', :yellow
      pa 'end', :yellow
      puts
    end
    puts
  end

  def exec_cases
    @cases.each do |test_case|
      unless test_case.commands.length == 0
        test_case.commands.each do |cmd|
          eval cmd
        end
      else
        missing_commands(test_case)
      end
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
