# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Assembler::Labels do
  let(:processor) { instance_double(R64::Processor, pc: 0x1000) }
  let(:memory) { instance_double(R64::Memory) }
  let(:assembler) { R64::Assembler.new(processor: processor, memory: memory) }

  describe '#get_label' do
    context 'during precompile phase' do
      before { assembler.instance_variable_set(:@precompile, true) }

      it 'returns placeholder value 12345' do
        expect(assembler.get_label(:test_label)).to eq(12345)
      end

      it 'adds reference to the label' do
        assembler.get_label(:test_label)
        references = assembler.instance_variable_get(:@references)
        expect(references[:test_label]).to include(0x1000)
      end

      it 'does not duplicate references for same PC' do
        assembler.get_label(:test_label)
        assembler.get_label(:test_label)
        references = assembler.instance_variable_get(:@references)
        expect(references[:test_label].count(0x1000)).to eq(1)
      end
    end

    context 'during compile phase' do
      before do
        assembler.instance_variable_set(:@precompile, false)
        assembler.instance_variable_set(:@labels, { test_label: 0x2000 })
      end

      it 'returns the actual label address' do
        expect(assembler.get_label(:test_label)).to eq(0x2000)
      end

      it 'raises exception for non-existent label' do
        expect { assembler.get_label(:missing_label) }.to raise_error(Exception, /Label does not exists/)
      end
    end
  end

  describe '#label' do
    context 'with default address' do
      it 'sets label to current processor PC' do
        assembler.label(:start)
        labels = assembler.instance_variable_get(:@labels)
        expect(labels[:start]).to eq(0x1000)
      end
    end

    context 'with specific address' do
      it 'sets label to provided address' do
        assembler.label(:custom, 0x3000)
        labels = assembler.instance_variable_get(:@labels)
        expect(labels[:custom]).to eq(0x3000)
      end
    end

    context 'with double address type' do
      it 'creates low and high byte labels' do
        # For double labels: data_lo gets current PC, data_hi gets PC + 1
        assembler.label(:data, :double)
        labels = assembler.instance_variable_get(:@labels)
        expect(labels[:data_lo]).to eq(0x1000)
        expect(labels[:data_hi]).to eq(0x1001)  # processor.pc + 1
      end
    end

    context 'during precompile with duplicate label' do
      before do
        assembler.instance_variable_set(:@precompile, true)
        assembler.label(:duplicate, 0x2000)
      end

      it 'raises exception for double definition' do
        expect { assembler.label(:duplicate, 0x3000) }.to raise_error(Exception, /Double definition of label/)
      end
    end

    context 'during compile phase' do
      before { assembler.instance_variable_set(:@precompile, false) }

      it 'allows overwriting existing labels' do
        assembler.label(:overwrite, 0x2000)
        assembler.label(:overwrite, 0x3000)
        labels = assembler.instance_variable_get(:@labels)
        expect(labels[:overwrite]).to eq(0x3000)
      end
    end
  end

  describe '#method_missing' do
    context 'when label exists' do
      before do
        assembler.instance_variable_set(:@labels, { existing_label: 0x4000 })
      end

      it 'returns the label value' do
        expect(assembler.existing_label).to eq(0x4000)
      end
    end

    context 'during precompile for non-existent label' do
      before { assembler.instance_variable_set(:@precompile, true) }

      it 'returns placeholder value 12345' do
        expect(assembler.non_existent_label).to eq(12345)
      end
    end

    context 'during compile for non-existent label' do
      before { assembler.instance_variable_set(:@precompile, false) }

      it 'calls super method' do
        expect { assembler.non_existent_method }.to raise_error(NoMethodError)
      end
    end
  end
end
