require 'byebug'; alias :breakpoint :byebug
require 'selenium-webdriver'
require 'paint/pa'

CHIZU_FILE = './chizu/futo_map.rb'
PLATFORM = :cli
#PLATFORM = :appium
#PLATFORM = :selenium

class FutoBullet
  attr_accessor :label, :associated_commands
  def initialize(h)
    @label = h
    @associated_commands = Array.new
  end
end

class FutoCase
  attr_accessor :description, :bullet_points
  def initialize(h, b_arr)
    @description = h
    @bullet_points = b_arr
  end
end

class ChizuEntry
  attr_accessor :kkey, :associated_commands
  def initialize(h, c_arr)
    @kkey = h
    @associated_commands = c_arr
  end
end

class FutoSpec
  attr_accessor :cases, :chizu, :unmatched

  #def initialize(desc, steps)
  def initialize(desc_file)
    @cases = Array.new
    @chizu = Array.new
    @unmatched = Array.new
    load_test_cases(desc_file)
    load_chizu
    match_cases_to_chizu
  end

  def begin_new_case
    @new_case_label = ''
    @new_case_bullets = Array.new
  end

  def add_case_to_spec
    @cases << FutoCase.new(@new_case_label, @new_case_bullets)
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
          label = ll.split('-').last.chomp.lstrip
          @new_case_bullets << FutoBullet.new(label)
        else
          @new_case_label = ll.chomp.lstrip
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
      kkey = ''
      commands = Array.new
      lines.each do |ll|
        using_single_quotes = single_quoted_line?(ll)
        if ll.start_with? 'On'
          if using_single_quotes
            kkey = ll.split("'")[1].chomp
          else
            kkey = ll.split('"')[1].chomp
          end
        elsif ll.start_with? 'end'
          @chizu << ChizuEntry.new(kkey, commands)
          kkey = ''
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
      test_case.bullet_points.each do |bullet|
        @chizu.each do |chizu|
          if bullet == chizu.kkey
            test_case.associated_commands = chizu.associated_commands
          end
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
    if @unmatched.length > 0
      output_unmatched_commands
    end
  end

  def output_unmatched_commands
    puts; puts
    pa "Missing chizu entries:", :cyan
    puts
    @unmatched.each do |un|
      pa "On '#{un.label}' do", :yellow
      pa '  # TODO', :yellow
      pa 'end', :yellow
      puts
    end
    puts
  end

  def exec_cases
    @cases.each do |test_case|
      test_case.bullet_points.each do |bullet|
        unless bullet.associated_commands.length == 0
          bullet.associated_commands.each do |cmd|
            eval cmd
          end
        else
          @unmatched << bullet
        end
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

fs = FutoSpec.new(ARGV.first)
fs.run
