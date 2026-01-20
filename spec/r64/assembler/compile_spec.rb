# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tempfile'

RSpec.describe R64::Assembler::Compile do
  let(:processor) { instance_double(R64::Processor, pc: 0x1000, start: 0x0801, set_pc: nil) }
  let(:memory) { instance_double(R64::Memory, start: 0x0801, finish: 0x2000) }
  let(:assembler) { R64::Assembler.new(processor: processor, memory: memory) }

  before do
    # Define main method on assembler since it's expected by compile methods
    assembler.define_singleton_method(:main) { }
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:open).and_yield(instance_double(File, write: nil, print: nil))
  end

  describe '#precompile' do
    it 'calls main method' do
      expect(assembler).to receive(:main)
      assembler.precompile
    end

    it 'sets processor PC to start position' do
      expect(processor).to receive(:set_pc).with(0x1000)
      assembler.precompile
    end

    it 'sets precompile to false' do
      assembler.precompile
      expect(assembler.instance_variable_get(:@precompile)).to be false
    end
  end

  describe '#compile!' do
    context 'with basic options' do
      it 'calls main method' do
        expect(assembler).to receive(:main)
        assembler.compile!
      end
    end

    context 'with save option' do
      before { allow(assembler).to receive(:save!) }

      it 'calls save! when save option is true' do
        expect(assembler).to receive(:save!).with({ save: true })
        assembler.compile!(save: true)
      end

      it 'calls save! when filename option is provided' do
        expect(assembler).to receive(:save!).with({ filename: 'test.prg' })
        assembler.compile!(filename: 'test.prg')
      end
    end

    context 'with debug option' do
      before { allow(assembler).to receive(:debug) }

      it 'calls debug when debug option is :debug' do
        expect(assembler).to receive(:debug)
        assembler.compile!(debug: :debug)
      end

      it 'calls debug when global $mode is :debug' do
        $mode = :debug
        expect(assembler).to receive(:debug)
        assembler.compile!
        $mode = nil
      end
    end
  end

  describe '#debug' do
    before do
      allow(assembler).to receive(:save_labels)
      allow(assembler).to receive(:save_watches)
      allow(assembler).to receive(:save_breakpoints)
    end

    it 'saves labels, watches, and breakpoints' do
      expect(assembler).to receive(:save_labels)
      expect(assembler).to receive(:save_watches)
      expect(assembler).to receive(:save_breakpoints)
      assembler.debug
    end
  end

  describe '#save_labels' do
    before do
      assembler.instance_variable_set(:@labels, { start: 0x1000, end: 0x2000 })
      allow(assembler).to receive(:filename).and_return('test')
      allow(assembler).to receive(:formatted_labels).and_return('start = $1000\nend = $2000')
    end

    it 'creates output directory' do
      expect(FileUtils).to receive(:mkdir_p).with('./output/meta/labels')
      assembler.save_labels
    end

    it 'writes formatted labels to file' do
      file_mock = instance_double(File)
      expect(File).to receive(:open).with("./output/meta/labels/#{assembler.filename}.labels", 'w').and_yield(file_mock)
      expect(file_mock).to receive(:write).with('start = $1000\nend = $2000')
      assembler.save_labels
    end
  end

  describe '#formatted_labels' do
    context 'with labels defined' do
      before do
        assembler.instance_variable_set(:@labels, { start: 0x1000, loop: 0x1010 })
      end

      it 'formats labels as hex strings' do
        result = assembler.formatted_labels
        expect(result).to include('start = $1000')
        expect(result).to include('loop = $1010')
      end
    end

    context 'with no labels' do
      it 'returns empty string' do
        result = assembler.formatted_labels
        expect(result).to eq('')
      end
    end
  end

  describe '#save_watches' do
    before do
      assembler.instance_variable_set(:@watchers, [
        { label: 'test_label', address: '1000' },
        { label: 'addr_2000', address: '2000' }
      ])
      allow(assembler).to receive(:filename).and_return('test')
    end

    it 'creates output directory' do
      expect(FileUtils).to receive(:mkdir_p).with('./output/meta/watches')
      assembler.save_watches
    end

    it 'writes watchers to file' do
      file_mock = instance_double(File)
      expect(File).to receive(:open).with("./output/meta/watches/#{assembler.filename}.watches", 'w').and_yield(file_mock)
      expect(file_mock).to receive(:write).with("test_label = $1000\naddr_2000 = $2000")
      assembler.save_watches
    end
  end

  describe '#save_breakpoints' do
    before do
      assembler.instance_variable_set(:@breakpoints, [
        { type: 'breakonpc', params: '1000' },
        { type: 'breakmem', params: '2000r' }
      ])
      allow(assembler).to receive(:filename).and_return('test')
    end

    it 'creates output directory' do
      expect(FileUtils).to receive(:mkdir_p).with('./output/meta/breakpoints')
      assembler.save_breakpoints
    end

    it 'writes breakpoints to file' do
      file_mock = instance_double(File)
      expect(File).to receive(:open).with("./output/meta/breakpoints/#{assembler.filename}.breakpoints", 'w').and_yield(file_mock)
      expect(file_mock).to receive(:write).with("breakonpc 1000\nbreakmem 2000r")
      assembler.save_breakpoints
    end
  end

  describe '#entrypoint' do
    it 'returns entrypoint from options' do
      assembler.instance_variable_set(:@options, { entrypoint: 0x1000 })
      expect(assembler.entrypoint).to eq(0x1000)
    end
  end

  describe '#set_entrypoint' do
    context 'during precompile with no entrypoint set' do
      before do
        assembler.instance_variable_set(:@precompile, true)
        assembler.instance_variable_set(:@options, {})
        allow($stdout).to receive(:puts)
      end

      it 'sets entrypoint to current processor PC' do
        assembler.set_entrypoint
        options = assembler.instance_variable_get(:@options)
        expect(options[:entrypoint]).to eq(0x1000)
      end

      it 'prints entrypoint message' do
        expect($stdout).to receive(:puts).with('Setting entrypoint to 1000')
        assembler.set_entrypoint
      end
    end

    context 'when entrypoint already set' do
      before do
        assembler.instance_variable_set(:@precompile, true)
        assembler.instance_variable_set(:@options, { entrypoint: 0x2000 })
      end

      it 'does not change existing entrypoint' do
        assembler.set_entrypoint
        options = assembler.instance_variable_get(:@options)
        expect(options[:entrypoint]).to eq(0x2000)
      end
    end

    context 'during compile phase' do
      before do
        assembler.instance_variable_set(:@precompile, false)
        assembler.instance_variable_set(:@options, {})
      end

      it 'does not set entrypoint' do
        assembler.set_entrypoint
        options = assembler.instance_variable_get(:@options)
        expect(options[:entrypoint]).to be_nil
      end
    end
  end

  describe '#filename' do
    it 'returns lowercase class name truncated to 15 characters' do
      # The actual implementation returns the first 15 characters of the lowercased class name
      expected = assembler.class.name.downcase[0..15]
      expect(assembler.filename).to eq(expected)
    end
  end

  describe '#save!' do
    before do
      allow(assembler).to receive(:hi_lo).with(0x0801).and_return({ lo: 0x01, hi: 0x08 })
      allow(assembler).to receive(:filename).and_return('test')
      allow($stdout).to receive(:puts)
    end

    it 'creates PRG file with start address header' do
      # Mock memory to return specific values for the range
      allow(memory).to receive(:[]).and_return(0x01) # Return 0x01 for all memory reads
      
      file_mock = instance_double(File)
      expect(File).to receive(:open).with('./output/test.prg', 'w').and_yield(file_mock)
      expect(file_mock).to receive(:print).with(0x01.chr) # low byte
      expect(file_mock).to receive(:print).with(0x08.chr) # high byte
      # Allow any number of print calls for memory contents
      allow(file_mock).to receive(:print)
      
      assembler.save!
    end

    it 'writes memory contents to file' do
      allow(memory).to receive(:[]).and_return(0x00) # Return 0x00 for all memory reads
      
      file_mock = instance_double(File)
      allow(File).to receive(:open).and_yield(file_mock)
      allow(file_mock).to receive(:print)
      
      expect(memory).to receive(:[]).at_least(:once)
      assembler.save!
    end

    context 'with custom options' do
      let(:options) { { start: 0x1000, end: 0x1100 } }

      it 'uses provided start and end addresses' do
        allow(assembler).to receive(:hi_lo).with(0x1000).and_return({ lo: 0x00, hi: 0x10 })
        allow(memory).to receive(:[]).and_return(0x00) # Return 0x00 for all memory reads
        
        file_mock = instance_double(File)
        expect(File).to receive(:open).and_yield(file_mock)
        expect(file_mock).to receive(:print).with(0x00.chr)
        expect(file_mock).to receive(:print).with(0x10.chr)
        # Allow any number of print calls for memory contents
        allow(file_mock).to receive(:print)
        
        assembler.save!(options)
      end
    end
  end
end
