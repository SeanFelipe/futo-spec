require 'paint/pa'
require 'rspec/expectations'
require 'find'
require 'rspec'
require 'byebug'; alias :breakpoint :byebug
require_relative 'logger'


BULLET_POINTS_REGEX = /[\->]*/

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :should
  end
end

def logd(msg, color=nil)
  if ENV.has_key? 'DEBUG'
    if ENV.fetch('DEBUG') == 'true'
      unless color
        puts msg
      else
        pa msg, color
      end
    end
  end
end

class FutoBullet
  attr_accessor :label, :associated_commands
  def initialize(h)
    @label = h
    @associated_commands = Array.new
  end
  def to_s; return @label; end
end

class FutoCase
  attr_accessor :description, :bullet_points
  def initialize(h, b_arr)
    @description = h
    @bullet_points = b_arr
  end
  def to_s; return @description; end
end

class ChizuEntry
  attr_accessor :kkey, :associated_commands
  def initialize(h, c_arr)
    @kkey = h
    @associated_commands = c_arr
  end
  def to_s; return @kkey; end
end

class FutoSpec
  include RSpec::Matchers
  attr_accessor :cases, :chizu, :unmatched

  def initialize(specified_file=false)
    @cases = Array.new
    @chizu = Array.new
    @unmatched = Array.new

    look_for_envrb_and_parse

    find_and_load_chizu_files

    test_case_lines = nil
    unless specified_file
      test_case_lines = discover_and_process_spec_files
    else
      test_case_lines = process_specific_file(specified_file)
    end
    create_test_cases(test_case_lines)

    match_chizus_to_test_cases
  end

  def look_for_envrb_and_parse
    if Dir.children(Dir.pwd).include? 'spec'
      if Dir.children("#{Dir.pwd}/spec'").include? '_glue'
        if Dir.children("#{Dir.pwd}/futo-spec/_glue").include? 'env.rb'
          puts 'found futo-spec/_glue/env.rb'
          load 'futo-spec/_glue/env.rb'
        end
      end
    end
  end

  def discover_and_process_spec_files
    futo_files = []
    test_case_lines = []

    Find.find('./futo-spec/') do |ff|
      if ff.end_with? '.futo' or ff.end_with? 'spec'
        futo_files << ff
      end
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
    #puts label
    @new_case_bullets << FutoBullet.new(label)
  end

  def new_label(line)
    @new_case_label = line
  end

  def is_newline?(line)
    return line == ''
  end

  def is_mock_data?(line)
    return line.start_with?('** mock data:')
  end

  def load_mock_data(ll)
    fn = ll.split(' ').last.gsub("'",'').gsub('"','')
    md = File.readlines(fn, chomp:true)
    @mock_data = md
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

  def create_test_cases(test_case_lines)
    begin_new_case

    test_case_lines.each do |line|
      l0 = line.gsub('(DONE)','').gsub('(done)','')
      ll = l0.lstrip.rstrip
      if is_newline? ll
        pa "found newline: #{ll}", :yellow
        add_case_to_spec
        begin_new_case
      else
        if is_mock_data? ll
          pa "found mock data: #{ll}", :yellow
          load_mock_data(ll)
        elsif is_bullet? ll
          pa "found bullet: #{ll}", :yellow
          new_bullet(ll)
        else
          pa "found new description: #{ll}", :yellow
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
    search_dir = 'futo-spec/_glue/chizu'
    if Dir.children(Dir.pwd).include? 'spec'
      search_dir = 'spec/' + search_dir
    end
    Find.find(search_dir) do |ff|
      chizu_files << ff if ff.end_with? '.chizu'
      chizu_files << ff if ff.end_with? '.rb'
    end

    chizu_files.each {|ff| load_chizu_commands ff}
    pa "chizu load complete: #{@chizu}", :gray
  end

  def add_new_chizu(kkey, commands)
    @chizu << ChizuEntry.new(kkey, commands)
  end

  def load_chizu_commands(ff)
    File.open(ff) do |file|
      lines = file.readlines(chomp:true)
      kkey = ''
      associated_commands = Array.new

      processing_block = false
      inside_begin_end = false
      begin_end_block_string = ''

      lines.each do |ll|
        if processing_block
          if inside_begin_end
            puts "processing begin-end command: #{ll}"
            if ll.lstrip.start_with? 'end'
              begin_end_block_string += " #{ll.lstrip};"
              associated_commands << begin_end_block_string
              begin_end_block_string = ''
              inside_begin_end = false
            else
              begin_end_block_string += " #{ll.lstrip};"
            end
          else
            if ll.strip.start_with? 'begin'
              inside_begin_end = true
              begin_end_block_string += "#{ll.lstrip};"
            elsif ll.start_with? 'end'
              processing_block = false
              add_new_chizu(kkey, associated_commands)
              kkey = ''
              associated_commands = Array.new
            else
              associated_commands << ll.lstrip
            end
          end
        else
          puts "processing description line: #{ll}"
          if ll.start_with? 'On'
            processing_block = true
            using_single_quotes = single_quoted_line?(ll)
            if using_single_quotes
              kkey = ll.split("'")[1]
            else
              kkey = ll.split('"')[1]
            end
          elsif ll == "\n" || ll == ''
            next
          else
            breakpoint
            puts
          end
        end
      end
    end
  end

  def is_todo?(chizu)
    if chizu.associated_commands.include?('TODO')
      return true
    else
      return false
    end
  end

  #def load_commands_into_test_cases_from_chizu
  def match_chizus_to_test_cases
    @cases.each do |test_case|
      test_case.bullet_points.each do |bullet|
        matched = false
        if @chizu.length == 0
          # no chizus found, everything will be unmatched
          @unmatched << bullet
        else
          @chizu.each do |chizu|
            logd "processing chizu: #{chizu}", :yellow
            if is_todo? chizu
              logd "found todo: #{chizu}", :red
              next
            else
=begin
              if bullet.label.start_with? 'lines without bullets'
                breakpoint
              end
=end
              logd "matching bullet with chizu:"
              logd bullet.label, :blue
              logd chizu.kkey, :yellow
              if bullet.label == chizu.kkey
                matched = true
                bullet.associated_commands = chizu.associated_commands
                next
              end
            end
          end
          if ! matched
            pa "couldn't match: #{bullet.label}", :blue
            unless @unmatched.include? bullet
              @unmatched << bullet
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

  def run(dry_run=false)
    exec_cases unless dry_run
    output_unmatched_commands
  end

  def exec_cases
    puts
    @cases.each do |test_case|
      test_case.bullet_points.each do |bullet|
        #puts
        pa "case: #{bullet.label}", :gray
        bullet.associated_commands.each do |cmd|
          pa cmd, :cyan if cmd != 'breakpoint'
          begin
            binding = eval(cmd, binding)
          rescue RSpec::Expectations::ExpectationNotMetError => e
            pa e, :red
          end
        end
      end
    end
  end
end
