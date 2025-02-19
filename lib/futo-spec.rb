require 'set'
require 'find'
require 'byebug'; alias :breakpoint :byebug
require 'paint/pa'
require 'rspec/expectations'
require 'rspec'
require_relative 'bullet_point'
require_relative 'chizu_entry'
require_relative 'context_breakpoint'
require_relative 'futo-spec'
require_relative 'mock_tools'
require_relative 'runner'
require_relative 'test_case'
require_relative 'utils'


BULLET_POINTS_REGEX = /[\->]*/

COLORS = {
  init:     :gray,
  setup:    :gray,
  debug:    :gray,
  log:      :yellow,
  exec:     :yellow,
  support:  'cornflower blue',
  out:      'dark khaki',
  warning:  'coral',
  missing:  :yellow,
  error:    :red,
}

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :should
  end
end

class UnmatchedChizuData
  attr_reader :summary, :bullet_points
  def initialize(sum)
    @summary = sum
    @bullet_points = []
  end
  def add_bullet_point(bp)
    @bullet_points << bp
  end
end

class FutoSpec
  ##
  # A collection of test cases, "FutoTestCase", and execution mappings, "Chizus".
  # Collect test definitions, then match them to chizus and run the associated commands.
  include RSpec::Matchers
  attr_reader :cases, :chizu, :unmatched, :included_ins

  def initialize(opts={})
=begin
    # future enhancement ?
    # https://github.com/janlelis/whirly
    # couldn't get it dialed in with variable scoping + good timing
    Whirly.configure spinner: "dots"
    Whirly.configure append_newline: false
    Whirly.configure color: false
=end
    @cases = Array.new
    @chizu_files = Array.new
    @chizus = Array.new
    @unmatched = Set.new
    @included_ins = Array.new

    if $debug
      dpa '-- debug mode --'
      puts
    end

    if opts.include? :dry_run
      $dry_run = true
      pa 'dry run', COLORS[:init], :bright
    end

    if opts.include? :specified_file
      dpa "specified file: #{$specified_file}"
    end

    if opts.include? :headless
      $headless = true
      dpa 'headless mode'
    end

    if opts.include? :markdown
      markdown_only
    else
      look_for_envrb_and_parse
      test_case_lines = process_specified_file
      create_test_cases(test_case_lines)
      find_matching_chizu_files
      process_chizu_files
      if @chizus.length == 0
        set_all_test_cases_unmatched
      else
        match_cases_to_chizus_descriptions_only
        #fire_cases
      end
    end
  end

  def markdown_only
    pa 'markdown mode', COLORS[:init], :bright
    unless $specified_file
      raise ArgumentError, "please specify a file when using --markdown option."
    else
      test_case_lines = process_specified_file
      generate_markdown_and_print(test_case_lines)
      pa 'finished markdown.', COLORS[:init]
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

  def process_specified_file
    dpa "process_specified_file: #{$specified_file}"
    path = "futo/#{$specified_file}"
    File.open(path) do |file|
      file_lines = file.readlines(chomp:true)
      # add one blank line to facilitate saving the last test case
      file_lines << ''
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
    # don't add the last test case
    unless @new_case_label == ''
      dpa "adding new test case: #{@new_case_label}"
      @cases << FutoTestCase.new(@new_case_label, @new_case_bullets)
    end
  end

  def begin_new_case
    @new_case_label = ''
    @new_case_bullets = Array.new
  end

  def new_bullet(line)
    label = line.sub(BULLET_POINTS_REGEX, '').lstrip
    #puts label
    @new_case_bullets << FutoBulletPoint.new(label)
  end

  def new_label(line)
    @new_case_label = line
  end

  def is_description?(line)
    return false if is_bullet? line
    return false if is_newline? line
    return false if is_asterisk? line
    return false if MockTools.is_mock_data? line
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

  def create_test_cases(test_case_lines)
    begin_new_case

    test_case_lines.each do |line|
      l0 = line.gsub('(DONE)','').gsub('(done)','')
      ll = l0.lstrip.rstrip
      if is_newline? ll
        dpa "found newline: #{ll}, saving existing case and starting a new one"
        add_case_to_spec
        begin_new_case
      else
        if MockTools.is_mock_data? ll
          dpa "found mock data: #{ll}", COLORS[:setup]
          MockTools.load_mock_data(ll)
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
          raise RuntimeError, "could not find matching chizu entry type for: #{ll}"
        end
      end
      dpa "test cases loaded: #{@cases.length}"
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

  def find_matching_chizu_files
    without_suffix = $specified_file.chomp('.futo')
    base = "#{Dir.pwd}/futo/chizus"
    path = "#{base}/#{without_suffix}.chizu"
    unless File.exist? path
      pa "#{$specified_file}: couldn't find matching .chizu file", COLORS[:warning]
    else
      dpa "loading matching #{$specified_file}.chizu ...", COLORS[:setup]
      @chizu_files << path
    end

    search_dir = "#{base}/shared"
    dpa "loading shared chizus ...", COLORS[:setup]
    Find.find(search_dir) do |ff|
      if ff.end_with? 'chizu'
        dpa "loading #{ff}"
        @chizu_files << ff
      end
    end
  end

  def process_chizu_files
    @chizu_files.each do |ff|
      #puts "processing chizu #{ff}"
      load_ruby_commands_from_chizu_file ff
    end
  end

  def add_new_chizu(kkey, commands)
    @chizus << ChizuEntry.new(kkey, commands)
  end

  def load_ruby_commands_from_chizu_file(ff)
    dpa "loading ruby commands from file: #{ff}"
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

  def gen_unmatched(test_case)
    unm = UnmatchedChizuData.new(test_case.description)
    test_case.bullet_points.each {|bullet| unm.add_bullet_point(bullet.label) }
    return unm
  end

  def set_all_test_cases_unmatched
    @cases.each do |cc|
      unm = gen_unmatched(cc)
      @unmatched << unm
    end
  end

  def match_cases_to_chizus_descriptions_only
    @cases.each do |test_case|
      @chizus.each do |chizu|
        matched = false
        first_bullet_text = test_case.bullet_points.first.to_s
        #puts "tc bullet : #{first_bullet_text} #{first_bullet_text.class}"
        #puts "chizu.kkey: #{chizu.kkey} #{chizu.kkey.class}"
        #puts "match: #{first_bullet_text == chizu.kkey}"
        if chizu.kkey == first_bullet_text
          test_case.associated_commands_test_case_level = chizu.associated_commands
          matched = true
          break
        end
        if ! matched
          unless @unmatched.include? test_case.description
            dpa "couldn't find a match for #{test_case.description}", COLORS[:error]
            breakpoint
            puts
            @unmatched << gen_unmatched(test_case)
          end
        end
      end
    end
  end

=begin
  def match_cases_to_chizus
    @cases.each do |test_case|
      breakpoint
      test_case.bullet_points.each do |bullet|
        dpa "matching bullet: #{bullet}", :bb
        matched = false
        @chizus.each do |chizu|
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
=end

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
        matched = true
      end
    end
    return matched
  end

=begin
  def fire_cases
    @cases.each do |tcase|
      #puts tcase.label
      tcase.associated_commands.each do |cmd|
        eval cmd
      end
      tcase.associated_commands_test_case_level.each do |cmd|
        eval cmd
      end
    end
  end
=end
end
