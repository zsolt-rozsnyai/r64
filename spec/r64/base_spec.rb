# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Base do
  let(:processor) { instance_double(R64::Processor, pc: 0x1000, start: 0x0801, set_pc: nil, "start=": nil) }
  let(:memory) { instance_double(R64::Memory, start: 0x0801, finish: 0x2000, "start=": nil, "finish=": nil) }
  let(:parent) { instance_double(R64::Base, memory: memory, processor: processor) }

  describe '#initialize' do
    context 'with no parent' do
      subject(:base) { described_class.new }

      it 'creates a new base instance' do
        expect(base).to be_a(R64::Base)
      end

      it 'sets parent to nil' do
        expect(base.instance_variable_get(:@parent)).to be_nil
      end

      it 'sets rendered to false' do
        expect(base.instance_variable_get(:@rendered)).to be false
      end

      it 'sets index from class instance count' do
        initial_count = described_class.instance_count
        expect(base.instance_variable_get(:@index)).to eq(initial_count)
      end

      it 'increments class instance count' do
        initial_count = described_class.instance_count
        described_class.new
        expect(described_class.instance_count).to eq(initial_count + 1)
      end
    end

    context 'with parent' do
      subject(:base) { described_class.new(parent) }

      before do
        allow(parent).to receive(:verbose).and_return(false)
      end

      it 'stores the parent' do
        expect(base.instance_variable_get(:@parent)).to eq(parent)
      end

      it 'passes parent memory and processor to super' do
        expect(base.memory).to eq(memory)
        expect(base.processor).to eq(processor)
      end
    end

    context 'with verbose parent' do
      let(:verbose_base_class) do
        Class.new(R64::Base) do
          def verbose
            true
          end
        end
      end

      before do
        allow($stdout).to receive(:puts)
      end

      it 'prints parent information when verbose' do
        expect($stdout).to receive(:puts).with("parent: #{parent}")
        verbose_base_class.new(parent)
      end
    end

    context 'with before hooks' do
      let(:test_class) do
        Class.new(R64::Base) do
          before { @before_called = true }
        end
      end

      it 'executes before hooks during initialization' do
        instance = test_class.new
        expect(instance.instance_variable_get(:@before_called)).to be true
      end
    end
  end

  describe '#setup' do
    subject(:base) { described_class.new(parent) }

    before do
      allow(parent).to receive(:verbose).and_return(false)
      allow(base).to receive(:set_entrypoint)
    end

    context 'with start and end options' do
      let(:options) { { start: 0x2000, end: 0x3000 } }

      it 'sets processor PC to start address' do
        expect(processor).to receive(:set_pc).with(0x2000)
        base.setup(options)
      end

      it 'sets processor start address' do
        expect(processor).to receive(:start=).with(0x2000)
        base.setup(options)
      end

      it 'sets memory start address' do
        expect(memory).to receive(:start=).with(0x2000)
        base.setup(options)
      end

      it 'sets memory finish address' do
        expect(memory).to receive(:finish=).with(0x3000)
        base.setup(options)
      end

      it 'calls set_entrypoint' do
        expect(base).to receive(:set_entrypoint)
        base.setup(options)
      end
    end

    context 'with empty options' do
      it 'handles nil values gracefully' do
        expect { base.setup({}) }.not_to raise_error
      end
    end
  end

  describe '#object_name' do
    subject(:base) { described_class.new }

    it 'returns class name with index' do
      index = base.instance_variable_get(:@index)
      expect(base.object_name).to eq("R64::Base#{index}")
    end
  end

  describe 'module inclusion' do
    subject(:base) { described_class.new }

    it 'includes Hooks module' do
      expect(base).to be_a(R64::Base::Hooks)
    end

    it 'includes Dispatch module' do
      expect(base).to be_a(R64::Base::Dispatch)
    end

    it 'includes Rendering module' do
      expect(base).to be_a(R64::Base::Rendering)
    end
  end

  describe 'inheritance' do
    it 'inherits from Assembler' do
      expect(R64::Base.superclass).to eq(R64::Assembler)
    end
  end
end
