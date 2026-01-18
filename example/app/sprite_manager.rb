class SpriteManager < R64::Base
  before do
    @_sprites = []
    8.times do |i|
      @_sprites.push Sprite.new self
    end
    @_sprite_gfx = SpriteGfx.new self
  end

  def _turn_on_sprites
    @_sprites.each(&:turn_on)
  end

  def _move_sprites
    @_sprites.each(&:move)
  end
end