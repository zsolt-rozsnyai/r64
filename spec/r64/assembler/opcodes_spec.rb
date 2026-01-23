# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Assembler::Opcodes do
  let(:processor) { instance_double(R64::Processor, pc: 0x1000) }
  let(:memory) { instance_double(R64::Memory) }
  let(:assembler) { R64::Assembler.new(processor: processor, memory: memory) }

  describe 'ADDRESSES constant' do
    it 'defines NMI vector address' do
      expect(R64::Assembler::Opcodes::ADDRESSES[:nmi]).to eq(0xfffa)
    end

    it 'defines IRQ vector address' do
      expect(R64::Assembler::Opcodes::ADDRESSES[:irq]).to eq(0xfffe)
    end
  end

  describe 'OPCODES constant' do
    it 'is defined as a hash' do
      expect(R64::Assembler::Opcodes::OPCODES).to be_a(Hash)
    end

    describe 'ORA instruction' do
      let(:ora_opcodes) { R64::Assembler::Opcodes::OPCODES[:ora] }

      it 'defines immediate addressing mode' do
        expect(ora_opcodes[:imm]).to eq({ code: 0x09, length: 2, cycles: 2 })
      end

      it 'defines zero page addressing mode' do
        expect(ora_opcodes[:zp]).to eq({ code: 0x05, length: 2, cycles: 3 })
      end

      it 'defines zero page X addressing mode' do
        expect(ora_opcodes[:zpx]).to eq({ code: 0x15, length: 2, cycles: 4 })
      end

      it 'defines indexed indirect addressing mode' do
        expect(ora_opcodes[:izx]).to eq({ code: 0x01, length: 3, cycles: 3 })
      end

      it 'defines indirect indexed addressing mode' do
        expect(ora_opcodes[:izy]).to eq({ code: 0x11, length: 3, cycles: 3 })
      end

      it 'defines absolute addressing mode' do
        expect(ora_opcodes[:abs]).to eq({ code: 0x0d, length: 3, cycles: 3 })
      end

      it 'defines absolute X addressing mode' do
        expect(ora_opcodes[:abx]).to eq({ code: 0x1d, length: 3, cycles: 3 })
      end

      it 'defines absolute Y addressing mode' do
        expect(ora_opcodes[:aby]).to eq({ code: 0x19, length: 3, cycles: 3 })
      end
    end

    describe 'ANA (AND) instruction' do
      let(:ana_opcodes) { R64::Assembler::Opcodes::OPCODES[:ana] }

      it 'defines immediate addressing mode' do
        expect(ana_opcodes[:imm]).to eq({ code: 0x29, length: 2, cycles: 2 })
      end

      it 'defines zero page addressing mode' do
        expect(ana_opcodes[:zp]).to eq({ code: 0x25, length: 2, cycles: 3 })
      end

      it 'defines absolute addressing mode' do
        expect(ana_opcodes[:abs]).to eq({ code: 0x2d, length: 3, cycles: 3 })
      end
    end

    describe 'EOR instruction' do
      let(:eor_opcodes) { R64::Assembler::Opcodes::OPCODES[:eor] }

      it 'defines immediate addressing mode' do
        expect(eor_opcodes[:imm]).to eq({ code: 0x49, length: 2, cycles: 2 })
      end

      it 'defines zero page addressing mode' do
        expect(eor_opcodes[:zp]).to eq({ code: 0x45, length: 2, cycles: 3 })
      end

      it 'defines absolute addressing mode' do
        expect(eor_opcodes[:abs]).to eq({ code: 0x4d, length: 3, cycles: 3 })
      end
    end

    describe 'ADC instruction' do
      let(:adc_opcodes) { R64::Assembler::Opcodes::OPCODES[:adc] }

      it 'defines immediate addressing mode' do
        expect(adc_opcodes[:imm]).to eq({ code: 0x69, length: 2, cycles: 2 })
      end

      it 'defines zero page addressing mode' do
        expect(adc_opcodes[:zp]).to eq({ code: 0x65, length: 2, cycles: 3 })
      end

      it 'defines absolute addressing mode' do
        expect(adc_opcodes[:abs]).to eq({ code: 0x6d, length: 3, cycles: 3 })
      end
    end

    it 'contains multiple instruction types' do
      opcodes = R64::Assembler::Opcodes::OPCODES
      expect(opcodes.keys).to include(:ora, :ana, :eor, :adc)
    end

    it 'all opcodes have consistent structure' do
      R64::Assembler::Opcodes::OPCODES.each do |instruction, modes|
        expect(modes).to be_a(Hash)
        modes.each do |mode, details|
          expect(details).to have_key(:code)
          expect(details).to have_key(:length)
          expect(details).to have_key(:cycles)
          expect(details[:code]).to be_a(Integer)
          expect(details[:length]).to be_a(Integer)
          expect(details[:cycles]).to be_a(Integer)
        end
      end
    end

    it 'has unique opcodes for each instruction/mode combination' do
      all_codes = []
      R64::Assembler::Opcodes::OPCODES.each do |instruction, modes|
        modes.each do |mode, details|
          all_codes << details[:code]
        end
      end
      expect(all_codes.uniq.length).to eq(all_codes.length)
    end
  end

  describe 'opcode validation' do
    it 'all opcodes are within valid 6502 range (0x00-0xFF)' do
      R64::Assembler::Opcodes::OPCODES.each do |instruction, modes|
        modes.each do |mode, details|
          expect(details[:code]).to be >= 0x00
          expect(details[:code]).to be <= 0xFF
        end
      end
    end

    it 'all instruction lengths are reasonable (1-3 bytes)' do
      R64::Assembler::Opcodes::OPCODES.each do |instruction, modes|
        modes.each do |mode, details|
          expect(details[:length]).to be >= 1
          expect(details[:length]).to be <= 3
        end
      end
    end

    it 'all cycle counts are reasonable (1-7 cycles)' do
      R64::Assembler::Opcodes::OPCODES.each do |instruction, modes|
        modes.each do |mode, details|
          expect(details[:cycles]).to be >= 1
          expect(details[:cycles]).to be <= 7
        end
      end
    end
  end

  describe 'addressing mode consistency' do
    let(:common_modes) { [:imm, :zp, :zpx, :abs, :abx, :aby, :izx, :izy] }

    it 'immediate mode instructions are 2 bytes long' do
      R64::Assembler::Opcodes::OPCODES.each do |instruction, modes|
        if modes[:imm]
          expect(modes[:imm][:length]).to eq(2)
        end
      end
    end

    it 'zero page instructions are 2 bytes long' do
      R64::Assembler::Opcodes::OPCODES.each do |instruction, modes|
        if modes[:zp]
          expect(modes[:zp][:length]).to eq(2)
        end
      end
    end

    it 'absolute mode instructions are 3 bytes long' do
      R64::Assembler::Opcodes::OPCODES.each do |instruction, modes|
        if modes[:abs]
          expect(modes[:abs][:length]).to eq(3)
        end
      end
    end
  end

  describe '#extract_address' do
    let(:assembler) do
      R64::Assembler.new(processor: processor, memory: memory).tap do |asm|
        # Set up some test labels
        asm.instance_variable_set(:@labels, {
          test_label: 0x42,
          high_label: 0x1234
        })
        asm.instance_variable_set(:@precompile, false)
      end
    end

    context 'with single argument' do
      context 'when zeropage: true is explicitly set' do
        it 'forces zero page addressing regardless of address value' do
          # Test with high address value but zeropage: true
          options = { args: [0x1234], zeropage: true }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:zp)
          expect(result[:address]).to eq(0x1234)
        end

        it 'forces zero page addressing with placeholder values during precompilation' do
          assembler.instance_variable_set(:@precompile, true)
          
          # Test with symbol that resolves to placeholder
          options = { args: [:unknown_label], zeropage: true }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:zp)
          expect(result[:address]).to eq(12345) # placeholder value
        end

        it 'forces zero page addressing with low address values' do
          options = { args: [0x42], zeropage: true }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:zp)
          expect(result[:address]).to eq(0x42)
        end
      end

      context 'when zeropage: true is not set' do
        it 'uses immediate addressing for values < 256' do
          options = { args: [0x42] }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:imm)
          expect(result[:address]).to eq(0x42)
        end

        it 'uses absolute addressing for values >= 256' do
          options = { args: [0x1234] }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:abs)
          expect(result[:address]).to eq(0x1234)
        end

        it 'uses indirect addressing when indirect: true' do
          options = { args: [0x1234], indirect: true }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:ind)
          expect(result[:address]).to eq(0x1234)
        end
      end

      context 'with label resolution' do
        it 'resolves symbols to label addresses' do
          options = { args: [:test_label] }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:imm) # 0x42 < 256
          expect(result[:address]).to eq(0x42)
        end

        it 'resolves high address labels to absolute addressing' do
          options = { args: [:high_label] }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:abs) # 0x1234 >= 256
          expect(result[:address]).to eq(0x1234)
        end
      end
    end

    context 'with two arguments (indexed addressing)' do
      context 'when zeropage: true is explicitly set' do
        it 'forces zero page X addressing regardless of address value' do
          options = { args: [0x1234, :x], zeropage: true }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:zpx)
          expect(result[:address]).to eq(0x1234)
        end

        it 'forces zero page Y addressing regardless of address value' do
          options = { args: [0x1234, :y], zeropage: true }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:zpy)
          expect(result[:address]).to eq(0x1234)
        end

        it 'forces indirect zero page X addressing when indirect: true' do
          options = { args: [0x1234, :x], zeropage: true, indirect: true }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:izx)
          expect(result[:address]).to eq(0x1234)
        end

        it 'forces indirect zero page Y addressing when indirect: true' do
          options = { args: [0x1234, :y], zeropage: true, indirect: true }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:izy)
          expect(result[:address]).to eq(0x1234)
        end
      end

      context 'when zeropage: true is not set' do
        it 'uses zero page X for low addresses' do
          options = { args: [0x42, :x] }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:zpx)
          expect(result[:address]).to eq(0x42)
        end

        it 'uses absolute X for high addresses' do
          options = { args: [0x1234, :x] }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:abx)
          expect(result[:address]).to eq(0x1234)
        end

        it 'uses absolute Y for high addresses' do
          options = { args: [0x1234, :y] }
          result = assembler.send(:extract_address, options)
          
          expect(result[:type]).to eq(:aby)
          expect(result[:address]).to eq(0x1234)
        end
      end
    end

    context 'consistency between compilation passes' do
      it 'produces same addressing mode in both passes when zeropage: true' do
        # First pass (precompilation)
        assembler.instance_variable_set(:@precompile, true)
        options1 = { args: [:unknown_label], zeropage: true }
        result1 = assembler.send(:extract_address, options1)
        
        # Second pass (final compilation)
        assembler.instance_variable_set(:@precompile, false)
        assembler.instance_variable_get(:@labels)[:unknown_label] = 0x1234
        options2 = { args: [:unknown_label], zeropage: true }
        result2 = assembler.send(:extract_address, options2)
        
        expect(result1[:type]).to eq(result2[:type])
        expect(result1[:type]).to eq(:zp)
      end

      it 'produces same indexed addressing mode in both passes when zeropage: true' do
        # First pass (precompilation)
        assembler.instance_variable_set(:@precompile, true)
        options1 = { args: [:unknown_label, :x], zeropage: true }
        result1 = assembler.send(:extract_address, options1)
        
        # Second pass (final compilation)
        assembler.instance_variable_set(:@precompile, false)
        assembler.instance_variable_get(:@labels)[:unknown_label] = 0x1234
        options2 = { args: [:unknown_label, :x], zeropage: true }
        result2 = assembler.send(:extract_address, options2)
        
        expect(result1[:type]).to eq(result2[:type])
        expect(result1[:type]).to eq(:zpx)
      end
    end

    context 'edge cases' do
      it 'handles zero address with zeropage: true' do
        options = { args: [0x00], zeropage: true }
        result = assembler.send(:extract_address, options)
        
        expect(result[:type]).to eq(:zp)
        expect(result[:address]).to eq(0x00)
      end

      it 'handles maximum 16-bit address with zeropage: true' do
        options = { args: [0xFFFF], zeropage: true }
        result = assembler.send(:extract_address, options)
        
        expect(result[:type]).to eq(:zp)
        expect(result[:address]).to eq(0xFFFF)
      end

      it 'preserves other options when forcing zeropage' do
        options = { args: [0x1234], zeropage: true, custom_option: 'test' }
        result = assembler.send(:extract_address, options)
        
        expect(result[:type]).to eq(:zp)
        expect(result[:custom_option]).to eq('test')
      end
    end
  end
end
