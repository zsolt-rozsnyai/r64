class Sprite < R64::Base
  def variables
    @num = @index % 8
    var :xpos, 0
    var :ypos, 0
    var :num, @num
    var :shape, 0xc0
    var :color, 0
  end

  def _turn_on
      lda :color
      sta 0xd027 + @num
      lda :shape
      sta 0x07f8 + @num
  end

  def _set_xpos
      sta :xpos
  end

  def _set_ypos
      sta :ypos
  end

  def _set_position
      lda :xpos
      clc
      adc 0x20
      sta 0xd000 + @num * 2
      lda :ypos
      clc
      adc 0x30
      sta 0xd001 + @num * 2
      turn_on
  end
end