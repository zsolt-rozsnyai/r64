require './app/screen'

# Main entry point - sets up memory and starts the demo
# Entry point: 0x2000 (SYS 8192)
class Main < R64::Base
  before do
    setup start: 0x0fc0, end: 0x4fff, entry: 0x2000
    @_screen = Screen.new self
  end
  
  # Setup IRQ system and run main loop (IRQs do all the work)
  def _main
    @_screen.setup_irq
    
    label :main_loop
      jmp :main_loop
  end
end
