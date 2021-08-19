class MarkdownTestCase
  def initialize(markdown)
    @markdown = markdown
  end
  def to_s
    @markdown
  end
end

def table_headings
  '|| test case || steps || expected result' 
end

def is_step?(ll)
  ll.start_with?('-') && not(ll.include?('>'))
end

def is_expected_result?(ll)
  ll.start_with?('-') && ll.include?('>')
end

def is_blank_line?(ll)
  ll == ''
end

def generate_markdown_and_print(test_case_lines)
  puts
  pa 'generating markdown ...', :gray, :bright
  desc = ''
  steps = ''
  expected_result = ''
  tcs = [ table_headings ]

  test_case_lines.each do |ll|
    if is_step? ll
      txt = ll.gsub('-', '').lstrip
      steps += "#{txt}\n"
    elsif is_expected_result? ll
      txt = ll.gsub('-', '').gsub('>','').lstrip
      expected_result += "* #{txt}\n"
    elsif is_blank_line? ll
      unless desc == ''
        row = "| #{desc} | #{steps.chomp} | #{expected_result.chomp}"
        tcs << MarkdownTestCase.new(row)
        desc = ''
        steps = ''
        expected_result = ''
      end
    else
      desc += ll.lstrip
    end
  end
  unless desc == ''
    row = "| #{desc} | #{steps.chomp} | #{expected_result.chomp}"
    tcs << MarkdownTestCase.new(row)
  end
  puts
  tcs.each do |tc|
    puts tc
  end
  puts
end
