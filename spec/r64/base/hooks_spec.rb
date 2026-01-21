# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Base::Hooks do
  let(:test_class) do
    Class.new(R64::Base) do
      include R64::Base::Hooks
    end
  end

  describe 'ClassMethods' do
    describe '#instance_count' do
      it 'initializes to 0' do
        expect(test_class.instance_count).to eq(0)
      end

      it 'can be set and retrieved' do
        test_class.instance_count = 5
        expect(test_class.instance_count).to eq(5)
      end
    end

    describe '#before' do
      context 'without block' do
        it 'returns empty array initially' do
          expect(test_class.before).to eq([])
        end
      end

      context 'with block' do
        it 'adds block to before hooks' do
          block = proc { puts "before" }
          test_class.before(&block)
          expect(test_class.before).to include(block)
        end
      end
    end

    describe '#after' do
      context 'without block' do
        it 'returns empty array initially' do
          expect(test_class.after).to eq([])
        end
      end

      context 'with block' do
        it 'adds block to after hooks' do
          block = proc { puts "after" }
          test_class.after(&block)
          expect(test_class.after).to include(block)
        end
      end
    end

    describe '#before_compile' do
      context 'without block' do
        it 'returns empty array initially' do
          expect(test_class.before_compile).to eq([])
        end
      end

      context 'with block' do
        it 'adds block to before_compile hooks' do
          block = proc { puts "before compile" }
          test_class.before_compile(&block)
          expect(test_class.before_compile).to include(block)
        end
      end
    end

    describe '#after_compile' do
      context 'without block' do
        it 'returns empty array initially' do
          expect(test_class.after_compile).to eq([])
        end
      end

      context 'with block' do
        it 'adds block to after_compile hooks' do
          block = proc { puts "after compile" }
          test_class.after_compile(&block)
          expect(test_class.after_compile).to include(block)
        end
      end
    end
  end

  describe 'instance methods' do
    let(:processor) { instance_double(R64::Processor, pc: 0x1000, start: 0x0801, set_pc: nil) }
    let(:memory) { instance_double(R64::Memory, start: 0x0801, finish: 0x2000) }
    let(:parent) { instance_double(R64::Base, memory: memory, processor: processor, verbose: false) }
    let(:instance) { test_class.new(parent) }

    describe '#run_before_compile' do
      context 'with before_compile hooks' do
        it 'executes all before_compile blocks' do
          executed = []
          test_class.before_compile { executed << :first }
          test_class.before_compile { executed << :second }
          
          instance.send(:run_before_compile)
          expect(executed).to eq([:first, :second])
        end
      end

      context 'without before_compile hooks' do
        it 'executes without error' do
          expect { instance.send(:run_before_compile) }.not_to raise_error
        end
      end
    end

    describe '#run_after_compile' do
      context 'with after_compile hooks' do
        it 'executes all after_compile blocks' do
          executed = []
          test_class.after_compile { executed << :first }
          test_class.after_compile { executed << :second }
          
          instance.send(:run_after_compile)
          expect(executed).to eq([:first, :second])
        end
      end

      context 'without after_compile hooks' do
        it 'executes without error' do
          expect { instance.send(:run_after_compile) }.not_to raise_error
        end
      end
    end
  end

  describe 'module inclusion' do
    it 'extends class with ClassMethods when included' do
      expect(test_class).to respond_to(:instance_count)
      expect(test_class).to respond_to(:before)
      expect(test_class).to respond_to(:after)
      expect(test_class).to respond_to(:before_compile)
      expect(test_class).to respond_to(:after_compile)
    end
  end
end
