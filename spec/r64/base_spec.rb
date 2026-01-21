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

  describe 'documentation example: MyScreen class' do
    # Test the example from base.rb:27
    let(:my_screen_class) do
      Class.new(R64::Base) do
        def _set_background_color
          lda 0x01
          sta 0xd020
        end
      end
    end

    let(:screen) { my_screen_class.new }

    before do
      # Mock the assembler methods that would be called
      allow(screen).to receive(:lda)
      allow(screen).to receive(:sta)
      allow(screen).to receive(:jsr)
      allow(screen).to receive(:label)
      allow(screen).to receive(:rts)
      allow(screen).to receive(:set_entrypoint)
      
      # Mock processor and memory for setup
      allow(screen).to receive(:processor).and_return(processor)
      allow(screen).to receive(:memory).and_return(memory)
    end

    describe 'class definition' do
      it 'inherits from R64::Base' do
        expect(screen).to be_a(R64::Base)
      end

      it 'defines the _set_background_color method' do
        expect(screen).to respond_to(:_set_background_color)
      end

      it 'responds to set_background_color via method dispatch' do
        expect(screen).to respond_to(:set_background_color)
      end
    end

    describe 'setup method' do
      it 'configures memory and processor with start and end addresses' do
        expect(processor).to receive(:set_pc).with(0x2000)
        expect(processor).to receive(:start=).with(0x2000)
        expect(memory).to receive(:start=).with(0x2000)
        expect(memory).to receive(:finish=).with(0x3000)
        expect(screen).to receive(:set_entrypoint)

        screen.setup(start: 0x2000, end: 0x3000)
      end
    end

    describe 'method dispatch' do
      it 'calls _set_background_color as a subroutine when called without :inline' do
        expect(screen).to receive(:jsr).with(:_set_background_color)
        
        screen.set_background_color
      end

      it 'calls _set_background_color inline when :inline argument is passed' do
        expect(screen).to receive(:_set_background_color)
        expect(screen).not_to receive(:jsr)
        
        screen.set_background_color(:inline)
      end
    end

    describe '_set_background_color method' do
      it 'executes the expected assembly instructions' do
        expect(screen).to receive(:lda).with(0x01)
        expect(screen).to receive(:sta).with(0xd020)
        
        screen._set_background_color
      end
    end

    describe 'binary generation' do
      before do
        # Mock the rendering process
        allow(screen).to receive(:render_instance!)
        allow(screen.class).to receive(:after).and_return([])
      end

      it 'generates binary output' do
        expect(screen).to receive(:render_instance!)
        
        result = screen.to_binary
        expect(result).not_to be_nil
      end

      it 'calls render_instance! during to_binary' do
        expect(screen).to receive(:render_instance!)
        
        screen.to_binary
      end
    end

    describe 'complete example workflow' do
      it 'executes the full example workflow without errors' do
        # Setup
        expect(processor).to receive(:set_pc).with(0x2000)
        expect(processor).to receive(:start=).with(0x2000)
        expect(memory).to receive(:start=).with(0x2000)
        expect(memory).to receive(:finish=).with(0x3000)
        expect(screen).to receive(:set_entrypoint)
        
        screen.setup(start: 0x2000, end: 0x3000)

        # Method dispatch
        expect(screen).to receive(:jsr).with(:_set_background_color)
        screen.set_background_color

        # Binary generation
        expect(screen).to receive(:render_instance!)
        binary = screen.to_binary
        
        expect(binary).not_to be_nil
      end
    end
  end
end
