require 'byebug'; alias :breakpoint :byebug
require 'find'
require 'paint/pa'
require 'rspec/expectations'
require 'rspec'
require_relative './markdown_generator'


BULLET_POINTS_REGEX = /[\->]*/

COLORS = {
  init:     :gray,
  setup:    :gray,
  log:      :yellow,
  exec:     :yellow,
  support:  :cyan,
  warning:  :yellow,
  error:    :red,
}

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :should
  end
end

def logd(msg, *colors)
  if $debug
    unless colors
      puts msg
    else
      if colors.first == :bb
        pa msg, :yellow, :bright
      else
        pa msg, *colors
      end
    end
  end
end
alias :dpa :logd

class FutoBullet
  attr_accessor :label, :associated_commands
  def initialize(h)
    @label = h
    @associated_commands = Array.new
  end
  def to_s; return @label; end
end

class FutoCase
  ##
  # A test case, with a description and associated bullet points.
  # The description won't actually execute code.
  # The associated bullet points will be mapped to ruby commands via "Chizus".
  # Bullets will in sequence until a newline is encountered.
  attr_accessor :description, :bullet_points
  def initialize(h, b_arr)
    @description = h
    @bullet_points = b_arr
  end
  def to_s; return @description; end
end

class ChizuEntry
  ##
  # "Chizu" is Japanese for "map".
  # Chizus map bullet point text to specific ruby commands which will be executed.
  # Analagous to Cucumber's "step definition" layer.
  attr_accessor :kkey, :associated_commands
  def initialize(h, c_arr)
    @kkey = h
    @associated_commands = c_arr
  end
  def to_s; return @kkey; end
end

class FutoSpec
  ##
  # A collection of test cases, "FutoCase", and execution mappings, "Chizus".
  # Collect test definitions, then match them to chizus and run the associated commands.
  include RSpec::Matchers
  attr_accessor :cases, :chizu, :unmatched, :included_ins

  def check_and_set_debug
    if ENV.has_key? 'DEBUG'
      if ENV.fetch('DEBUG') == 'true'
        $debug = true
      end
    end
  end

  def initialize(opts={})
    @cases = Array.new
    @chizu_files = Array.new
    @chizu_array = Array.new
    @unmatched = Array.new
    @included_ins = Array.new

    check_and_set_debug

    if opts.include? :dry
      $dry_run = true if opts[:dry]
      pa 'dry run', COLORS[:init], :bright
    end

    if opts.include? :markdown
      $markdown = true if opts[:markdown]
      pa 'markdown mode', COLORS[:init], :bright
    end

    if opts.include? :headless
      $headless = true if opts[:headless]
    end

    @specified_file = opts.fetch(:specified_file)

    if $markdown
      unless @specified_file
        raise ArgumentError, "please specify a file when using --markdown option."
      else
        test_case_lines = process_specific_file(@specified_file)
        generate_markdown_and_print(test_case_lines)
        pa 'finished markdown.', COLORS[:init]
      end
    else
      look_for_envrb_and_parse

      test_case_lines = process_specific_file(@specified_file)
      create_test_cases(test_case_lines)
      dpa "test cases loaded: #{@cases.length}", :bb

      load_matching_chizu_plus_shared_directory
    end
  end

  def look_for_envrb_and_parse
    if Dir.children(Dir.pwd).include? 'futo'
      if Dir.children("#{Dir.pwd}/futo").include? '_glue'
        if Dir.children("#{Dir.pwd}/futo/_glue").include? 'env.rb'
          dpa 'found futo/_glue/env.rb', COLORS[:init]
          load 'futo/_glue/env.rb'
        end
      end
    end
  end

  def discover_and_process_spec_files
    dpa "no file specified, discovering all .futo or .spec files ...", COLORS[:init], :bright
    futo_files = []
    test_case_lines = []

    Find.find("#{Dir.pwd}/futo") do |ff|
      if ff.end_with? '.futo' or ff.end_with? 'spec'
        fn = ff.split('/').last
        futo_files << fn
      end
    end

    futo_files.each { |fn| test_case_lines += process_specific_file(fn) }
    return test_case_lines
  end

  def process_specific_file(fn)
    dpa "process_specific_file: #{fn}", COLORS[:init], :bright
    path = "futo/#{fn}"
    File.open(path) do |file|
      file_lines = file.readlines(chomp:true)
      return file_lines
    end
  end

  def process_specific_line(desc)
    spl = desc.split(':')
    desc_file = spl.first
    # allow for specifying line w/o .futo, eg `futo current:19 for current.futo:19`
    desc_file = "#{desc_file}.futo" if not desc_file.include? '.'
    line_specified = spl.last
    idx = line_specified.to_i - 1 # line numbers are 1-indexed

    puts "found specific file request: #{desc_file} at line #{line_specified} (index #{idx})"

    File.open("./futo/#{desc_file}") do |file|
      all_lines = file.readlines(chomp:true)
      specified_line = all_lines[idx]
      if is_description? specified_line
        return add_additional_lines_context_to_specified_line(all_lines, idx)
      else
        specified_line_as_arr = [ specified_line ]
        return specified_line_as_arr
      end
    end
  end

  def add_additional_lines_context_to_specified_line(all_lines, idx)
    starting_slice = all_lines.slice(idx, all_lines.length)
    final_idx = nil
    starting_slice.each_with_index do |ll, ii|
      if is_newline? ll
        final_idx = ii
        break
      end
      if final_idx == nil
        # no newline found through the rest of the futo
        final_idx = starting_slice.length
      end
    end
    final_slice = starting_slice.slice(0, final_idx)
    return final_slice
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

  def is_description?(line)
    return false if is_bullet? line
    return false if is_newline? line
    return false if is_mock_data? line
    return false if is_asterisk? line
    return true
  end

  def is_asterisk?(line)
    return line.start_with?('*')
  end

  def is_bullet?(line)
    return line.start_with?('-') || line.start_with?('>')
  end

  def is_newline?(line)
    return line == ''
  end

  def is_mock_data?(line)
    return line.start_with?('** mock data:')
  end

  def load_mock_data(ll)
    # ll is the full line including '** mock data:'
    fn = ll.split(' ').last.gsub("'",'').gsub('"','')
    # now we have the filename minus futo/
    path = "futo/#{fn}"
    md = File.readlines(path, chomp:true)
    @mock_data = md
  end

  def init_test(line)
    prefix = line.split(':').last.lstrip
    fn = "./initialize/#{prefix}.initialize.rb"
    if File.exist?(fn)
      load(fn)
    else
      pa "failed to find setup file #{fn} for line: #{line}", COLORS[:red]
    end
    puts
  end

  def create_test_cases(test_case_lines)
    begin_new_case

    test_case_lines.each do |line|
      l0 = line.gsub('(DONE)','').gsub('(done)','')
      ll = l0.lstrip.rstrip
      if is_newline? ll
        dpa "found newline: #{ll}", COLORS[:setup]
        add_case_to_spec
        begin_new_case
      else
        if is_mock_data? ll
          dpa "found mock data: #{ll}", COLORS[:setup]
          load_mock_data(ll)
        elsif is_bullet? ll
          dpa "found bullet: #{ll}", COLORS[:setup]
          new_bullet(ll)
        elsif is_asterisk? ll
          dpa "found asterisk, treating as description: #{ll}", COLORS[:setup]
          label = ll.gsub('*', '').lstrip
          new_label(label)
        elsif is_description? ll
          dpa "found new description: #{ll}", COLORS[:setup]
          new_label(ll)
        else
          raise RuntimeError, "could not find entry type for string #{ll}"
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

  def find_chizu_with_matching_fn
  end

  def load_matching_chizu_plus_shared_directory
    base = "#{Dir.pwd}/futo/chizus"
    path = "#{base}/#{@specified_file}.chizu"
    chizu_files = []
    unless File.exist? path
      raise RuntimeError, "couldn't find matching chizu for #{@specified_file}"
    else
      dpa "loading matching #{@specified_file}.chizu ...", COLORS[:setup], :bright
      chizu_files << path
    end
    search_dir = "#{base}/shared"
    dpa "loading shared chizus ...", COLORS[:setup], :bright
    Find.find(search_dir) do |ff|
      dpa "loading #{ff}", :cyan
      chizu_files << ff if ff.end_with? '.chizu'
    end

    chizu_files.each {|ff| load_chizu_commands ff}
  end


  def add_new_chizu(kkey, commands)
    @chizu_array << ChizuEntry.new(kkey, commands)
  end

  def load_chizu_commands(ff)
    File.open(ff) do |file|
      lines = file.readlines(chomp:true)
      kkey = ''
      associated_commands = Array.new

      processing_stanza = false
      inside_begin_end_block = false
      begin_end_block_string = ''

      lines.each do |ll|
        if processing_stanza
          if inside_begin_end_block
            puts "processing begin-end command: #{ll}"
            if ll.lstrip.start_with? 'end'
              begin_end_block_string += " #{ll.lstrip};"
              associated_commands << begin_end_block_string
              begin_end_block_string = ''
              inside_begin_end_block = false
            else
              begin_end_block_string += " #{ll.lstrip};"
            end
          else
            if ll.strip.start_with? 'begin'
              inside_begin_end_block= true
              begin_end_block_string += "#{ll.lstrip};"
            elsif ll.start_with? 'end'
              processing_stanza = false
              add_new_chizu(kkey, associated_commands)
              kkey = ''
              associated_commands = Array.new
            else
              associated_commands << ll.lstrip
            end
          end
        else
          #puts "processing description line: #{ll}"
          if ll.start_with? 'On'
            processing_stanza = true
            using_single_quotes = single_quoted_line?(ll)
            if using_single_quotes
              kkey = ll.split("'")[1]
            else
              kkey = ll.split('"')[1]
            end
          elsif ll == "\n" || ll == ''
            next
          else
            pa "encountered unexpected line: #{ll}", :red, :bright
          end
        end
      end
    end
  end

  def is_todo?(chizu)
    return chizu.associated_commands.include?('TODO')
  end

  def is_included_in?(chizu)
    return chizu.associated_commands.first.include? 'included_in'
  end

  def set_all_unmatched
    @cases.each do |cc|
      cc.bullet_points.each {|bullet| @unmatched << bullet.label }
    end
  end

  def match_chizus_to_test_cases
    if @chizu_array.length == 0
      set_all_unmatched
    else
      @cases.each_with_index do |test_case, tc_index|
        test_case.bullet_points.each do |bullet|
          dpa "matching bullet: #{bullet}", :bb
          matched = false
          @chizu_array.each do |chizu|
            if process_bullet_chizu_match(bullet, chizu)
              bullet.associated_commands = chizu.associated_commands
              matched = true
              break
            end
          end
          dpa "matched? #{bullet.label} : #{matched}", :bb
          if ! matched
            unless @unmatched.include? bullet.label
              dpa "couldn't find a match for #{bullet.label}", COLORS[:error]
              @unmatched << bullet.label
            end
          end
        end
      end
    end
  end

  def process_bullet_chizu_match(bullet, chizu)
    matched = false
    dpa "chizu: #{chizu.kkey}", COLORS[:init]
    if is_todo? chizu
      logd "found todo: #{chizu}", COLORS[:init]
      # todos aren't considered completed so they are unmatched
    elsif is_included_in? chizu
      #logd "found included_in: #{chizu}", COLORS[:init]
      @included_ins << chizu
    else
      if bullet.label == chizu.kkey
        logd "matched: #{bullet.label} #{chizu.kkey}", COLORS[:init]
        matched = true
      end
    end
    return matched
  end

  def output_unmatched_commands
    puts
    pa "Missing chizu entries:", COLORS[:warning], :bright
    puts
    @unmatched.each do |label|
      pa "On '#{label}' do", COLORS[:warning]
      pa '  # TODO', COLORS[:warning]
      pa 'end', COLORS[:warning]
      puts
    end
  end

  def run
    exec_cases unless $dry_run
    output_unmatched_commands if @unmatched.length > 0
  end

  def run_commands_in_block_context(bullet)
    bullet.associated_commands.each do |cmd|
      pa cmd, COLORS[:support] if cmd != 'breakpoint'
      begin
        binding = eval(cmd, binding)
      rescue RSpec::Expectations::ExpectationNotMetError => e
        pa e, COLORS[:error], :bright
      end
    end
  end

  def exec_cases
    puts
    @cases.each do |test_case|
      pa "case: #{test_case.description}", COLORS[:exec], :bright
      test_case.bullet_points.each do |bullet|
        pa bullet, COLORS[:exec]
        run_commands_in_block_context(bullet)
      end
    end
  end
end
