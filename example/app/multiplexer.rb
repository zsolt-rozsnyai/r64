class Multiplexer < R64::Base
  before do
    @_sprite_managers = []
    3.times do |i|
      @_sprite_managers.push SpriteManager.new self
    end
  end

  def _turn_on_sprites
    @_sprite_managers.each(&:turn_on_sprites)
  end

  def _move_sprites
    @_sprite_managers.each(&:move_sprites)
  end
end