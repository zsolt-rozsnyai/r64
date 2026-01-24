require 'spec_helper'

RSpec.describe 'Memory Range Validation' do
  let(:memory) { R64::Memory.new }
  
  # Simulate non-precompile context by ensuring no assembler context
  before do
    Thread.current[:r64_assembler_context] = nil
  end
  
  describe 'memory range validation' do
    context 'when storing valid byte values' do
      it 'accepts values from 0 to 255' do
        expect { memory[0x1000] = 0 }.not_to raise_error
        expect { memory[0x1001] = 255 }.not_to raise_error
        expect { memory[0x1002] = 128 }.not_to raise_error
        
        expect(memory[0x1000]).to eq(0)
        expect(memory[0x1001]).to eq(255)
        expect(memory[0x1002]).to eq(128)
      end
    end
    
    context 'when storing out-of-range values' do
      it 'throws an error for values below 0' do
        expect { memory[0x1000] = -1 }.to raise_error(RangeError, /Value -1 is out of byte range \[0\.\.255\]/)
        expect { memory[0x1001] = -100 }.to raise_error(RangeError, /Value -100 is out of byte range \[0\.\.255\]/)
      end
      
      it 'throws an error for values above 255' do
        expect { memory[0x1000] = 256 }.to raise_error(RangeError, /Value 256 is out of byte range \[0\.\.255\]/)
        expect { memory[0x1001] = 1000 }.to raise_error(RangeError, /Value 1000 is out of byte range \[0\.\.255\]/)
        expect { memory[0x1002] = 8417 }.to raise_error(RangeError, /Value 8417 is out of byte range \[0\.\.255\]/)
      end
      
      it 'throws an error for non-integer values' do
        expect { memory[0x1000] = 255.5 }.to raise_error(RangeError, /Value 255.5 is not a valid integer/)
        expect { memory[0x1001] = "hello" }.to raise_error(RangeError, /Value "hello" is not a valid integer/)
      end
    end
    
    context 'chr compatibility' do
      it 'ensures stored values work with chr method' do
        memory[0x1000] = 65  # ASCII 'A'
        memory[0x1001] = 255
        
        expect { memory[0x1000].chr }.not_to raise_error
        expect { memory[0x1001].chr }.not_to raise_error
        expect(memory[0x1000].chr).to eq('A')
      end
    end
  end
  
  describe 'sprite order validation' do
    let(:multiplexer) do
      Class.new(R64::Base) do
        MAX_SPRITES = 8
        
        def test_sprite_order(sprite_indices)
          sprite_indices.each do |sprite_idx|
            raise RangeError, "Sprite index #{sprite_idx} out of range [0..#{MAX_SPRITES-1}]" unless (0...MAX_SPRITES).include?(sprite_idx)
            add_byte sprite_idx
          end
        end
      end.new
    end
    
    it 'accepts valid sprite indices' do
      expect { multiplexer.test_sprite_order([0, 1, 2, 3, 4, 5, 6, 7]) }.not_to raise_error
      expect { multiplexer.test_sprite_order([7, 6, 5, 4, 3, 2, 1, 0]) }.not_to raise_error
    end
    
    it 'throws an error for invalid sprite indices' do
      expect { multiplexer.test_sprite_order([0, 1, 2, 8]) }.to raise_error(RangeError, /Sprite index 8 out of range/)
      expect { multiplexer.test_sprite_order([-1, 1, 2, 3]) }.to raise_error(RangeError, /Sprite index -1 out of range/)
      expect { multiplexer.test_sprite_order([0, 1, 255, 3]) }.to raise_error(RangeError, /Sprite index 255 out of range/)
    end
  end
end
