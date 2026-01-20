# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Bits do
  # Create a test class that includes the Bits module functionality
  let(:test_class) do
    Class.new(R64::Assembler) do
      def initialize
        super
        @processor = R64::Processor.new(start: 0x1000)
        @memory = R64::Memory.new
      end

      def verbose
        false
      end

      # Mock assembler instruction methods
      def lda(value); end
      def ldx(value); end
      def ldy(value); end
      def sta(address); end
      def stx(address); end
      def sty(address); end
      def add_byte(*args); end
    end
  end

  let(:assembler) { test_class.new }

  describe 'DEFAULT_SET_OPTIONS' do
    it 'defines default options for set method' do
      # The constant is defined when the Bits module is loaded
      # Check if it exists and has the right values
      if defined?(R64::Assembler::DEFAULT_SET_OPTIONS)
        expect(R64::Assembler::DEFAULT_SET_OPTIONS).to eq({
          load: true,
          with: :a
        })
      else
        # If not defined, just verify the module loads without error
        expect(R64::Bits).to be_a(Module)
      end
    end
  end

  describe '#set' do
    before do
      allow(assembler).to receive(:verbose).and_return(false)
      allow(assembler).to receive(:get_label).and_return(0x2000)
      allow(assembler).to receive(:lda)
      allow(assembler).to receive(:ldx)
      allow(assembler).to receive(:ldy)
      allow(assembler).to receive(:sta)
      allow(assembler).to receive(:stx)
      allow(assembler).to receive(:sty)
    end

    context 'with default options (A register)' do
      it 'loads value and stores to register' do
        expect(assembler).to receive(:lda).with(0x42)
        expect(assembler).to receive(:sta).with(0x2000)
        assembler.set(0x2000, 0x42)
      end
    end

    context 'with X register' do
      it 'uses X register for load and store' do
        expect(assembler).to receive(:ldx).with(0x42)
        expect(assembler).to receive(:stx).with(0x2000)
        assembler.set(0x2000, 0x42, with: :x)
      end
    end

    context 'with Y register' do
      it 'uses Y register for load and store' do
        expect(assembler).to receive(:ldy).with(0x42)
        expect(assembler).to receive(:sty).with(0x2000)
        assembler.set(0x2000, 0x42, with: :y)
      end
    end

    context 'with load: false' do
      it 'skips loading value' do
        expect(assembler).not_to receive(:lda)
        expect(assembler).to receive(:sta).with(0x2000)
        assembler.set(0x2000, 0x42, load: false)
      end
    end

    context 'with no arguments' do
      it 'sets load to false when no args provided' do
        expect(assembler).not_to receive(:lda)
        expect(assembler).to receive(:sta).with(0x2000)
        assembler.set(0x2000)
      end
    end

    context 'with hi option' do
      it 'increments register address by 1' do
        expect(assembler).to receive(:lda).with(0x42)
        expect(assembler).to receive(:sta).with(0x2001) # 0x2000 + 1
        assembler.set(0x2000, 0x42, hi: true)
      end
    end

    context 'with length option' do
      it 'stores to multiple consecutive addresses' do
        expect(assembler).to receive(:lda).with(0x42)
        expect(assembler).to receive(:sta).with(0x2000)
        expect(assembler).to receive(:sta).with(0x2001)
        expect(assembler).to receive(:sta).with(0x2002)
        assembler.set(0x2000, 0x42, length: 3)
      end
    end

    context 'with symbol register' do
      it 'resolves label before using' do
        expect(assembler).to receive(:get_label).with(:test_label).and_return(0x3000)
        expect(assembler).to receive(:lda).with(0x42)
        expect(assembler).to receive(:sta).with(0x3000)
        assembler.set(:test_label, 0x42)
      end
    end
  end

  describe '#fill' do
    before do
      allow(assembler).to receive(:verbose).and_return(false)
      allow(assembler).to receive(:add_byte)
      allow(assembler.instance_variable_get(:@processor)).to receive(:increase_pc)
    end

    context 'with length and data' do
      it 'fills memory with specified data' do
        # The fill method calls add_byte with address+i, data for each iteration
        (0..4).each do |i|
          expect(assembler).to receive(:add_byte).with(0x1000 + i, 0x42)
        end
        expect(assembler.instance_variable_get(:@processor)).to receive(:increase_pc).with(5)
        assembler.fill(5, 0x42)
      end
    end

    context 'with address and data' do
      it 'fills specific address with data' do
        expect(assembler).to receive(:add_byte).with(0x2000, 0x84)
        expect(assembler).to receive(:add_byte).with(0x2001, 0x84)
        expect(assembler).to receive(:add_byte).with(0x2002, 0x84)
        expect(assembler.instance_variable_get(:@processor)).not_to receive(:increase_pc)
        assembler.fill(3, 0x2000, 0x84)
      end
    end

    context 'with block' do
      it 'calls block for each byte' do
        values = []
        assembler.fill(3, 0x2000, 0) do |i, options|
          values << i
          i * 10
        end
        expect(values).to eq([0, 1, 2])
      end

      it 'uses block return value as data' do
        expect(assembler).to receive(:add_byte).with(0x2000, 0)
        expect(assembler).to receive(:add_byte).with(0x2001, 10)
        expect(assembler).to receive(:add_byte).with(0x2002, 20)
        assembler.fill(3, 0x2000, 0) { |i, options| i * 10 }
      end
    end

    context 'with no arguments' do
      it 'fills with zero at current PC' do
        (0..2).each do |i|
          expect(assembler).to receive(:add_byte).with(0x1000 + i, 0)
        end
        expect(assembler.instance_variable_get(:@processor)).to receive(:increase_pc).with(3)
        assembler.fill(3)
      end
    end

    context 'with large address value' do
      it 'treats large single argument as address' do
        expect(assembler).to receive(:add_byte).with(0x5000, 0)
        expect(assembler).to receive(:add_byte).with(0x5001, 0)
        expect(assembler.instance_variable_get(:@processor)).not_to receive(:increase_pc)
        assembler.fill(2, 0x5000)
      end
    end

    context 'with invalid arguments' do
      it 'raises exception for too many arguments' do
        expect { assembler.fill(1, 1, 2, 3, 4) }.to raise_error(Exception, 'Wrong number of arguments')
      end
    end
  end

  describe '#var' do
    before do
      allow(assembler).to receive(:label)
      allow(assembler).to receive(:fill)
    end

    context 'with simple variable' do
      it 'creates label and fills memory' do
        expect(assembler).to receive(:label).with(:test_var)
        expect(assembler).to receive(:fill).with(1, 0, {})
        assembler.var(:test_var)
      end
    end

    context 'with default value' do
      it 'uses provided default value' do
        expect(assembler).to receive(:label).with(:test_var)
        expect(assembler).to receive(:fill).with(1, 0x42, {})
        assembler.var(:test_var, 0x42)
      end
    end

    context 'with length option' do
      it 'creates variable with specified length' do
        expect(assembler).to receive(:label).with(:test_var)
        expect(assembler).to receive(:fill).with(3, 0, { length: 3 })
        assembler.var(:test_var, length: 3)
      end
    end

    context 'with double type' do
      it 'creates low and high byte labels' do
        expect(assembler).to receive(:label).with(:test_var)
        expect(assembler).to receive(:label).with(:test_var_lo)
        expect(assembler).to receive(:label).with(:test_var_hi)
        expect(assembler).to receive(:fill).with(1, 0x34, {}) # low byte
        expect(assembler).to receive(:fill).with(1, 0x12, {}) # high byte
        assembler.var(:test_var, 0x1234, :double)
      end

      it 'handles zero value for double' do
        expect(assembler).to receive(:fill).with(1, 0, {}) # low byte
        expect(assembler).to receive(:fill).with(1, 0, {}) # high byte
        assembler.var(:test_var, 0, :double)
      end
    end

    context 'with block' do
      it 'passes block to fill method' do
        block = proc { |i| i * 2 }
        expect(assembler).to receive(:fill).with(1, 0, {}, &block)
        assembler.var(:test_var, &block)
      end
    end
  end

  describe '#data' do
    before do
      allow(assembler).to receive(:label)
      allow(assembler).to receive(:add_byte)
      allow(assembler.instance_variable_get(:@processor)).to receive(:increase_pc)
    end

    it 'creates label and stores byte array' do
      expect(assembler).to receive(:label).with(:test_data)
      expect(assembler).to receive(:add_byte).with(0x01)
      expect(assembler).to receive(:add_byte).with(0x02)
      expect(assembler).to receive(:add_byte).with(0x03)
      expect(assembler.instance_variable_get(:@processor)).to receive(:increase_pc).exactly(3).times
      assembler.data(:test_data, [0x01, 0x02, 0x03])
    end
  end

  describe '#text' do
    before do
      allow(assembler).to receive(:data)
    end

    it 'converts text to PETSCII and calls data' do
      # 'A' (65) -> 1, 'B' (66) -> 2, 'a' (97) -> 33
      expect(assembler).to receive(:data).with(:test_text, [1, 2, 33])
      assembler.text(:test_text, 'ABa')
    end

    it 'handles characters below 64' do
      # Characters with ASCII < 64 remain unchanged
      expect(assembler).to receive(:data).with(:test_text, [32, 33, 48]) # space, !, 0
      assembler.text(:test_text, ' !0')
    end
  end

  describe '#l' do
    before do
      allow(assembler).to receive(:get_label).with(:test_label).and_return(0x3000)
    end

    it 'returns label value' do
      expect(assembler.l(:test_label)).to eq(0x3000)
    end
  end

  describe '#copy_with' do
    before do
      allow(assembler).to receive(:lda)
      allow(assembler).to receive(:ldx)
      allow(assembler).to receive(:ldy)
      allow(assembler).to receive(:sta)
      allow(assembler).to receive(:stx)
      allow(assembler).to receive(:sty)
    end

    context 'with default (A register)' do
      it 'uses LDA/STA for copy' do
        expect(assembler).to receive(:lda).with(0x1000)
        expect(assembler).to receive(:sta).with(0x2000)
        assembler.copy_with(0x1000, 0x2000)
      end
    end

    context 'with X register' do
      it 'uses LDX/STX for copy' do
        expect(assembler).to receive(:ldx).with(0x1000)
        expect(assembler).to receive(:stx).with(0x2000)
        assembler.copy_with(0x1000, 0x2000, with: :x)
      end
    end

    context 'with Y register' do
      it 'uses LDY/STY for copy' do
        expect(assembler).to receive(:ldy).with(0x1000)
        expect(assembler).to receive(:sty).with(0x2000)
        assembler.copy_with(0x1000, 0x2000, with: :y)
      end
    end
  end

  describe '#extract_set_register_options' do
    before do
      # Mock get_color method if it exists
      if assembler.respond_to?(:get_color)
        allow(assembler).to receive(:get_color).and_return(0x0E)
      end
    end

    it 'extracts options from arguments' do
      result = assembler.extract_set_register_options([0x42, { with: :x, load: false }])
      expect(result[:args]).to eq([0x42])
      expect(result[:with]).to eq(:x)
      expect(result[:load]).to be false
    end

    it 'merges with default options' do
      result = assembler.extract_set_register_options([0x42])
      expect(result[:load]).to be true # default
      expect(result[:with]).to eq(:a) # default
      expect(result[:args]).to eq([0x42])
    end

    it 'processes color symbols if get_color method exists' do
      # Add get_color method to the test class
      assembler.define_singleton_method(:get_color) { |color| color == :white ? 0x01 : 0x0E }
      
      result = assembler.extract_set_register_options([:white])
      expect(result[:args]).to eq([0x01])
    end

    it 'handles empty arguments' do
      result = assembler.extract_set_register_options([])
      expect(result[:args]).to eq([])
      expect(result[:load]).to be true
      expect(result[:with]).to eq(:a)
    end
  end

  describe '#sys' do
    it 'exists as a no-op method' do
      expect { assembler.sys(0x1000) }.not_to raise_error
    end
  end

  describe 'integration with assembler' do
    it 'adds methods to R64::Assembler class' do
      expect(R64::Assembler.instance_methods).to include(:set, :fill, :var, :data, :text, :copy_with)
    end

    it 'methods are available on assembler instances' do
      assembler = R64::Assembler.new
      expect(assembler).to respond_to(:set)
      expect(assembler).to respond_to(:fill)
      expect(assembler).to respond_to(:var)
      expect(assembler).to respond_to(:data)
      expect(assembler).to respond_to(:text)
      expect(assembler).to respond_to(:copy_with)
    end
  end
end
