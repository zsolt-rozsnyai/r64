module R64
  class Memory < Array
    attr_accessor :start, :finish
    
    def initialize options={}
      @start = options[:start] || 0
      @finish = options[:end] || 0xffff
      clear
    end
    
    def clear
      i = @start
      while i <= @finish
        self[i] = 0
        i = i + 1
      end
    end

    def inspect
      self.slice(0, 10).push('...')
    end
  end
end
