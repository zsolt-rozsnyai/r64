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
      let(:options) { { memory: memory, processor: processor } }

      it 'stores the provided options' do
        expect(assembler.instance_variable_get(:@options)).to eq(options)
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
      it 'executes the block in assembler context' do
        block_called = false
        described_class.new(options) { block_called = true }
        expect(block_called).to be true
      end

      it 'allows access to assembler methods in block' do
        assembler_instance = nil
        described_class.new(options) do
          assembler_instance = self
        end
        expect(assembler_instance).to be_a(R64::Assembler)
      end
    end
  end

  describe 'documentation example' do
    context 'basic usage example from RDoc' do
      let(:memory) { R64::Memory.new }
      let(:processor) { R64::Processor.new }
      
      before do
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:open).and_yield(double('file', write: nil, print: nil))
      end

      it 'executes the documentation example successfully' do
        assembler = described_class.new do
          label :start
          lda 0x01
          sta 0xd020
          jmp :start
        end

        expect(assembler).to be_a(R64::Assembler)
        expect(assembler.instance_variable_get(:@precompile)).to be true
        
        # Verify labels were created
        labels = assembler.instance_variable_get(:@labels)
        expect(labels).to have_key(:start)
        
        # Should be able to compile without errors
        expect { assembler.compile!(save: true) }.not_to raise_error
      end

      it 'creates proper assembly code structure' do
        add_code_calls = []
        
        described_class.new do
          # Mock add_code to capture calls
          define_singleton_method(:add_code) do |options|
            add_code_calls << options
          end
          
          label :start
          lda 0x01
          sta 0xd020
          jmp :start
        end

        # Verify the assembly instructions were called
        expect(add_code_calls).to include(
          hash_including(token: :lda),
          hash_including(token: :sta),
          hash_including(token: :jmp)
        )
      end

      it 'handles label references correctly' do
        assembler = described_class.new do
          label :start
          lda 0x01
          sta 0xd020
          jmp :start
        end

        # Verify label references were tracked
        references = assembler.instance_variable_get(:@references)
        expect(references).to have_key(:start)
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
