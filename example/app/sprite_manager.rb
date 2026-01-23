require './app/sprite'

class SpriteManager < R64::Base
  attr_reader :_sprites

  before do
    @_sprites = []
    8.times do |i|
      @_sprites.push Sprite.new self
    end
  end

  def _set_positions
    @_sprites.each(&:set_position)
  end
end