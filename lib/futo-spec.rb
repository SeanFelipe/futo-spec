require 'paint/pa'
require 'rspec/expectations'
require 'find'


BULLET_POINTS_REGEX = /[\->]*/


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

    look_for_envrb_and_parse
    find_and_load_chizu_files
    create_test_cases_and_load_bullet_points(test_case_lines)
    load_commands_into_test_cases_from_chizu
  end

  def look_for_envrb_and_parse
    if Dir.children(Dir.pwd).include? '_glue'
      if Dir.children("#{Dir.pwd}/_glue").include? 'env.rb'
        puts 'found _glue/env.rb'
        load '_glue/env.rb'
      end
    end
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

  def specific_line_requested(desc)
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
      return specific_line_requested(spec)
    else
      File.open(spec) do |file|
        file_lines = file.readlines(chomp:true)
        return file_lines
      end
    end
  end

  def add_case_to_spec
    @cases << FutoCase.new(@new_case_label, @new_case_bullets)
  end

  def begin_new_case
    @new_case_label = ''
    @new_case_bullets = Array.new
  end

  def new_bullet(line)
    label = line.sub(BULLET_POINTS_REGEX, '').lstrip
    puts label
    @new_case_bullets << FutoBullet.new(label)
  end

  def new_label(line)
    @new_case_label = line
  end

  def is_newline?(line)
    return line == ''
  end

  def is_initialize?(line)
    return line.start_with?('** initialize with:') ||
      line.start_with?('**')
  end

  def init_test(line)
    prefix = line.split(':').last.lstrip
    fn = "./initialize/#{prefix}.initialize.rb"
    if File.exist?(fn)
      load(fn)
    else
      pa "failed to find setup file #{fn} for line: #{line}", :red
    end
    puts
  end

  def is_bullet?(line)
    return line.start_with?('-') || line.start_with?('>')
  end

  def create_test_cases_and_load_bullet_points(test_case_lines)
    begin_new_case

    test_case_lines.each do |line|
      l0 = line.gsub('(DONE)','').gsub('(done)','')
      ll = l0.lstrip.rstrip
      if is_newline? ll
        add_case_to_spec
        begin_new_case
      else
        if is_initialize? ll
          init_test(ll)
        elsif is_bullet? ll
          new_bullet(ll)
        else
          new_label(ll)
        end
      end
    end

    # catch anything left over
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

    Find.find('./_glue/chizu/') do |line|
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
        elsif ll == "\n" || ll == ''
          next
        else
          commands << ll.lstrip
        end
      end
    end
  end

  def is_todo?(chizu)
    if chizu.associated_commands.include?('# TODO') ||
        chizu.associated_commands.include?('#TODO') ||
        chizu.associated_commands.include?('TODO')
      return true
    else
      return false
    end
  end

  def load_commands_into_test_cases_from_chizu
    @cases.each do |test_case|
      test_case.bullet_points.each do |bullet|
        matched = false
        if @chizu.length == 0
          # no chizus found, everything will be unmatched
          @unmatched << bullet
        else
          @chizu.each do |chizu|
            if is_todo? chizu
              next
            else
              if bullet.label == chizu.kkey
                matched = true
                bullet.associated_commands = chizu.associated_commands
              end
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
    pa "Missing chizu entries:", :yellow
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
    puts
    @cases.each do |test_case|
      test_case.bullet_points.each do |bullet|
        #puts
        #pa "case: #{bullet.label}", :gray
        bullet.associated_commands.each do |cmd|
          pa cmd, :yellow if cmd != 'breakpoint'
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
