# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe R64::Memory do
  describe '#initialize' do
    context 'with default options' do
      subject(:memory) { described_class.new }

      it 'creates a new memory instance' do
        expect(memory).to be_a(R64::Memory)
      end

      it 'inherits from Array' do
        expect(memory).to be_a(Array)
      end

      it 'sets default start to 0' do
        expect(memory.start).to eq(0)
      end

      it 'sets default finish to 0xffff' do
        expect(memory.finish).to eq(0xffff)
      end
    end

    context 'with custom options' do
      let(:options) { { start: 0x1000, end: 0x2000 } }
      subject(:memory) { described_class.new(options) }

      it 'sets custom start address' do
        expect(memory.start).to eq(0x1000)
      end

      it 'sets custom finish address' do
        expect(memory.finish).to eq(0x2000)
      end
    end
  end

  describe '.with_caller' do
    let(:memory) { described_class.new }
    let(:caller_obj) { double('caller') }

    it 'sets thread-local caller context' do
      described_class.with_caller(caller_obj) do
        expect(Thread.current[:memory_caller]).to eq(caller_obj)
      end
    end

    it 'restores previous caller context after block' do
      old_caller = double('old_caller')
      Thread.current[:memory_caller] = old_caller

      described_class.with_caller(caller_obj) do
        # Inside block
      end

      expect(Thread.current[:memory_caller]).to eq(old_caller)
    end

    it 'restores context even if block raises exception' do
      old_caller = double('old_caller')
      Thread.current[:memory_caller] = old_caller

      expect do
        described_class.with_caller(caller_obj) do
          raise StandardError, 'test error'
        end
      end.to raise_error(StandardError)

      expect(Thread.current[:memory_caller]).to eq(old_caller)
    end
  end

  describe '#[]=' do
    let(:memory) { described_class.new }
    let(:owner) { double('owner', object_name: 'TestOwner') }

    before do
      Thread.current[:memory_caller] = owner
    end

    after do
      Thread.current[:memory_caller] = nil
    end

    context 'setting new memory location' do
      it 'stores value with owner information' do
        memory[0x1000] = 0x42
        expect(memory[0x1000]).to eq(0x42)
      end

      it 'stores owner information in memory entry' do
        memory[0x1000] = 0x42
        # Use Array's [] method to get raw entry
        entry = Array.instance_method(:[]).bind(memory).call(0x1000)
        expect(entry[:owner]).to eq(owner)
        expect(entry[:value]).to eq(0x42)
      end
    end

    context 'overwriting memory location with same owner' do
      before do
        memory[0x1000] = 0x42
      end

      it 'allows overwriting by same owner' do
        memory[0x1000] = 0x84
        expect(memory[0x1000]).to eq(0x84)
      end
    end

    context 'overwriting memory location with different owner' do
      let(:other_owner) { double('other_owner', object_name: 'OtherOwner') }

      before do
        memory[0x1000] = 0x42
        Thread.current[:memory_caller] = other_owner
      end

      it 'raises error when different owner tries to overwrite' do
        expect { memory[0x1000] = 0x84 }.to raise_error(/Memory location 4096.*is owned by TestOwner/)
      end
    end
  end

  describe '#[]' do
    let(:memory) { described_class.new }
    let(:owner) { double('owner') }

    before do
      Thread.current[:memory_caller] = owner
    end

    after do
      Thread.current[:memory_caller] = nil
    end

    context 'reading stored value' do
      before do
        memory[0x1000] = 0x42
      end

      it 'returns the stored value' do
        expect(memory[0x1000]).to eq(0x42)
      end
    end

    context 'reading uninitialized location' do
      it 'returns nil for uninitialized memory' do
        expect(memory[0x2000]).to be_nil
      end
    end

    context 'reading raw data' do
      before do
        # Directly set raw data using Array's []= method
        Array.instance_method(:[]=).bind(memory).call(0x1000, 'raw_data')
      end

      it 'returns raw data when not in hash format' do
        expect(memory[0x1000]).to eq('raw_data')
      end
    end
  end

  describe '#get_memory_entry' do
    let(:memory) { described_class.new }
    let(:owner) { double('owner') }

    before do
      Thread.current[:memory_caller] = owner
      memory[0x1000] = 0x42
    end

    after do
      Thread.current[:memory_caller] = nil
    end

    it 'returns the full memory entry hash' do
      # Use Array's [] method to get raw entry since get_memory_entry calls super
      entry = Array.instance_method(:[]).bind(memory).call(0x1000)
      expect(entry).to be_a(Hash)
      expect(entry[:value]).to eq(0x42)
      expect(entry[:owner]).to eq(owner)
    end
  end

  describe '#inspect' do
    let(:memory) { described_class.new }

    before do
      # Add some data to memory
      (0..15).each { |i| memory[i] = i }
    end

    it 'returns truncated representation' do
      # Call inspect using send to access the method
      result = memory.send(:inspect)
      expect(result).to be_a(Array)
      expect(result.last).to eq('...')
      expect(result.length).to eq(11) # 10 elements + '...'
    end
  end

  describe 'private methods' do
    let(:memory) { described_class.new }

    describe '#get_object_display_name' do
      context 'with object that responds to object_name' do
        let(:obj) { double('obj', object_name: 'TestObject') }

        it 'returns object_name' do
          result = memory.send(:get_object_display_name, obj)
          expect(result).to eq('TestObject')
        end
      end

      context 'with hash containing object_name' do
        let(:obj) { { object_name: 'HashObject', file: 'test.rb', line: 42 } }

        it 'returns formatted object name with file info' do
          result = memory.send(:get_object_display_name, obj)
          expect(result).to eq('HashObject (test.rb:42)')
        end
      end

      context 'with hash containing file info but no object_name' do
        let(:obj) { { file: 'test.rb', line: 42, method: 'test_method' } }

        it 'returns formatted file info' do
          result = memory.send(:get_object_display_name, obj)
          expect(result).to eq('test.rb:42 in test_method')
        end
      end

      context 'with other objects' do
        let(:obj) { 'simple_string' }

        it 'returns inspect result' do
          result = memory.send(:get_object_display_name, obj)
          expect(result).to eq('"simple_string"')
        end
      end
    end

    describe '#get_calling_object' do
      context 'with thread-local caller set' do
        let(:caller_obj) { double('caller') }

        before do
          Thread.current[:memory_caller] = caller_obj
        end

        after do
          Thread.current[:memory_caller] = nil
        end

        it 'returns the thread-local caller' do
          result = memory.send(:get_calling_object)
          expect(result).to eq(caller_obj)
        end
      end

      context 'without thread-local caller' do
        before do
          Thread.current[:memory_caller] = nil
        end

        it 'returns caller information hash' do
          result = memory.send(:get_calling_object)
          expect(result).to be_a(Hash)
          expect(result).to have_key(:file)
          expect(result).to have_key(:line)
          expect(result).to have_key(:method)
        end
      end
    end

    describe '#get_source_line' do
      context 'with valid file and line number' do
        let(:temp_file) do
          file = Tempfile.new('test_source')
          file.write("line 1\nline 2\nline 3\n")
          file.close
          file
        end

        after do
          temp_file.unlink
        end

        it 'returns the source line' do
          result = memory.send(:get_source_line, temp_file.path, 2)
          expect(result).to eq('line 2')
        end
      end

      context 'with non-existent file' do
        it 'returns unknown for non-existent file' do
          result = memory.send(:get_source_line, '/non/existent/file.rb', 1)
          expect(result).to eq('unknown')
        end
      end

      context 'with invalid line number' do
        let(:temp_file) do
          file = Tempfile.new('test_source')
          file.write("line 1\n")
          file.close
          file
        end

        after do
          temp_file.unlink
        end

        it 'returns invalid_line_number for out of range line' do
          result = memory.send(:get_source_line, temp_file.path, 10)
          expect(result).to eq('invalid_line_number')
        end
      end
    end
  end

  describe 'accessor methods' do
    let(:memory) { described_class.new }

    it 'allows reading and writing start' do
      memory.start = 0x2000
      expect(memory.start).to eq(0x2000)
    end

    it 'allows reading and writing finish' do
      memory.finish = 0x3000
      expect(memory.finish).to eq(0x3000)
    end
  end
end
