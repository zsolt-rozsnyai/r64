require 'chunky_png'

module R64
  class Charset
    R64::Assembler.class_eval do
     
      def cs
        #puts '----------------'
        #puts @charsets
        @charsets
      end
    end
   
    def initialize options={}
      @start = options[:start] || 0x1000
      @memory = options[:memory] || R64::Memory.new
      (256*8).times do |i|
        @memory[@start + i] = 0
      end
      @objects = {}
      @next_character = 1
      default if defined? default
    end
    
    def memory
      @memory
    end
    
    def add name, file
      object = {
        :file => file
      }
      @objects[name] = convert_to_charset object
    end
    
    def get name
      @objects[name]
    end
    
private
    
    def convert_to_charset object
      image = ChunkyPNG::Image.from_file(object[:file])
      object[:characters] = []
      w = image.width / 8
      h = image.height / 8
      object[:width] = w
      object[:height] = h
      object[:length] = w * h
      h.times do |y|
        object[:characters][y] = []
        w.times do |x|
          character = @next_character
          raise Exception.new('Character out of range. Only 256 characters allowed in a Character set!') if character > 255
          @next_character = @next_character + 1
          object[:characters][y][x] = character
          8.times do |row|
            address = @start + character * 8 + row
            byte = 0
            mul = 128
            8.times do |col|
              pixel = image.get_pixel(x*8+col, y*8+row)
              byte = byte + mul if pixel > 0
              mul = mul / 2
            end
            @memory[address] = byte
          end
        end
      end
      puts "Image loaded: #{object[:file]} #{object}"
      object
    end
    
  end
end
