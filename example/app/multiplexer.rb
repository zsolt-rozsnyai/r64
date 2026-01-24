require './app/sprite_manager'
require './app/sprite_gfx'

class Multiplexer < R64::Base
  attr_reader :_sprite_managers

  MAX_SPRITES = 8
  WIDTH = 120
  HEIGHT = 160
  SIN_SIZE = 17 * 11
  COS_SIZE = 7 * 13

  before do
    @_sprite_managers = []
    @_sprite_managers.push SpriteManager.new self
    @_sprite_gfx = SpriteGfx.new self
  end

  def variables
    data :xindex, (1..MAX_SPRITES).map{|i| i * 9 }
    data :yindex, (1..MAX_SPRITES).map{|i| i * 9 }

    data :xpositions, Array.new(MAX_SPRITES, 0)
    data :ypositions, Array.new(MAX_SPRITES, 0)
    
    var :swap_flag, 0
    var :sort_index, 0
    var :current_row_ptr, 0
    
    data :sorted_sprite_order, Array.new(MAX_SPRITES, 0)
    
    label :yvalues
    fill SIN_SIZE do |i|
      (Math.sin(2 * Math::PI * i / SIN_SIZE) * HEIGHT / 2).to_i + HEIGHT / 2
    end
    
    label :xvalues
    fill COS_SIZE do |i|
      (Math.cos(2 * Math::PI * i / COS_SIZE) * WIDTH / 2).to_i + WIDTH / 2
    end

    data :sorted_x, Array.new(MAX_SPRITES, 0) 
    data :sorted_y, Array.new(MAX_SPRITES, 0)
  end

  def _sprite_order_data
    # Generate precalculated sprite orders for all possible Y positions
    # This creates a lookup table where each row contains sprite indices sorted by Y position
    
    # First, calculate all possible sprite positions for the animation cycle
    all_sprite_positions = []
    SIN_SIZE.times do |frame|
      frame_sprites = []
      MAX_SPRITES.times do |sprite_idx|
        y_index = ((sprite_idx + 1) * 9 + frame) % SIN_SIZE
        x_index = ((sprite_idx + 1) * 9 + frame) % COS_SIZE
        
        y_pos = (Math.sin(2 * Math::PI * y_index / SIN_SIZE) * HEIGHT / 2).to_i + HEIGHT / 2
        x_pos = (Math.cos(2 * Math::PI * x_index / COS_SIZE) * WIDTH / 2).to_i + WIDTH / 2
        
        frame_sprites << {sprite: sprite_idx, y: y_pos, x: x_pos}
      end
      
      # Sort sprites by Y position for this frame
      frame_sprites.sort! { |a, b| a[:y] <=> b[:y] }
      all_sprite_positions << frame_sprites.map { |s| s[:sprite] }
    end
    
    # Generate the sprite order data table with individual labels for each row
    all_sprite_positions.each_with_index do |sprite_order, frame|
      data "sprite_order_row_#{frame}".to_sym, sprite_order
    end
  end

  def _sprite_order_pointers_lo
    # Generate pointer table (low bytes) - placeholder for now
    # In a real implementation, this would need to be resolved during the second compilation pass
    data :sprite_order_pointers_lo, Array.new(SIN_SIZE, 0)
  end
  
  def _sprite_order_pointers_hi
    # Generate pointer table (high bytes) - placeholder for now  
    # In a real implementation, this would need to be resolved during the second compilation pass
    data :sprite_order_pointers_hi, Array.new(SIN_SIZE, 0)
  end

  def _increment_indexes
      ldx 0
    label :increment_indexes_loop
      inc :xindex, :x
      clc
      lda :xindex, :x
      cmp COS_SIZE
      bne :cos_no_reset
      lda 0
      sta :xindex, :x
    label :cos_no_reset
      inc :yindex, :x
      clc
      lda :yindex, :x
      cmp SIN_SIZE
      bne :sin_no_reset
      lda 0
      sta :yindex, :x
    label :sin_no_reset
      inx
      cpx MAX_SPRITES
      bne :increment_indexes_loop
  end

  def _calculate_positions
      ldx 0
    label :fill_sorter_loop
      lda :xindex, :x
      tay
      lda :xvalues, :y
      sta :xpositions, :x
      lda :yindex, :x
      tay
      lda :yvalues, :y
      sta :ypositions, :x
      inx
      cpx MAX_SPRITES
      bne :fill_sorter_loop
  end

  # def _insertion_sort
  #   label :i, 0x02
  #   label :j, 0x03
  #   label :tmp_xpos, 0x04
  #   label :tmp_ypos, 0x05
  #     ldx 1
  #   label :sort_outer_loop
  #     stx :i, zeropage: true

  #     lda :ypositions, :x
  #     sta :tmp_ypos, zeropage: true
  #     lda :xpositions, :x
  #     sta :tmp_xpos, zeropage: true

  #     dex
  #     stx :j, zeropage: true
    
  #   label :sort_inner_loop
  #     ldx :j, zeropage: true
  #     lda :ypositions, :x
  #     cmp :tmp_ypos, zeropage: true
  #     bcc :insert

  #     lda :ypositions, :x
  #     sta :ypositions + 1, :x
  #     lda :xpositions, :x
  #     sta :xpositions + 1, :x

  #     dex
  #     stx :j, zeropage: true
  #     bpl :sort_inner_loop

  #   label :insert
  #     inx
  #     lda :tmp_ypos, zeropage: true
  #     sta :ypositions, :x
  #     lda :tmp_xpos, zeropage: true
  #     sta :xpositions, :x

  #     ldx :i, zeropage: true
  #     inx
  #     cpx MAX_SPRITES
  #     bne :sort_outer_loop
  # end

  def _set_sprite_positions
    ldx 0
    8.times do |i|
      lda :sorted_sprite_order, :x 
      tay
      lda :xpositions, :y 
      adc 0x20
      @_sprite_managers[0]._sprites[i].set_xpos :inline
      lda :ypositions, :y 
      @_sprite_managers[0]._sprites[i].set_ypos :inline
      @_sprite_managers[0]._sprites[i].set_position :inline
      inx
    end
  end

  def _get_precalculated_order
    # Use yindex[0] to determine which frame we're in
    lda :yindex
    tay
    
    # Get low byte of pointer
    lda :_sprite_order_pointers_lo, :y
    sta :current_row_ptr
    
    # Get high byte of pointer
    lda :_sprite_order_pointers_hi, :y
    sta :current_row_ptr + 1
    
    # Copy precalculated sprite order to current positions
    ldy 0
    label :copy_order_loop
      lda (:current_row_ptr), :y
      sta :sorted_sprite_order, :y
      iny
      cpy MAX_SPRITES
      bne :copy_order_loop
  end

  def _calculate_next_positions
    increment_indexes
    calculate_positions
    get_precalculated_order
    set_sprite_positions

    watch :sorted_sprite_order
  end
end