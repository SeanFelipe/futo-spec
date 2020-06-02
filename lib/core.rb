require 'byebug'; alias :breakpoint :byebug #agbignore
require 'paint/pa'
require 'rspec/expectations'
require 'find'


BULLET_POINTS_REGEX = /[\->]*/

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
  include RSpec::Matchers
  attr_accessor :cases, :chizu, :unmatched

  def initialize(specified_file=nil)
    @cases = Array.new
    @chizu = Array.new
    @unmatched = Array.new

    test_case_lines = nil
    if specified_file == nil
      test_case_lines = discover_and_process_futo_files
    else
      test_case_lines = process_specific_file(specified_file)
    end

    breakpoint

    find_and_load_chizu_files
    load_bullet_points_into_test_case(test_case_lines)
    match_cases_to_chizu
  end

  def discover_and_process_futo_files
    futo_files = []
    test_case_lines = []

    Find.find('.') do |line|
      futo_files << line if line.end_with? '.futo'
    end

    futo_files.each { |ff| test_case_lines += process_specific_file(ff) }
    return test_case_lines
  end

  def process_specific_line_only(desc)
    spl = desc.split(':')
    desc_file = spl.first
    idx = spl.last.to_i - 1 # line numbers are 1-indexed

    File.open(desc_file) do |file|
      all_lines = file.readlines(chomp:true)
      specified_line = all_lines[idx]
      return specified_line
    end
  end

  def process_specific_file(spec)
    if spec.include? ':'
      return process_specific_line_only(spec)
    else
      File.open(spec) do |file|
        file_lines = file.readlines(chomp:true)
        return file_lines
      end
    end
  end

  def begin_new_case
    @new_case_label = ''
    @new_case_bullets = Array.new
  end

  def add_case_to_spec
    @cases << FutoCase.new(@new_case_label, @new_case_bullets)
  end

  def load_bullet_points_into_test_case(test_case_lines)
    begin_new_case

    test_case_lines.each do |ll|
      if ll == "\n"
        # ending a test case
        add_case_to_spec
        begin_new_case
      else
        no_ws = ll.lstrip
        if no_ws.start_with?('-') || no_ws.start_with?('>')
        # bullet for a new test case
          label = no_ws.gsub(BULLET_POINTS_REGEX, '')
          @new_case_bullets << FutoBullet.new(label.lstrip)
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

  def find_and_load_chizu_files
    chizu_files = []

    Find.find('./chizu/') do |line|
      chizu_files << line if line.end_with? 'chizu'
    end

    chizu_files.each {|ff| load_chizu ff}
  end

  def load_chizu(ff)
    File.open(ff) do |file|
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
    breakpoint
    @cases.each do |test_case|
      test_case.bullet_points.each do |bullet|
        matched = false
        if @chizu.length == 0
          @unmatched << bullet
        else
          @chizu.each do |chizu|
            if bullet.label == chizu.kkey
              matched = true
              bullet.associated_commands = chizu.associated_commands
            end
            if ! matched
              if ! @unmatched.include? bullet
                @unmatched << bullet
              end
            end
          end
        end
      end
    end
  end

  def output_unmatched_commands
    puts
    pa "\tMissing chizu entries:", :cyan
    puts
    @unmatched.each do |un|
      pa "On '#{un.label}' do", :yellow
      pa '  # TODO', :yellow
      pa 'end', :yellow
      puts
    end
  end

  def run
    exec_cases
    output_unmatched_commands
  end

  def exec_cases
    @cases.each do |test_case|
      test_case.bullet_points.each do |bullet|
        #puts
        #pa "case: #{bullet.label}", :gray
        bullet.associated_commands.each do |cmd|
          pa cmd, :green if cmd != 'breakpoint'
          begin
            eval cmd
          rescue RSpec::Expectations::ExpectationNotMetError => e
            pa e, :red
          end
        end
      end
    end
  end
end
