module R64
  class Vic
    #require 'assembler'
    
    def initialize
      R64::Assembler.class_eval do

        def colors
          {
            :black => 0,
            :white => 1,
            :red => 2,
            :cyan => 3,
            :purple => 4,
            :green => 5,
            :blue => 6,
            :yellow => 7,
            :orange => 8,
            :brown => 9,
            :pink => 10,
            :darkgrey => 11,
            :grey => 12,
            :lightgreen => 13,
            :lightblue => 14,
            :lightgrey => 15
          }
        end

        def background *args
          set 0xd021, *args
        end

        def border *args
          set 0xd020, *args
        end
        
        def spritex num, *args
          _spritex num, *args
        end

        def spritey num, *args
          _spritey num, *args
        end
        
        def get_color color
          colors[color] || color
        end

private

        def _spritex num, *args
          if args.any? && args[0] > 255
          
          else
            set 0xd000 + (num * 2), args
          end
        end
        
        def _spritey num, args
          set 0xd001 + (num * 2), args
        end

      end
    end  
  end
end
