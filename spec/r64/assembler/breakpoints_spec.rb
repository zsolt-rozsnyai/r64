# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Assembler::Breakpoints do
  let(:processor) { instance_double(R64::Processor, pc: 0x1000) }
  let(:memory) { instance_double(R64::Memory) }
  let(:assembler) { R64::Assembler.new(processor: processor, memory: memory) }

  describe '#break_pc' do
    context 'during compile phase' do
      before { assembler.instance_variable_set(:@precompile, false) }

      it 'adds a PC breakpoint' do
        assembler.break_pc
        breakpoints = assembler.instance_variable_get(:@breakpoints)
        expect(breakpoints).to include({
          type: 'breakonpc',
          params: '1000'
        })
      end
    end

    context 'during precompile phase' do
      before { assembler.instance_variable_set(:@precompile, true) }

      it 'does not add breakpoint during precompile' do
        assembler.break_pc
        breakpoints = assembler.instance_variable_get(:@breakpoints)
        expect(breakpoints).to be_nil
      end
    end
  end

  describe '#break_mem' do
    context 'during compile phase' do
      before { assembler.instance_variable_set(:@precompile, false) }

      it 'adds a memory breakpoint with condition' do
        assembler.break_mem(0x2000, 'r')
        breakpoints = assembler.instance_variable_get(:@breakpoints)
        expect(breakpoints).to include({
          type: 'breakmem',
          params: '2000r'
        })
      end
    end

    context 'during precompile phase' do
      before { assembler.instance_variable_set(:@precompile, true) }

      it 'does not add breakpoint during precompile' do
        assembler.break_mem(0x2000, 'w')
        breakpoints = assembler.instance_variable_get(:@breakpoints)
        expect(breakpoints).to be_nil
      end
    end
  end

  describe '#break_raster' do
    context 'during compile phase' do
      before { assembler.instance_variable_set(:@precompile, false) }

      it 'adds a raster breakpoint' do
        assembler.break_raster(100)
        breakpoints = assembler.instance_variable_get(:@breakpoints)
        expect(breakpoints).to include({
          type: 'breakraster',
          params: 100
        })
      end
    end

    context 'during precompile phase' do
      before { assembler.instance_variable_set(:@precompile, true) }

      it 'does not add breakpoint during precompile' do
        assembler.break_raster(200)
        breakpoints = assembler.instance_variable_get(:@breakpoints)
        expect(breakpoints).to be_nil
      end
    end
  end

  describe '#add_breakpoint' do
    context 'during compile phase' do
      before { assembler.instance_variable_set(:@precompile, false) }

      it 'adds breakpoint to the list' do
        assembler.add_breakpoint('custom_type', 'custom_params')
        breakpoints = assembler.instance_variable_get(:@breakpoints)
        expect(breakpoints).to include({
          type: 'custom_type',
          params: 'custom_params'
        })
      end

      it 'initializes breakpoints array if not exists' do
        expect(assembler.instance_variable_get(:@breakpoints)).to be_nil
        assembler.add_breakpoint('test', 'params')
        expect(assembler.instance_variable_get(:@breakpoints)).to be_an(Array)
      end
    end

    context 'during precompile phase' do
      before { assembler.instance_variable_set(:@precompile, true) }

      it 'returns early without adding breakpoint' do
        assembler.add_breakpoint('test', 'params')
        breakpoints = assembler.instance_variable_get(:@breakpoints)
        expect(breakpoints).to be_nil
      end
    end
  end

  describe '#watch' do
    before do
      assembler.instance_variable_set(:@precompile, false)
      assembler.instance_variable_set(:@labels, { test_label: 0x3000 })
      allow(assembler).to receive(:processor).and_return(processor)
    end

    context 'with symbol argument' do
      it 'adds watcher with label information' do
        assembler.watch(:test_label)
        watchers = assembler.instance_variable_get(:@watchers)
        expect(watchers).to include({
          label: :test_label,
          address: '3000'
        })
      end
    end

    context 'with numeric argument' do
      it 'adds watcher with address information' do
        assembler.watch(0x4000)
        watchers = assembler.instance_variable_get(:@watchers)
        expect(watchers).to include({
          label: 'addr_4000',
          address: '4000'
        })
      end
    end

    context 'with no argument' do
      it 'uses processor PC as default' do
        assembler.watch
        watchers = assembler.instance_variable_get(:@watchers)
        expect(watchers).to include({
          label: 'addr_1000',
          address: '1000'
        })
      end
    end

    context 'during precompile phase' do
      before { assembler.instance_variable_set(:@precompile, true) }

      it 'returns early without adding watcher' do
        assembler.watch(:test_label)
        watchers = assembler.instance_variable_get(:@watchers)
        expect(watchers).to be_nil
      end
    end

    it 'initializes watchers array if not exists' do
      expect(assembler.instance_variable_get(:@watchers)).to be_nil
      assembler.watch(0x5000)
      expect(assembler.instance_variable_get(:@watchers)).to be_an(Array)
    end
  end
end
