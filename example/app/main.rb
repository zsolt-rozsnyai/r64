require './app/screen'

class Main < R64::Base
  before do
    setup start: 0x2000, end: 0x3fff
    @_screen = Screen.new self
  end

  # after do
  #   mem = @memory[0x2000..0x3fff].map{|i| i&.[](:value)}
  #   max = mem.reject{|i| i.nil?}.max
  #   puts mem.join(',')
  # end
  
  def _main
    @_screen.setup_irq
    
    label :main_loop
      jmp :main_loop
  end
end
