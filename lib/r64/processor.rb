module R64
  class Processor
    attr_accessor :start
  
    DEFAULT_OPTIONS = {:start => 0x1000, :a => 0, :x => 0, :y => 0, :s => 0}
    
    def initialize options={}
      options = DEFAULT_OPTIONS.merge options
      @start = options[:start]
      @pc = options[:start]
      @a = options[:a]
      @x = options[:x]
      @y = options[:y]
      @s = options[:s]
    end
    
    def status
      {:pc => @pc, :a => @a, :x => @x, :y => @y, :s => @s}
    end
    
    def pc
      @pc
    end
    
    def increase_pc count=1
      @pc = @pc + count
    end
    
    def reset_pc
      @pc = @start
    end
    
    def set_pc address
      @pc = address
    end
    
  end

end
