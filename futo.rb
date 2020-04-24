require 'byebug'; alias :breakpoint :byebug
require 'selenium-webdriver'

MAP_FILE = 'chizu/futo_map.rb'

class MapEntry
  attr_accessor :title, :commands
  def initialize(t, c_arr)
    @title = t
    @commands = c_arr
  end
end

class FutoSpec
  attr_accessor :description, :steps, :map

  #def initialize(desc, steps)
  def initialize(desc_file)
    #@description = desc
    #@steps = steps
    @steps = Array.new
    @map = Array.new
    load_steps(desc_file)
  end

  def load_steps(fn)
    File.open(fn) do |file|
      lines = file.readlines
      #desc = nil
      #steps = Array.new
      lines.each do |ll|
        if ll.start_with? 'describe'
          @desc = ll.split('describe ').last.chomp.lstrip
        elsif ll.lstrip.start_with? '-'
          @steps << ll.split('-').last.chomp.lstrip
        end
      end

      #new_spec = FutoSpec.new desc, steps
      #new_spec.run
    end
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

  def load_map
    File.open(MAP_FILE) do |file|
      lines = file.readlines
      title = String.new
      commands = Array.new
      lines.each do |ll|
        using_single_quotes = single_quoted_line?(line)
        if ll.start_with? 'On'
          if using_single_quotes
            title = ll.split("'")[1].chomp
          else
            title = ll.split('"')[1].chomp
          end
        elsif ll.start_with? 'end'
          @map << MapEntry.new(title, commands)
          title = String.new
          commands = Array.new
        elsif ll == "\n"
          next
        else
          commands << ll.lstrip.chomp
        end
      end
    end
  end

  def run
    load_map
    init_browser
    puts 'browser loaded, beginning test...'
    exec_steps
  end

  def match_step_with_command(st)
    @map.each do |entry|
      if entry.title == st
        entry.commands.each do |cmd|
          eval cmd
        end
      end
    end
  end

  def exec_steps
    @steps.each do |st|
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


fs = FutoSpec.new('basics.desc')
fs.run
