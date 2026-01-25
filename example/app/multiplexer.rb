require './app/sprite_manager'
require './app/sprite_gfx'

class Multiplexer < R64::Base
  attr_reader :_sprite_managers

  MAX_SPRITES = 16
  WIDTH = 120
  HEIGHT = 160
  SIN_SIZE = 17 * 13
  COS_SIZE = 7 * 11
  DISTANCE = 11

  before do
    @_sprite_managers = []
    @_sprite_managers.push SpriteManager.new self
    @_sprite_managers.push SpriteManager.new self
    # @_sprite_managers.push SpriteManager.new self
    @_sprite_gfx = SpriteGfx.new self
  end

  # Shared algorithm for calculating sprite positions
  def calculate_sprite_positions_for_frame(frame_offset = 0)
    positions = []
    MAX_SPRITES.times do |sprite_idx|
      # Use the same algorithm as runtime: initial_index + frame_offset
      # Both X and Y use the same initial calculation as in variables method
      initial_index = (sprite_idx + 1) * DISTANCE % 256
      
      y_index = (initial_index + frame_offset) % SIN_SIZE
      x_index = (initial_index + frame_offset) % COS_SIZE
      
      y_pos = (Math.sin(2 * Math::PI * y_index / SIN_SIZE) * HEIGHT / 2).to_i + HEIGHT / 2
      x_pos = (Math.cos(2 * Math::PI * x_index / COS_SIZE) * WIDTH / 2).to_i + WIDTH / 2
      
      positions << {sprite: sprite_idx, y: y_pos, x: x_pos}
    end
    positions
  end

  def variables
    data :xindex, (1..MAX_SPRITES).map{|i| i * DISTANCE % COS_SIZE }
    data :yindex, (1..MAX_SPRITES).map{|i| i * DISTANCE % SIN_SIZE }

    # Initialize positions with frame 0 values instead of zeros
    initial_positions = calculate_sprite_positions_for_frame(0)
    data :xpositions, initial_positions.map { |pos| pos[:x] }
    data :ypositions, initial_positions.map { |pos| pos[:y] }
    
    var :swap_flag, 0
    var :sort_index, 0 # 2-byte pointer for indirect addressing
    
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
    
    # Calculate all possible sprite positions for the animation cycle using shared algorithm
    all_sprite_positions = []
    SIN_SIZE.times do |frame|
      frame_sprites = calculate_sprite_positions_for_frame(frame)
      
      # Sort sprites by Y position for this frame
      frame_sprites.sort! { |a, b| a[:y] <=> b[:y] }
      all_sprite_positions << frame_sprites.map { |s| s[:sprite] }
    end
    
    # puts all_sprite_positions.inspect

    # Generate the sprite order data table with individual labels for each row
    all_sprite_positions.each_with_index do |sprite_order, frame|
      data "sprite_order_row_#{frame}".to_sym, sprite_order
    end
  end

  def _sprite_order_pointers_lo
    # Generate pointer table (low bytes) pointing to sprite_order_row labels
    pointers_lo = []
    SIN_SIZE.times do |frame|
      pointers_lo << "sprite_order_row_#{frame}".to_sym % 256
    end
    data :sprite_order_pointers_lo, pointers_lo
  end
  
  def _sprite_order_pointers_hi
    # Generate pointer table (high bytes) pointing to sprite_order_row labels
    pointers_hi = []
    SIN_SIZE.times do |frame|
      pointers_hi << "sprite_order_row_#{frame}".to_sym / 256
    end
    data :sprite_order_pointers_hi, pointers_hi
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
    8.times do |i|
      ldy :sorted_sprite_order + i 
      lda :xpositions, :y 
      adc 0x20
      @_sprite_managers[0]._sprites[i].set_xpos :inline
      lda :ypositions, :y 
      @_sprite_managers[0]._sprites[i].set_ypos :inline
      @_sprite_managers[0]._sprites[i].set_position :inline
    end
  end

  def _get_first_sprite_ypos
    watch :sorted_sprite_order
    watch :ypositions
    ldy :sorted_sprite_order
    lda :ypositions, :y
    adc 0x45
  end

  def _set_sprite_positions_in_irq
    watch :sorted_sprite_order + 8
    watch 0xd012
    8.times do |i|
      ldy :sorted_sprite_order + i
      lda :ypositions, :y
      adc 0x45
    label "sprite_raster_loop_#{i}".to_sym
      cmp 0xd012
      bcs "sprite_raster_loop_#{i}".to_sym
      lda :sorted_sprite_order + 8 + i
      tay
      lda :ypositions, :y
      @_sprite_managers[1]._sprites[i].set_ypos :inline
      lda :xpositions, :y 
      adc 0x20
      @_sprite_managers[1]._sprites[i].set_xpos :inline
      @_sprite_managers[1]._sprites[i].set_position :inline
    end


    #   ldx 16
    # 8.times do |i|
    #   lda :sorted_sprite_order - 16, :x 
    #   tay
    #   lda :ypositions, :y
    #   adc 0x45
    # label "sprite_raster_loop_2#{i}".to_sym
    #   cmp 0xd012
    #   bpl "sprite_raster_loop_2#{i}".to_sym
    #   lda :sorted_sprite_order, :x 
    #   tay
    #   lda :ypositions, :y
    #   @_sprite_managers[1]._sprites[i].set_ypos
    #   lda :xpositions, :y 
    #   adc 0x20
    #   @_sprite_managers[1]._sprites[i].set_xpos
    #   @_sprite_managers[1]._sprites[i].set_position
    #   inx
    # end
  end

  def _get_precalculated_order
      # Use yindex[0] to determine which frame we're in
      ldy :yindex
      # Get low byte of pointer
      lda :sprite_order_pointers_lo, :y
      sta :copy_order_loop + 1
      
      # Get high byte of pointer
      lda :sprite_order_pointers_hi, :y
      sta :copy_order_loop + 2

    watch :copy_order_loop + 1
    watch :copy_order_loop + 2
      
      # Copy precalculated sprite order to current positions
      ldy 0
    label :copy_order_loop
      lda :copy_order_loop, :y
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