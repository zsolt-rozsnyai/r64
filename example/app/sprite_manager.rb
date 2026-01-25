require './app/sprite'

# Manages a group of 8 hardware sprites (sprites 0-7)
class SpriteManager < R64::Base
  attr_reader :_sprites

  before do
    @_sprites = []
    8.times do |i|
      @_sprites.push Sprite.new self
    end
  end

  # Update positions for all 8 sprites
  def _set_positions
    @_sprites.each(&:set_position)
  end
end