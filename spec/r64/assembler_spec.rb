# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Assembler do
  let(:memory) { instance_double(R64::Memory) }
  let(:processor) { instance_double(R64::Processor, pc: 0x1000, start: 0x0801) }
  let(:options) { { memory: memory, processor: processor } }
  
  subject(:assembler) { described_class.new(options) }

  describe '#initialize' do
    context 'with default options' do
      subject(:assembler) { described_class.new }

      it 'creates a new assembler instance' do
        expect(assembler).to be_a(R64::Assembler)
      end

      it 'sets precompile to true' do
        expect(assembler.instance_variable_get(:@precompile)).to be true
      end
    end

    context 'with custom options' do
      let(:charsets) { { custom: 'charset' } }
      let(:options) { { charsets: charsets, memory: memory, processor: processor } }

      it 'stores the provided options' do
        expect(assembler.instance_variable_get(:@options)).to eq(options)
      end

      it 'stores the provided charsets' do
        expect(assembler.instance_variable_get(:@charsets)).to eq(charsets)
      end

      it 'stores the provided memory' do
        expect(assembler.instance_variable_get(:@memory)).to eq(memory)
      end

      it 'stores the provided processor' do
        expect(assembler.instance_variable_get(:@processor)).to eq(processor)
      end

      it 'sets pc_start from processor pc' do
        expect(assembler.instance_variable_get(:@pc_start)).to eq(0x1000)
      end
    end

    context 'with block given' do
      it 'yields to the block' do
        block_called = false
        described_class.new(options) { block_called = true }
        expect(block_called).to be true
      end
    end
  end

  describe 'module inclusion' do
    it 'includes Labels module' do
      expect(assembler).to be_a(R64::Assembler::Labels)
    end

    it 'includes Breakpoints module' do
      expect(assembler).to be_a(R64::Assembler::Breakpoints)
    end

    it 'includes Compile module' do
      expect(assembler).to be_a(R64::Assembler::Compile)
    end

    it 'includes Opcodes module' do
      expect(assembler).to be_a(R64::Assembler::Opcodes)
    end

    it 'includes Utils module' do
      expect(assembler).to be_a(R64::Assembler::Utils)
    end
  end
end
