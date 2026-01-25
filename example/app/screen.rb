require './app/multiplexer'

class Screen < R64::Base
  before do
    @_multiplexer = Multiplexer.new self
    @calculator_raster = 0xef
  end

  def _setup_irq
      sei
      lda 0x7f
      sta 0xdc0d
      sta 0xdd0d
      lda 0xdc0d
      lda 0xdd0d
    set 0xd01a, 1
    set 0xd012, @calculator_raster
    set 0xd011, 0x1b
    set 0xd018, 0x14
      lda 0xdd00
      ora 0x03
      sta 0xdd00
      lda 0x35
      sta 0x01, :zeropage => true #TODO: this is not so pretty
    address 0xfffe, :_irq

      lda 0xd011
      ora 0x10
      sta 0xd011
      lda 0xff
      sta 0xd015
      lda 0
      sta 0xd010
      clear
      cli
  end

  def _irq
      lda 0x07
      sta 0xd021
      sta 0xd020

      @_multiplexer.calculate_next_positions

      @_multiplexer.get_first_sprite_ypos
      # clc
      # adc 0x20 + 20
      sta 0xd012
    address 0xfffe, :_irq2

      lda 0x07
      sta 0xd021
      sta 0xd020

      set 0xd019, 0xff
      rti
  end

  def _irq2
      lda 0x07
      sta 0xd021
      sta 0xd020

      @_multiplexer.set_sprite_positions_in_irq

      lda @calculator_raster
      sta 0xd012
    address 0xfffe, :_irq

      lda 0x07
      sta 0xd021
      sta 0xd020

      set 0xd019, 0xff
      rti
  end

  def _clear
      ldx 0
    label :clear_loop
      lda 0x20
      sta 0x0400, :x
      sta 0x0500, :x
      sta 0x0600, :x
      sta 0x0700, :x
      inx
      cpx 0
      bne :clear_loop
  end
end