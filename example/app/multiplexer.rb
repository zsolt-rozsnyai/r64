require './app/sprite_manager'
require './app/sprite_gfx'

# Sprite multiplexing: 24 sprites using 8 hardware sprites
# Uses sine/cosine animation with pre-calculated lookup tables
class Multiplexer < R64::Base
  attr_reader :_sprite_managers

  MAX_SPRITES = 24
  WIDTH = 120
  HEIGHT = 180
  DEPTH = 7
  SIN_SIZE = 10 * 24
  COS_SIZE = 16 * 8
  WAVE_SIZE = 16 * DEPTH
  DISTANCE = 10

  YPOS_OFFSET = 51
  XPOS_OFFSET = 120
  SHAPE_OFFSET = 0x38

  # Background color (yellow)
  BG_COLOR = 7

  before do
    @_sprite_managers = []
    3.times do |i|
      @_sprite_managers.push SpriteManager.new self
    end
    @_sprite_gfx = SpriteGfx.new self
  end

  # Calculate Y position using sine wave
  def calculate_sinus_values(index)
    (Math.sin(2 * Math::PI * index / SIN_SIZE) * HEIGHT / 2).to_i + HEIGHT / 2
  end

  # Calculate X position using cosine wave
  def calculate_cos_values(index)
    (Math.cos(2 * Math::PI * index / COS_SIZE) * WIDTH / 2).to_i + WIDTH / 2
  end

  # Calculate wave position (sprite shape) - values between 0x78 and 0x7f
  def calculate_wave_values(index)
    (Math.cos(2 * Math::PI * index / WAVE_SIZE) * DEPTH / 2).to_i + DEPTH / 2
  end

  # Calculate all 24 sprite positions for given frame
  def calculate_sprite_positions_for_frame(frame_offset = 0)
    positions = []
    MAX_SPRITES.times do |sprite_idx|
      # Use the same algorithm as runtime: initial_index + frame_offset
      # Both X and Y use the same initial calculation as in variables method
      initial_index = (sprite_idx + 1) * DISTANCE % 256
      
      y_index = (initial_index + frame_offset) % SIN_SIZE
      x_index = (initial_index + frame_offset) % COS_SIZE
      wave_index = (initial_index + frame_offset) % WAVE_SIZE
      
      y_pos = YPOS_OFFSET + calculate_sinus_values(y_index)
      x_pos = XPOS_OFFSET + calculate_cos_values(x_index)
      wave_pos = calculate_wave_values(wave_index)
      
      positions << {sprite: sprite_idx, y: y_pos, x: x_pos, wave: wave_pos}
    end
    positions
  end

  # Memory layout: indices, positions, lookup tables
  def variables
    data :xindex, (1..MAX_SPRITES).map{|i| i * DISTANCE % COS_SIZE }
    data :yindex, (1..MAX_SPRITES).map{|i| i * DISTANCE % SIN_SIZE }
    data :waveindex, (1..MAX_SPRITES).map{|i| i * DISTANCE % WAVE_SIZE }

    # Initialize positions with frame 0 values instead of zeros
    initial_positions = calculate_sprite_positions_for_frame(0)
    data :xpositions, initial_positions.map { |pos| pos[:x] }
    data :ypositions, initial_positions.map { |pos| pos[:y] }
    data :wavepositions, initial_positions.map { |pos| pos[:wave] }
    
    data :sorted_sprite_order, Array.new(MAX_SPRITES, 0)
    
    label :yvalues
    fill SIN_SIZE do |i|
      YPOS_OFFSET + calculate_sinus_values(i)
    end
    
    label :xvalues
    fill COS_SIZE do |i|
      XPOS_OFFSET + calculate_cos_values(i)
    end

    label :wavevalues
    fill WAVE_SIZE do |i|
      SHAPE_OFFSET + calculate_wave_values(i)
    end
  end

  # Pre-calculate sprite order for all frames (sorted by Y position)
  def _sprite_order_data
    # This creates a lookup table where each row contains sprite indices sorted by Y position
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
      inc :waveindex, :x
      clc
      lda :waveindex, :x
      cmp WAVE_SIZE
      bne :wave_no_reset
      lda 0
      sta :waveindex, :x
    label :wave_no_reset
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
      lda :waveindex, :x
      tay
      lda :wavevalues, :y
      sta :wavepositions, :x
      inx
      cpx MAX_SPRITES
      bne :fill_sorter_loop
  end

  def _set_sprite_positions
    8.times do |i|
      ldy :sorted_sprite_order + i 
      lda :xpositions, :y 
      @_sprite_managers[0]._sprites[i].set_xpos :inline
      lda :ypositions, :y 
      @_sprite_managers[0]._sprites[i].set_ypos :inline
      lda :wavepositions, :y 
      @_sprite_managers[0]._sprites[i].set_shape :inline
      @_sprite_managers[0]._sprites[i].set_position :inline
    end
  end

  def _get_first_sprite_ypos
    ldy :sorted_sprite_order
    lda :ypositions, :y
    clc
    adc 21
  end

  # Position sprites 8-23 with raster timing (wait for beam position)
  def _set_sprite_positions_in_irq
    8.times do |i|
      # lda i
      # sta 0xd021
      ldy :sorted_sprite_order + i
      lda :ypositions, :y
      clc
      adc 21
    label "sprite_raster_loop_#{i}".to_sym
      cmp 0xd012
      bcc "continue_sprite_setup_#{i}".to_sym
      jmp "sprite_raster_loop_#{i}".to_sym
    label "continue_sprite_setup_#{i}".to_sym
      lda :sorted_sprite_order + 8 + i
      tay
      lda :ypositions, :y
      @_sprite_managers[1]._sprites[i].set_ypos :inline
      lda :xpositions, :y 
      @_sprite_managers[1]._sprites[i].set_xpos :inline
      lda :wavepositions, :y 
      @_sprite_managers[1]._sprites[i].set_shape :inline
      @_sprite_managers[1]._sprites[i].set_position :inline
      # lda BG_COLOR
      # sta 0xd021
    end

    8.times do |i|
      # lda i
      # sta 0xd021
      ldy :sorted_sprite_order + 8 + i
      lda :ypositions, :y
      clc
      adc 21
    label "sprite_raster_loop_2#{i}".to_sym
      cmp 0xd012
      bcc "continue_sprite_setup_2#{i}".to_sym
      jmp "sprite_raster_loop_2#{i}".to_sym
    label "continue_sprite_setup_2#{i}".to_sym
      lda :sorted_sprite_order + 16 + i
      tay
      lda :ypositions, :y
      @_sprite_managers[1]._sprites[i].set_ypos :inline
      lda :xpositions, :y 
      @_sprite_managers[1]._sprites[i].set_xpos :inline
      lda :wavepositions, :y 
      @_sprite_managers[1]._sprites[i].set_shape :inline
      @_sprite_managers[1]._sprites[i].set_position :inline
      # lda BG_COLOR
      # sta 0xd021
    end
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
      
      # Copy precalculated sprite order to current positions
      ldy 0
    label :copy_order_loop
      lda :copy_order_loop, :y
      sta :sorted_sprite_order, :y
      iny
      cpy MAX_SPRITES
      bne :copy_order_loop
  end

  # Main update: increment indices, calculate positions, sort, display
  def _calculate_next_positions
    increment_indexes
    calculate_positions
    get_precalculated_order
    set_sprite_positions
  end
end