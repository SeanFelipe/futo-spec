require 'byebug'; alias :breakpoint :byebug #agbignore
require 'selenium-webdriver'
require 'paint/pa'
require 'rspec/expectations'
require 'capybara/rspec'
require_relative "#{ENV['FUTO_AUT']}/futo/pom/mousetrap_models/"

CHIZU_FILE = "#{ENV['FUTO_AUT']}/futo/chizu/mousetrap_map.rb"
#PLATFORM = :cli
#PLATFORM = :appium
PLATFORM = :selenium

def fx(loc)
  $driver.find_xpath(loc).first
end

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
  attr_accessor :cases, :chizu, :unmatched, :desc_file, :desc_lines

  #def initialize(desc, steps)
  def initialize(desc_file)
    @cases = Array.new
    @chizu = Array.new
    @unmatched = Array.new
    @desc_file = desc_file
    @desc_lines = nil
    load_test_cases
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

  def load_test_cases
    begin_new_case

    File.open(@desc_file) do |file|
      @desc_lines = file.readlines(chomp:true)

      @desc_lines.each do |ll|
        if ll == "\n"
          # ending a test case
          add_case_to_spec
          begin_new_case
        elsif ll.lstrip.start_with? '-'
          # bullet for a new test case
          label = ll.split('-').last.lstrip
          @new_case_bullets << FutoBullet.new(label)
        else
          # start a new test case and give it a label
          @new_case_label = ll.lstrip
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
      lines = file.readlines(chomp:true)
      kkey = ''
      commands = Array.new
      lines.each do |ll|
        using_single_quotes = single_quoted_line?(ll)
        if ll.start_with? 'On'
          if using_single_quotes
            kkey = ll.split("'")[1]
          else
            kkey = ll.split('"')[1]
          end
        elsif ll.start_with? 'end'
          @chizu << ChizuEntry.new(kkey, commands)
          kkey = ''
          commands = Array.new
        elsif ll == "\n"
          next
        else
          commands << ll.lstrip
        end
      end
    end
  end

  def match_cases_to_chizu
    @cases.each do |test_case|
      test_case.bullet_points.each do |bullet|
        @chizu.each do |chizu|
          if bullet.label == chizu.kkey
            bullet.associated_commands = chizu.associated_commands
          end
        end
      end
    end
  end

  def run
    if PLATFORM == :selenium
      init_browser
      puts
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
    @desc_lines.each do |desc_line|
      #pa "matching #{desc_line}... ", :gray

      @cases.each do |test_case|
        if test_case.description == desc_line
          pa "suite: #{test_case.description}", :green
        else
          test_case.bullet_points.each do |bullet|
            if bullet.label == desc_line.split('-').last.lstrip
              pa "case: #{bullet.label}", :green
              bullet.associated_commands.each do |cmd|
                pa cmd, :green if cmd != 'breakpoint'
                eval cmd
              end
            end
          end
        end
      end
    end
  end

  def init_capybara(drv=:selenium_chrome_headless)
    Capybara.configure do |config|
      config.run_server = false
      config.app_host = 'http://localhost:9293'
      config.default_driver = drv
    end
  end

  def init_selenium
    #$driver = Selenium::WebDriver.for :firefox
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    $driver = Selenium::WebDriver.for :chrome, options: options
  end

  def reload_models_file
    load "#{ENV['FUTO_AUT']}/futo/pom/mousetrap_models.rb"
  end
  alias :rr:reload_models_file
  alias :rreload :reload_models_file

  def load_page_models
    PageModels.constants.each do |cc|
      eval "$#{cc} = PageModels::#{cc}.new"
    end
  end

  def init_browser
    `killall 'Google Chrome'`
    #init_selenium
    init_capybara(:selenium_chrome)
    #init_capybara(:selenium_chrome_headless)
    $driver = Capybara.current_session.driver
    $window = $driver.browser.manage.window
    $window.resize_to 400, 1000
    load_page_models
  end
end

fs = FutoSpec.new(ARGV.first)
fs.run
