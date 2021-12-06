module MockTools
  class << self
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
  end
end
