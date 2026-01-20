# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Assembler::Utils do
  let(:processor) { instance_double(R64::Processor, pc: 0x1000) }
  let(:memory) { instance_double(R64::Memory) }
  let(:assembler) { R64::Assembler.new(processor: processor, memory: memory) }

  describe '#resources' do
    it 'returns hash with processor and memory' do
      resources = assembler.resources
      expect(resources).to eq({ processor: processor, memory: memory })
    end
  end

  describe '#memory' do
    it 'returns the memory instance' do
      expect(assembler.memory).to eq(memory)
    end
  end

  describe '#processor' do
    it 'returns the processor instance' do
      expect(assembler.processor).to eq(processor)
    end
  end

  describe '#hi_lo' do
    context 'with valid 16-bit number' do
      it 'splits number into high and low bytes' do
        result = assembler.hi_lo(0x1234)
        expect(result).to eq({ hi: 0x12, lo: 0x34 })
      end

      it 'handles zero correctly' do
        result = assembler.hi_lo(0)
        expect(result).to eq({ hi: 0, lo: 0 })
      end

      it 'handles maximum 16-bit value' do
        result = assembler.hi_lo(65535)
        expect(result).to eq({ hi: 255, lo: 255 })
      end

      it 'handles values with zero low byte' do
        result = assembler.hi_lo(0x1000)
        expect(result).to eq({ hi: 0x10, lo: 0x00 })
      end

      it 'handles values with zero high byte' do
        result = assembler.hi_lo(0x00FF)
        expect(result).to eq({ hi: 0x00, lo: 0xFF })
      end
    end

    context 'with invalid numbers' do
      it 'raises exception for numbers greater than 65535' do
        expect { assembler.hi_lo(65536) }.to raise_error(Exception, 'Number out of range')
      end

      it 'raises exception for negative numbers' do
        expect { assembler.hi_lo(-1) }.to raise_error(Exception, 'Number out of range')
      end
    end
  end

  describe '#address' do
    before do
      allow(assembler).to receive(:get_label).with(:test_label).and_return(0x2000)
      allow(assembler).to receive(:set)
    end

    context 'with symbol store and symbol what' do
      it 'resolves label and calls set with hi_lo values' do
        expect(assembler).to receive(:set).with(0x1000, 0x00, {})
        expect(assembler).to receive(:set).with(0x1000, 0x20, { hi: true })
        
        assembler.address(0x1000, :test_label)
      end
    end

    context 'with numeric values' do
      it 'calls set with hi_lo values' do
        expect(assembler).to receive(:set).with(0x1000, 0x34, {})
        expect(assembler).to receive(:set).with(0x1000, 0x12, { hi: true })
        
        assembler.address(0x1000, 0x1234)
      end
    end

    context 'with options' do
      let(:options) { { some_option: true } }

      it 'passes options to set calls' do
        expect(assembler).to receive(:set).with(0x1000, 0x34, options)
        expect(assembler).to receive(:set).with(0x1000, 0x12, options.merge(hi: true))
        
        assembler.address(0x1000, 0x1234, options)
      end
    end
  end

  describe '#nop' do
    context 'with default count' do
      it 'responds to nop method' do
        expect(assembler).to respond_to(:nop)
      end
    end

    context 'method behavior' do
      it 'is defined by the Utils module' do
        expect(R64::Assembler::Utils.instance_methods).to include(:nop)
      end
    end
  end

  describe '#compile' do
    it 'executes block in assembler context' do
      result = nil
      assembler.compile do
        result = self.class
      end
      expect(result).to eq(R64::Assembler)
    end

    it 'passes arguments to block' do
      args_received = nil
      assembler.compile(1, 2, 3) do |*args|
        args_received = args
      end
      expect(args_received).to eq([1, 2, 3])
    end
  end

  describe '.included' do
    let(:test_class) { Class.new }

    before { test_class.include(R64::Assembler::Utils) }

    it 'adds descendants class method' do
      expect(test_class).to respond_to(:descendants)
    end

    it 'descendants method returns classes that inherit from it' do
      child_class = Class.new(test_class)
      descendants = test_class.descendants
      expect(descendants).to include(child_class)
    end
  end
end
