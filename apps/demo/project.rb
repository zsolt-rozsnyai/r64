require 'bits'

class Demo < R64::Assembler
  
  extend R64::Bits  
  
  #irq script based on: http://codebase64.org/doku.php?id=base:introduction_to_raster_irqs
  def main
    sei
    set 0xdc0d, 0x7f #shortcut for lda 0x7f; sta 0xdc0d
    set 0xdd0d #without second argument its simply a sta 0xdd0d
    lda 0xdc0d
    lda 0xdd0d
    set 0xd01a, 1
    set 0xd012, 20
    set 0xd011, 0x1b
    lda 0x35
    sta 0x01, :zeropage => true #TODO: this is not so pretty
    irq #shortcut for: address :irq, :irq
    cli
  label :self
    jmp :self
    
  label :irq
    border 0
    lda 22
  label :raster_fix
    cmp 0xd012
    bne :raster_fix
    nop 27
    [:darkgrey, :red, :grey, :pink, :lightgrey, :white, :lightgrey, :pink, :grey, :red, :darkgrey, :black].each do |color|
      border color
      nop 60
    end
    border 0
    set 0xd019, 0xff
    rti
  end
end

Demo.new(
  :start => 0x1000, 
  :end => 0x1fff
).compile!(
  :filename => 'demo'
)
