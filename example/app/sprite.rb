class Sprite < R64::Base
  def variables
    @num = @index % 8
    var :xpos, 24 * @num
    var :ypos, 8 * @num
    var :xspeed, (1.5 * @num).to_i % 4
    var :yspeed, (1.9 * @num).to_i % 4
    var :color, @num
    var :num, @num
    var :shape, 0xc0 + (@num / 2).to_i
  end

  def _move
      lda :xpos
      clc
      adc :xspeed
      sta :xpos
      lda :ypos
      clc
      adc :yspeed
      sta :ypos
    set_position
  end

  def _turn_on
      lda :color
      sta 0xd027 + @num
    set_position
  end

  def _set_position
      lda :xpos
      sta 0xd000 + @num * 2
      lda :ypos
      sta 0xd001 + @num * 2
      lda :shape
      sta 0x07f8 + @num
  end
end