require './app/screen'

class Main < R64::Base
  before do
    setup start: 0x2000, end: 0x3fff
    @_screen = Screen.new self
  end
  
  def _main
    @_screen.setup_irq
    
    label :main_loop
      jmp :main_loop
  end
end

