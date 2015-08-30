module R64
  class Memory < Array
    def initialize options={} 
      clear options if options[:start] && options[:end]
    end
    
    def clear options
      raise Exception.new('Set start and end options to clear the memory') if !options[:start] || !options[:end]
      i = options[:start]
      while i <= options[:end]
        self[i] = 0
        i = i + 1
      end
    end
  end
end
