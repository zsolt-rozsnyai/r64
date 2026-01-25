class Sprite < R64::Base
  before do
    @num = @index % 8
  end

  def variables
    var :xpos, 0
    var :ypos, 0
    var :shape, 0x3f
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
      sta 0xd000 + @num * 2
      lda :ypos
      sta 0xd001 + @num * 2
    #   inc :shape
    watch :shape
    turn_on :inline
  end
end