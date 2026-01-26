# Manages position, color and shape for a single sprite
class Sprite < R64::Base
  before do
    @num = @index % 8
  end

  # Memory variables for this sprite
  def variables
    var :xpos, 0
    var :ypos, 0
    var :shape, 0x3f
    var :color, 3
  end

  # Turn on sprite by setting color and shape registers
  def _turn_on
      lda :color
      sta 0xd027 + @num
      lda :shape
      sta 0x07f8 + @num
  end

  # Store X position from accumulator
  def _set_xpos
      sta :xpos
  end

  # Store Y position from accumulator
  def _set_ypos
      sta :ypos
  end

  # Store shape from accumulator
  def _set_shape
      sta :shape
  end

  # Apply stored position to VIC-II registers and turn on sprite
  def _set_position
      lda :xpos
      sta 0xd000 + @num * 2
      lda :ypos
      sta 0xd001 + @num * 2
    turn_on :inline
  end
end