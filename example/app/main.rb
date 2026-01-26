require './app/screen'
require './app/music'

# Main entry point - sets up memory and starts the demo
# Entry point: 0x2000 (SYS 8192)
class Main < R64::Base
  before do
    setup start: 0x0e00, end: 0x4fff, entry: 0x2000
    @_music = Music.new self
    @_screen = Screen.new self
  end
  
  # Setup IRQ system and run main loop (IRQs do all the work)
  def _main
    @_screen.setup_irq
    lda 0
    ldy 0
    ldx 0
    jsr 0x1000
    
    label :main_loop
      jmp :main_loop
  end
end
