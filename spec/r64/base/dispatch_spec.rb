# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Base::Dispatch do
  let(:test_class) do
    Class.new(R64::Base) do
      include R64::Base::Dispatch

      def _test_method
        "test method called"
      end

      def _inline_method
        "inline method called"
      end

      def inline_methods
        [:_inline_method]
      end
    end
  end

  let(:processor) { instance_double(R64::Processor, pc: 0x1000, start: 0x0801, set_pc: nil) }
  let(:memory) { instance_double(R64::Memory, start: 0x0801, finish: 0x2000) }
  let(:parent) { instance_double(R64::Base, memory: memory, processor: processor, verbose: false) }
  let(:instance) { test_class.new(parent) }

  describe '#method_missing' do
    context 'when underscored method exists' do
      before do
        allow(instance).to receive(:jsr)
      end

      it 'calls jsr for non-inline methods' do
        expect(instance).to receive(:jsr).with(:_test_method)
        instance.test_method
      end

      context 'with inline argument' do
        it 'calls method directly when :inline is passed' do
          expect(instance).to receive(:_test_method).and_return("direct call")
          result = instance.test_method(:inline)
          expect(result).to eq("direct call")
        end
      end

      context 'with inline_methods defined' do
        it 'calls method directly for inline methods' do
          expect(instance).to receive(:_inline_method).and_return("inline call")
          result = instance.inline_method
          expect(result).to eq("inline call")
        end
      end
    end

    context 'when underscored method does not exist' do
      it 'does not handle unknown methods through dispatch' do
        # Verify that unknown methods are not in our class instance methods
        expect(instance.send(:class_instance_methods)).not_to include(:_unknown_method)
        # The method will be handled by the assembler's method_missing or raise NoMethodError
        expect(instance.respond_to?(:unknown_method)).to be false
      end
    end
  end

  describe '#respond_to_missing?' do
    context 'when underscored method exists' do
      it 'returns true for methods with underscored equivalents' do
        expect(instance.respond_to?(:test_method)).to be true
      end

      it 'returns true for inline methods' do
        expect(instance.respond_to?(:inline_method)).to be true
      end
    end

    context 'when underscored method does not exist' do
      it 'returns false for methods without underscored equivalents' do
        expect(instance.respond_to?(:unknown_method)).to be false
      end
    end

    context 'with include_private parameter' do
      it 'passes include_private to super when method not found' do
        expect(instance.respond_to?(:unknown_method, true)).to be false
      end
    end
  end

  describe '#class_instance_methods' do
    it 'returns array of instance methods' do
      methods = instance.send(:class_instance_methods)
      expect(methods).to be_an(Array)
      expect(methods).to include(:_test_method, :_inline_method)
    end

    it 'includes methods from inheritance chain' do
      child_class = Class.new(test_class) do
        def _child_method
          "child method"
        end
      end

      child_instance = child_class.new(parent)
      methods = child_instance.send(:class_instance_methods)
      expect(methods).to include(:_test_method, :_child_method)
    end

    it 'stops traversal at R64::Base' do
      methods = instance.send(:class_instance_methods)
      # Should not include methods from classes above R64::Base
      expect(methods).not_to include(:class, :object_id)
    end

    it 'returns unique methods' do
      methods = instance.send(:class_instance_methods)
      expect(methods.uniq).to eq(methods)
    end
  end

  describe 'integration with method dispatch' do
    let(:enhanced_class) do
      Class.new(R64::Base) do
        include R64::Base::Dispatch

        def _setup_screen
          "setting up screen"
        end

        def _draw_sprite
          "drawing sprite"
        end

        def inline_methods
          [:_draw_sprite]
        end
      end
    end

    let(:enhanced_instance) { enhanced_class.new(parent) }

    before do
      allow(enhanced_instance).to receive(:jsr)
    end

    it 'dispatches to jsr for regular methods' do
      expect(enhanced_instance).to receive(:jsr).with(:_setup_screen)
      enhanced_instance.setup_screen
    end

    it 'calls directly for inline methods' do
      expect(enhanced_instance).to receive(:_draw_sprite).and_return("sprite drawn")
      result = enhanced_instance.draw_sprite
      expect(result).to eq("sprite drawn")
    end

    it 'handles method existence checks correctly' do
      expect(enhanced_instance.respond_to?(:setup_screen)).to be true
      expect(enhanced_instance.respond_to?(:draw_sprite)).to be true
      expect(enhanced_instance.respond_to?(:nonexistent_method)).to be false
    end
  end
end
