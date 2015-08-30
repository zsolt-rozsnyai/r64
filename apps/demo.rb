require 'bits'

class Demo < R64::Assembler
  
  extend R64::Bits  
  
  #irq script based on: http://codebase64.org/doku.php?id=base:introduction_to_raster_irqs
  def main
    fill 1
    var :counter, 10
    lda :counter
    fill 10
    fill 256 do |i, options|
      (Math.sin(i*3.14/128)*128+128).to_i
    end
    fill 10, 1
    sei
    set 0xdc0d, 0x7f #shortcut for lda 0x7f; sta 0xdc0d
    set 0xdd0d #without second argument its simply a sta 0xdd0d
    lda 0xdc0d
    lda 0xdd0d
    set 0xd01a, 1
    set 0xd012, 60
    set 0xd011, 0x1b
    lda 0x35
    sta 0x01, :zeropage => true #TODO: this is not so pretty
    irq #shortcut for: address :irq, :irq
    cli
  label :self
    jmp :self
   fill 10
  label :irq
    nop 24
    # you can use ruby to create anticycles
    [:darkgrey, :grey, :lightgrey, :white, :lightgrey, :grey, :darkgrey, :black].each do |color|
      border color
      background
      nop 26
      sta 0xd000-1
    end
    set 0xd019, 0xff
    rti
  end
end

Demo.new.compile!
