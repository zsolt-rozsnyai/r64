# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Processor do
  describe 'DEFAULT_OPTIONS' do
    it 'defines default processor options' do
      expect(R64::Processor::DEFAULT_OPTIONS).to eq({
        start: 0x1000,
        a: 0,
        x: 0,
        y: 0,
        s: 0
      })
    end
  end

  describe '#initialize' do
    context 'with default options' do
      subject(:processor) { described_class.new }

      it 'creates a new processor instance' do
        expect(processor).to be_a(R64::Processor)
      end

      it 'sets default start address' do
        expect(processor.start).to eq(0x1000)
      end

      it 'sets PC to start address' do
        expect(processor.pc).to eq(0x1000)
      end

      it 'initializes registers to default values' do
        status = processor.status
        expect(status[:a]).to eq(0)
        expect(status[:x]).to eq(0)
        expect(status[:y]).to eq(0)
        expect(status[:s]).to eq(0)
      end
    end

    context 'with custom options' do
      let(:options) do
        {
          start: 0x2000,
          a: 0x42,
          x: 0x10,
          y: 0x20,
          s: 0xFF
        }
      end
      subject(:processor) { described_class.new(options) }

      it 'sets custom start address' do
        expect(processor.start).to eq(0x2000)
      end

      it 'sets PC to custom start address' do
        expect(processor.pc).to eq(0x2000)
      end

      it 'initializes registers to custom values' do
        status = processor.status
        expect(status[:a]).to eq(0x42)
        expect(status[:x]).to eq(0x10)
        expect(status[:y]).to eq(0x20)
        expect(status[:s]).to eq(0xFF)
      end
    end

    context 'with partial options' do
      let(:options) { { start: 0x3000, a: 0x55 } }
      subject(:processor) { described_class.new(options) }

      it 'merges with default options' do
        expect(processor.start).to eq(0x3000)
        expect(processor.pc).to eq(0x3000)
        
        status = processor.status
        expect(status[:a]).to eq(0x55)
        expect(status[:x]).to eq(0) # default
        expect(status[:y]).to eq(0) # default
        expect(status[:s]).to eq(0) # default
      end
    end
  end

  describe '#status' do
    let(:processor) { described_class.new(start: 0x1500, a: 0x11, x: 0x22, y: 0x33, s: 0x44) }

    it 'returns hash with all register values' do
      status = processor.status
      expect(status).to be_a(Hash)
      expect(status[:pc]).to eq(0x1500)
      expect(status[:a]).to eq(0x11)
      expect(status[:x]).to eq(0x22)
      expect(status[:y]).to eq(0x33)
      expect(status[:s]).to eq(0x44)
    end

    it 'reflects current PC value' do
      processor.increase_pc(10)
      status = processor.status
      expect(status[:pc]).to eq(0x150A)
    end
  end

  describe '#pc' do
    let(:processor) { described_class.new(start: 0x2000) }

    it 'returns current program counter' do
      expect(processor.pc).to eq(0x2000)
    end

    it 'reflects changes made by other methods' do
      processor.increase_pc(5)
      expect(processor.pc).to eq(0x2005)
    end
  end

  describe '#increase_pc' do
    let(:processor) { described_class.new(start: 0x1000) }

    context 'with default count' do
      it 'increases PC by 1' do
        processor.increase_pc
        expect(processor.pc).to eq(0x1001)
      end
    end

    context 'with specific count' do
      it 'increases PC by specified amount' do
        processor.increase_pc(5)
        expect(processor.pc).to eq(0x1005)
      end

      it 'handles large increments' do
        processor.increase_pc(0x100)
        expect(processor.pc).to eq(0x1100)
      end

      it 'handles zero increment' do
        original_pc = processor.pc
        processor.increase_pc(0)
        expect(processor.pc).to eq(original_pc)
      end
    end

    context 'multiple increments' do
      it 'accumulates increments correctly' do
        processor.increase_pc(3)
        processor.increase_pc(2)
        processor.increase_pc(1)
        expect(processor.pc).to eq(0x1006)
      end
    end
  end

  describe '#reset_pc' do
    let(:processor) { described_class.new(start: 0x2000) }

    it 'resets PC to start address' do
      processor.increase_pc(100)
      expect(processor.pc).to eq(0x2064)
      
      processor.reset_pc
      expect(processor.pc).to eq(0x2000)
    end

    it 'works after multiple PC changes' do
      processor.set_pc(0x5000)
      processor.increase_pc(50)
      processor.reset_pc
      expect(processor.pc).to eq(0x2000)
    end
  end

  describe '#set_pc' do
    let(:processor) { described_class.new(start: 0x1000) }

    it 'sets PC to specified address' do
      processor.set_pc(0x3000)
      expect(processor.pc).to eq(0x3000)
    end

    it 'allows setting PC to any valid address' do
      processor.set_pc(0xFFFF)
      expect(processor.pc).to eq(0xFFFF)
    end

    it 'allows setting PC to zero' do
      processor.set_pc(0x0000)
      expect(processor.pc).to eq(0x0000)
    end

    it 'overwrites previous PC value' do
      processor.increase_pc(100)
      processor.set_pc(0x4000)
      expect(processor.pc).to eq(0x4000)
    end
  end

  describe 'start accessor' do
    let(:processor) { described_class.new(start: 0x1000) }

    it 'allows reading start address' do
      expect(processor.start).to eq(0x1000)
    end

    it 'allows writing start address' do
      processor.start = 0x5000
      expect(processor.start).to eq(0x5000)
    end

    it 'changing start does not affect current PC' do
      processor.increase_pc(10)
      original_pc = processor.pc
      processor.start = 0x6000
      expect(processor.pc).to eq(original_pc)
    end

    it 'reset_pc uses updated start address' do
      processor.start = 0x7000
      processor.reset_pc
      expect(processor.pc).to eq(0x7000)
    end
  end

  describe 'register state management' do
    let(:processor) { described_class.new }

    it 'maintains register state independently of PC operations' do
      processor = described_class.new(a: 0x42, x: 0x10, y: 0x20, s: 0xFF)
      
      # PC operations shouldn't affect registers
      processor.increase_pc(100)
      processor.set_pc(0x5000)
      processor.reset_pc
      
      status = processor.status
      expect(status[:a]).to eq(0x42)
      expect(status[:x]).to eq(0x10)
      expect(status[:y]).to eq(0x20)
      expect(status[:s]).to eq(0xFF)
    end
  end

  describe 'edge cases' do
    context 'with boundary values' do
      it 'handles maximum 16-bit addresses' do
        processor = described_class.new(start: 0xFFFF)
        expect(processor.pc).to eq(0xFFFF)
        expect(processor.start).to eq(0xFFFF)
      end

      it 'handles zero addresses' do
        processor = described_class.new(start: 0x0000)
        expect(processor.pc).to eq(0x0000)
        expect(processor.start).to eq(0x0000)
      end

      it 'handles maximum register values' do
        processor = described_class.new(a: 0xFF, x: 0xFF, y: 0xFF, s: 0xFF)
        status = processor.status
        expect(status[:a]).to eq(0xFF)
        expect(status[:x]).to eq(0xFF)
        expect(status[:y]).to eq(0xFF)
        expect(status[:s]).to eq(0xFF)
      end
    end
  end
end
