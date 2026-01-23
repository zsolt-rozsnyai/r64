# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Symbol Extensions' do
  let(:processor) { instance_double(R64::Processor, pc: 0x1000) }
  let(:memory) { instance_double(R64::Memory) }
  let(:assembler) do
    R64::Assembler.new(processor: processor, memory: memory).tap do |asm|
      # Set up test labels
      asm.instance_variable_set(:@labels, {
        test_label: 0x2000,
        zero_page_label: 0x42,
        high_label: 0x3000
      })
      asm.instance_variable_set(:@precompile, false)
    end
  end

  before do
    # Set up thread-local assembler context
    Thread.current[:r64_assembler_context] = assembler
  end

  after do
    # Clean up thread-local context
    Thread.current[:r64_assembler_context] = nil
  end

  describe 'arithmetic operations on assembly labels' do
    describe '#+ (addition)' do
      it 'resolves label and adds the operand' do
        result = :test_label + 10
        expect(result).to eq(0x2000 + 10)
      end

      it 'works with zero page labels' do
        result = :zero_page_label + 5
        expect(result).to eq(0x42 + 5)
      end

      it 'handles negative operands' do
        result = :test_label + (-10)
        expect(result).to eq(0x2000 - 10)
      end

      it 'raises NoMethodError for non-existent labels' do
        expect { :nonexistent_label + 1 }.to raise_error(NoMethodError, /undefined method `\+' for :nonexistent_label:Symbol/)
      end
    end

    describe '#- (subtraction)' do
      it 'resolves label and subtracts the operand' do
        result = :test_label - 10
        expect(result).to eq(0x2000 - 10)
      end

      it 'works with zero page labels' do
        result = :zero_page_label - 5
        expect(result).to eq(0x42 - 5)
      end

      it 'raises NoMethodError for non-existent labels' do
        expect { :nonexistent_label - 1 }.to raise_error(NoMethodError, /undefined method `-' for :nonexistent_label:Symbol/)
      end
    end

    describe '#* (multiplication)' do
      it 'resolves label and multiplies by the operand' do
        result = :test_label * 2
        expect(result).to eq(0x2000 * 2)
      end

      it 'works with zero page labels' do
        result = :zero_page_label * 3
        expect(result).to eq(0x42 * 3)
      end

      it 'raises NoMethodError for non-existent labels' do
        expect { :nonexistent_label * 2 }.to raise_error(NoMethodError, /undefined method `\*' for :nonexistent_label:Symbol/)
      end
    end

    describe '#/ (division)' do
      it 'resolves label and divides by the operand' do
        result = :test_label / 2
        expect(result).to eq(0x2000 / 2)
      end

      it 'works with zero page labels' do
        result = :zero_page_label / 2
        expect(result).to eq(0x42 / 2)
      end

      it 'raises NoMethodError for non-existent labels' do
        expect { :nonexistent_label / 2 }.to raise_error(NoMethodError, /undefined method `\/' for :nonexistent_label:Symbol/)
      end
    end

    describe '#% (modulo)' do
      it 'resolves label and calculates modulo with the operand' do
        result = :test_label % 256
        expect(result).to eq(0x2000 % 256)
      end

      it 'works with zero page labels' do
        result = :zero_page_label % 16
        expect(result).to eq(0x42 % 16)
      end

      it 'raises NoMethodError for non-existent labels' do
        expect { :nonexistent_label % 2 }.to raise_error(NoMethodError, /undefined method `%' for :nonexistent_label:Symbol/)
      end
    end
  end

  describe 'context resolution' do
    context 'with valid assembler context' do
      it 'finds labels in the current assembler context' do
        result = :test_label + 1
        expect(result).to eq(0x2001)
      end
    end

    context 'with memory caller context' do
      let(:memory_caller_with_get_label) do
        double('memory_caller').tap do |obj|
          allow(obj).to receive(:respond_to?).with(:get_label).and_return(true)
          allow(obj).to receive(:get_label).with(:caller_label).and_return(0x5000)
          allow(obj).to receive(:instance_variable_get).with(:@labels).and_return({ caller_label: 0x5000 })
        end
      end

      before do
        Thread.current[:memory_caller] = memory_caller_with_get_label
        Thread.current[:r64_assembler_context] = nil
      end

      it 'uses memory caller context when available' do
        result = :caller_label + 1
        expect(result).to eq(0x5001)
      end
    end

    context 'without assembler context' do
      before do
        Thread.current[:r64_assembler_context] = nil
        Thread.current[:memory_caller] = nil
      end

      it 'raises NoMethodError when no context is available' do
        expect { :test_label + 1 }.to raise_error(NoMethodError, /undefined method `\+' for :test_label:Symbol/)
      end
    end
  end

  describe 'precompilation behavior' do
    before do
      assembler.instance_variable_set(:@precompile, true)
    end

    it 'returns consistent placeholder values during precompilation' do
      result = :test_label + 10
      expect(result).to eq(12345 + 10) # placeholder + operand
    end

    it 'works with all arithmetic operations during precompilation' do
      expect(:test_label + 1).to eq(12346)
      expect(:test_label - 1).to eq(12344)
      expect(:test_label * 2).to eq(24690)
      expect(:test_label / 2).to eq(6172)
      expect(:test_label % 100).to eq(45)
    end
  end

  describe 'integration with real assembly code patterns' do
    it 'supports array indexing patterns' do
      # Simulates: lda :data_array + index
      index = 5
      result = :test_label + index
      expect(result).to eq(0x2000 + 5)
    end

    it 'supports offset calculations' do
      # Simulates: sta :buffer + 1, :x
      result = :zero_page_label + 1
      expect(result).to eq(0x43)
    end

    it 'supports address arithmetic for 16-bit operations' do
      # Simulates high/low byte calculations
      low_byte = :test_label % 256
      high_byte = :test_label / 256
      
      expect(low_byte).to eq(0x00)   # 0x2000 % 256
      expect(high_byte).to eq(0x20)  # 0x2000 / 256
    end
  end

  describe 'error handling' do
    it 'provides clear error messages for non-existent labels' do
      expect { :missing_label + 1 }.to raise_error(NoMethodError) do |error|
        expect(error.message).to include('undefined method')
        expect(error.message).to include(':missing_label:Symbol')
      end
    end

    it 'handles context resolution errors gracefully' do
      Thread.current[:r64_assembler_context] = double('invalid_context')
      
      expect { :test_label + 1 }.to raise_error(NoMethodError, /undefined method `\+' for :test_label:Symbol/)
    end

    it 'raises LabelResolutionError internally when no context is available' do
      Thread.current[:r64_assembler_context] = nil
      Thread.current[:memory_caller] = nil
      
      expect { :test_label.send(:resolve_label_arithmetic, :+, 1) }.to raise_error(LabelResolutionError, /No assembler context available/)
    end

    it 'raises LabelResolutionError internally when label is not found' do
      expect { :nonexistent_label.send(:resolve_label_arithmetic, :+, 1) }.to raise_error(LabelResolutionError, /Failed to resolve label/)
    end

    it 'preserves original Symbol behavior for non-label operations' do
      # This should still work as normal Symbol behavior
      expect(:test_symbol.to_s).to eq('test_symbol')
      expect(:test_symbol.class).to eq(Symbol)
    end
  end
end
