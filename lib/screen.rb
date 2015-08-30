module R64
  class Screen
   
    def initialize options={}
      @start = options[:start] || 0x7000
      @memory = options[:memory] || R64::Memory.new
      (40*25).times do |i|
        @memory[@start + i] = 0
      end
      @objects = {}
    end
    
    def memory
      @memory
    end
    
    def add object, x, y
      startpos = 40*y+x
      object[:height].times do |row|
        object[:width].times do |col|
          address = @start + row*40+col
          @memory[address] = object[:characters][row][col]
        end
      end
    end
    
private
    
  end
end
