class Multiplexer < R64::Base
  MAX_SPRITES = 8
  MAX_HEIGHT = 160
  MAX_WIDTH = 200

  before do
    @_sprite_managers = []
    1.times do |i|
      @_sprite_managers.push SpriteManager.new self
    end
  end

  def _variables
    data :xindex, (1..MAX_SPRITES).map{|i| i * 8 }
    data :yindex, (1..MAX_SPRITES).map{|i| 255 - i * 8 }
    fill 200, 0
    label :yvalues
    fill 256 do |i|
      (Math.sin(2 * Math::PI * i / 256) * MAX_HEIGHT / 2).to_i + MAX_HEIGHT / 2
    end
    label :xvalues
    fill 256 do |i|
      (Math.cos(2 * Math::PI * i / 256) * MAX_WIDTH / 2).to_i + MAX_WIDTH / 2
    end
  end

  def _increment_indexes
      ldx 0
    label :increment_indexes_loop
      clc
      inc :xindex, :x
      clc
      inc :xindex, :x
      clc
      inc :yindex, :x
      inx
      cpx MAX_SPRITES
      bne :increment_indexes_loop
  end

  def _set_sprite_positions
    8.times do |i|
      ldx xindex + i
      lda :xvalues, :x
      @_sprite_managers[0]._sprites[i].set_xpos
      ldx yindex + i
      lda :yvalues, :x
      @_sprite_managers[0]._sprites[i].set_ypos
    end
  end

  def _turn_on_sprites
    @_sprite_managers.each(&:turn_on_sprites)
  end

  def _calculate_next_positions
    increment_indexes
    set_sprite_positions
    @_sprite_managers.each(&:set_positions)
  end
end