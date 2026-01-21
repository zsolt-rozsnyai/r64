# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Base::Rendering do
  let(:test_class) do
    Class.new(R64::Base) do
      include R64::Base::Rendering

      def _test_method
        "test method executed"
      end

      def _inline_method
        "inline method executed"
      end

      def inline_methods
        [:_inline_method]
      end

      def variables
        "variables defined"
      end
    end
  end

  let(:processor) { instance_double(R64::Processor, pc: 0x1000, start: 0x0801, set_pc: nil) }
  let(:memory) { instance_double(R64::Memory, start: 0x0801, finish: 0x2000) }
  let(:parent) { instance_double(R64::Base, memory: memory, processor: processor, verbose: false) }
  let(:instance) { test_class.new(parent) }

  before do
    # Mock methods that rendering depends on
    allow(instance).to receive(:label)
    allow(instance).to receive(:rts)
    allow(instance).to receive(:run_before_compile)
    allow(instance).to receive(:run_after_compile)
    allow(instance).to receive(:verbose).and_return(false)
    allow($stdout).to receive(:puts)
  end


  describe '#main' do
    it 'calls to_binary' do
      expect(instance).to receive(:to_binary)
      instance.main
    end
  end

  describe '#to_binary' do
    before do
      allow(instance).to receive(:render_instance!)
    end

    it 'calls render_instance!' do
      expect(instance).to receive(:render_instance!)
      instance.to_binary
    end

    context 'with after hooks' do
      let(:after_class) do
        Class.new(R64::Base) do
          include R64::Base::Rendering
          after { @after_executed = true }
        end
      end

      let(:after_instance) { after_class.new(parent) }

      before do
        allow(after_instance).to receive(:render_instance!)
      end

      it 'executes after hooks' do
        after_instance.to_binary
        expect(after_instance.instance_variable_get(:@after_executed)).to be true
      end
    end
  end

  describe '#render_underscored_methods' do
    it 'renders non-inline underscored methods' do
      allow(instance).to receive(:underscored_methods).and_return([:_test_method, :_inline_method])
      
      expect(instance).to receive(:label).with(:_test_method)
      expect(instance).to receive(:_test_method)
      expect(instance).to receive(:rts)
      
      # Should not render inline method
      expect(instance).not_to receive(:label).with(:_inline_method)
      
      instance.send(:render_underscored_methods)
    end
  end

  describe '#render_variables' do
    context 'when variables method exists' do
      it 'calls variables method' do
        expect(instance).to receive(:variables)
        instance.send(:render_variables)
      end
    end

    context 'when variables method does not exist' do
      let(:no_vars_class) do
        Class.new(R64::Base) do
          include R64::Base::Rendering
        end
      end

      let(:no_vars_instance) { no_vars_class.new(parent) }

      it 'does not raise error' do
        expect { no_vars_instance.send(:render_variables) }.not_to raise_error
      end
    end
  end

  describe '#render_children' do
    before do
      # Create child objects
      child1 = instance_double("Child1", to_binary: nil)
      child2 = instance_double("Child2", to_binary: nil)
      child_array = [child1, child2]
      
      instance.instance_variable_set(:@_child1, child1)
      instance.instance_variable_set(:@_child_array, child_array)
      instance.instance_variable_set(:@regular_var, "not a child")
    end

    it 'calls to_binary on child objects with underscore prefix' do
      child1 = instance.instance_variable_get(:@_child1)
      child_array = instance.instance_variable_get(:@_child_array)
      
      expect(child1).to receive(:to_binary)
      child_array.each { |child| expect(child).to receive(:to_binary) }
      
      instance.send(:render_children)
    end

    it 'ignores regular instance variables' do
      # Should not try to call to_binary on string
      expect { instance.send(:render_children) }.not_to raise_error
    end
  end

  describe '#run_compile' do
    it 'executes compilation steps in order' do
      call_order = []
      
      allow(instance).to receive(:run_before_compile) { call_order << :before }
      allow(instance).to receive(:render_variables) { call_order << :variables }
      allow(instance).to receive(:render_underscored_methods) { call_order << :methods }
      allow(instance).to receive(:run_after_compile) { call_order << :after }
      
      instance.send(:run_compile)
      
      expect(call_order).to eq([:before, :variables, :methods, :after])
    end
  end

  describe '#render_instance!' do
    before do
      allow(instance).to receive(:run_compile)
      allow(instance).to receive(:render_children)
      allow(processor).to receive(:pc).and_return(0x1000, 0x1100)
    end

    it 'sets instance_start to current PC' do
      instance.send(:render_instance!)
      expect(instance.instance_variable_get(:@instance_start)).to eq(0x1000)
    end

    it 'sets precompile to false' do
      instance.send(:render_instance!)
      expect(instance.instance_variable_get(:@precompile)).to be false
    end

    it 'calls run_compile twice' do
      expect(instance).to receive(:run_compile).twice
      instance.send(:render_instance!)
    end

    it 'calls render_children' do
      expect(instance).to receive(:render_children)
      instance.send(:render_instance!)
    end

    it 'manages processor PC correctly' do
      expect(processor).to receive(:set_pc).twice # Called during render process
      instance.send(:render_instance!)
    end

    context 'with verbose output' do
      before do
        allow(instance).to receive(:verbose).and_return(true)
        allow(instance).to receive(:references_to_print).and_return({})
      end

      it 'prints debug information' do
        expect($stdout).to receive(:puts).with(/References for/)
        expect($stdout).to receive(:puts).with(/Location for/)
        instance.send(:render_instance!)
      end
    end
  end

  describe '#underscored_methods' do
    it 'returns sorted underscored methods' do
      allow(instance).to receive(:class_instance_methods).and_return([:_zebra, :_alpha, :regular_method])
      methods = instance.send(:underscored_methods)
      expect(methods).to eq([:_alpha, :_zebra])
    end

    it 'caches the result' do
      expect(instance).to receive(:class_instance_methods).once.and_return([:_test])
      instance.send(:underscored_methods)
      instance.send(:underscored_methods) # Second call should use cache
    end
  end

  describe '#references_to_print' do
    before do
      instance.instance_variable_set(:@references, {
        test_label: [0x1000, 0x2000],
        other_label: [0x3000]
      })
    end

    it 'converts references to hex strings' do
      result = instance.send(:references_to_print)
      expect(result).to eq({
        test_label: ["0x1000", "0x2000"],
        other_label: ["0x3000"]
      })
    end

    it 'handles nil references' do
      instance.instance_variable_set(:@references, nil)
      expect { instance.send(:references_to_print) }.not_to raise_error
    end
  end
end
