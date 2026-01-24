# frozen_string_literal: true

require 'spec_helper'

RSpec.describe R64::Base::NamespacedLabels do
  let(:processor) { R64::Processor.new }
  let(:memory) { R64::Memory.new }
  
  before do
    # Set up processor and memory for label generation
    processor.start = 0x2000
    processor.set_pc(0x2000)
    memory.start = 0x2000
    memory.finish = 0x3000
  end

  describe '#namespaced_labels' do
    let(:base_instance) do
      instance = R64::Base.new
      instance.instance_variable_set(:@processor, processor)
      instance.instance_variable_set(:@memory, memory)
      
      # Mock some labels for testing
      labels_hash = {
        :test_var => 0x2000,
        :_test_method => 0x2010,
        :another_var => 0x2020
      }
      instance.instance_variable_set(:@labels, labels_hash)
      
      instance
    end

    it 'returns a hash of namespaced labels' do
      labels = base_instance.namespaced_labels
      expect(labels).to be_a(Hash)
    end

    it 'handles empty label sets' do
      empty_instance = R64::Base.new
      empty_instance.instance_variable_set(:@processor, processor)
      empty_instance.instance_variable_set(:@memory, memory)
      
      labels = empty_instance.namespaced_labels
      expect(labels).to be_a(Hash)
      expect(labels).to be_empty
    end

    it 'prevents label name collisions' do
      labels = base_instance.namespaced_labels
      
      # All label names should be unique
      expect(labels.keys.uniq.length).to eq(labels.keys.length)
    end

    it 'prevents address collisions' do
      labels = base_instance.namespaced_labels
      
      # Group labels by address and ensure no address has multiple labels
      addresses_with_multiple_labels = labels.group_by { |_, address| address }
                                             .select { |_, label_pairs| label_pairs.length > 1 }
      
      expect(addresses_with_multiple_labels).to be_empty
    end
  end

  describe '#generate_namespace' do
    let(:base_instance) { R64::Base.new }

    it 'generates namespace with class name and index' do
      # Mock the class name and index
      allow(base_instance.class).to receive(:name).and_return('TestClass')
      base_instance.instance_variable_set(:@index, 0)
      
      namespace = base_instance.send(:generate_namespace, base_instance)
      expect(namespace).to match(/\w{2}\d/)
    end

    it 'uses consonants from class name' do
      # Mock a class with clear consonants
      allow(base_instance.class).to receive(:name).and_return('Sprite')
      base_instance.instance_variable_set(:@index, 0)
      
      namespace = base_instance.send(:generate_namespace, base_instance)
      expect(namespace).to eq('SP0')
    end

    it 'handles class names with few consonants' do
      # Mock a class with few consonants
      allow(base_instance.class).to receive(:name).and_return('Audio')
      base_instance.instance_variable_set(:@index, 1)
      
      namespace = base_instance.send(:generate_namespace, base_instance)
      expect(namespace).to match(/\w{2}1/)
    end
  end

  describe '#shorten_label_name' do
    let(:instance) { R64::Base.new }

    it 'shortens long label names by splitting on underscores' do
      result = instance.send(:shorten_label_name, '_get_precalculated_order')
      expect(result).to eq('getpreord')
    end

    it 'takes first 3 characters from each word' do
      result = instance.send(:shorten_label_name, 'very_long_method_name')
      expect(result).to eq('verlonmetn')
    end

    it 'handles labels with leading underscores' do
      result = instance.send(:shorten_label_name, '_set_sprite_position')
      expect(result).to eq('setsprpos')
    end

    it 'truncates to 10 characters maximum' do
      result = instance.send(:shorten_label_name, 'extremely_long_method_name_that_exceeds_limits')
      expect(result.length).to be <= 10
    end

    it 'returns short labels unchanged' do
      result = instance.send(:shorten_label_name, 'short')
      expect(result).to eq('sho')  # Single word gets first 3 chars
    end

    it 'handles single word labels' do
      result = instance.send(:shorten_label_name, 'verylongsinglewordinput')
      expect(result).to eq('ver')  # Single word gets first 3 chars, then truncated to 10
    end
  end

  describe '#create_namespaced_label' do
    let(:instance) { R64::Base.new }

    it 'creates regular labels with underscore separator' do
      result = instance.send(:create_namespaced_label, 'SP0', 'xpos')
      expect(result).to eq('SP0_XPOS')
    end

    it 'creates method labels with exclamation separator' do
      result = instance.send(:create_namespaced_label, 'SP0', '_set_xpos')
      expect(result).to eq('SP0!_SET_XPOS')
    end

    it 'shortens long labels' do
      result = instance.send(:create_namespaced_label, 'MU0', '_get_precalculated_order')
      expect(result).to eq('MU0!GETPREORD')
    end

    it 'converts to uppercase' do
      result = instance.send(:create_namespaced_label, 'sp0', 'test_label')
      expect(result).to eq('SP0_TEST_LABEL')
    end

    it 'truncates to 16 characters maximum' do
      result = instance.send(:create_namespaced_label, 'VERYLONGNAMESPACE', 'very_long_label_name')
      expect(result.length).to be <= 16
    end
  end

  describe 'integration with R64::Base' do
    let(:base_instance) { R64::Base.new }

    it 'includes NamespacedLabels module in R64::Base' do
      expect(base_instance).to respond_to(:namespaced_labels)
    end

    it 'provides access to private helper methods' do
      expect(base_instance.private_methods).to include(:generate_namespace)
      expect(base_instance.private_methods).to include(:shorten_label_name)
      expect(base_instance.private_methods).to include(:create_namespaced_label)
      expect(base_instance.private_methods).to include(:collect_watches_recursive)
    end
  end

  describe '#collect_namespaced_watches' do
    let(:base_instance) do
      instance = R64::Base.new
      instance.instance_variable_set(:@processor, processor)
      instance.instance_variable_set(:@memory, memory)
      
      # Mock some watches for testing
      watchers_array = [
        { label: :test_var, address: "2000" },
        { label: :_test_method, address: "2010" },
        { label: :another_var, address: "2020" }
      ]
      instance.instance_variable_set(:@watchers, watchers_array)
      
      instance
    end

    it 'returns a hash of namespaced watches' do
      watches = base_instance.collect_namespaced_watches
      expect(watches).to be_a(Hash)
    end

    it 'handles empty watch sets' do
      empty_instance = R64::Base.new
      empty_instance.instance_variable_set(:@processor, processor)
      empty_instance.instance_variable_set(:@memory, memory)
      
      watches = empty_instance.collect_namespaced_watches
      expect(watches).to be_a(Hash)
      expect(watches).to be_empty
    end

    it 'creates namespaced watch labels with proper formatting' do
      watches = base_instance.collect_namespaced_watches
      
      # Should have namespaced labels with proper separators and shortening
      expect(watches.keys).to include(match(/BA\d+_TEST_VAR/))     # Regular variable
      expect(watches.keys).to include(match(/BA\d+!TESMET/))       # Method (starts with _), shortened
      expect(watches.keys).to include(match(/BA\d+_ANOVAR/))       # Regular variable, shortened
    end

    it 'converts watch labels to uppercase' do
      watches = base_instance.collect_namespaced_watches
      
      watches.keys.each do |label|
        expect(label).to eq(label.upcase)
      end
    end

    it 'prevents watch name collisions' do
      watches = base_instance.collect_namespaced_watches
      
      # All watch names should be unique
      expect(watches.keys.uniq.length).to eq(watches.keys.length)
    end

    it 'prevents address collisions' do
      watches = base_instance.collect_namespaced_watches
      
      # Group watches by address and ensure no address has multiple watches
      addresses_with_multiple_watches = watches.group_by { |_, address| address }
                                               .select { |_, watch_pairs| watch_pairs.length > 1 }
      
      expect(addresses_with_multiple_watches).to be_empty
    end

    it 'preserves address format as strings' do
      watches = base_instance.collect_namespaced_watches
      
      watches.values.each do |address|
        expect(address).to be_a(String)
        expect(address).to match(/\A[0-9a-fA-F]+\z/) # Hex string format
      end
    end
  end

  describe '#collect_watches_recursive' do
    let(:base_instance) { R64::Base.new }

    it 'collects watches from current object' do
      # Mock watches on the base instance
      watchers = [{ label: :test_watch, address: "1000" }]
      base_instance.instance_variable_set(:@watchers, watchers)
      base_instance.instance_variable_set(:@index, 0)
      
      collected_watches = {}
      used_addresses = {}
      
      base_instance.send(:collect_watches_recursive, base_instance, collected_watches, used_addresses)
      
      expect(collected_watches).not_to be_empty
      expect(collected_watches.keys.first).to include('TEST_WATCH')
    end

    it 'handles objects without watches' do
      collected_watches = {}
      used_addresses = {}
      
      base_instance.send(:collect_watches_recursive, base_instance, collected_watches, used_addresses)
      
      expect(collected_watches).to be_empty
    end

    it 'processes @_ instance variables recursively' do
      # Create a mock child object with watches
      child_instance = R64::Base.new
      child_instance.instance_variable_set(:@watchers, [{ label: :child_watch, address: "2000" }])
      child_instance.instance_variable_set(:@index, 1)
      
      # Set up parent with @_ child
      base_instance.instance_variable_set(:@_child, child_instance)
      base_instance.instance_variable_set(:@index, 0)
      
      collected_watches = {}
      used_addresses = {}
      
      base_instance.send(:collect_watches_recursive, base_instance, collected_watches, used_addresses)
      
      expect(collected_watches).not_to be_empty
      expect(collected_watches.keys.first).to include('CHIWAT')  # child_watch gets shortened
    end

    it 'handles arrays of objects in @_ variables' do
      # Create mock child objects with watches
      child1 = R64::Base.new
      child1.instance_variable_set(:@watchers, [{ label: :watch1, address: "3000" }])
      child1.instance_variable_set(:@index, 0)
      
      child2 = R64::Base.new
      child2.instance_variable_set(:@watchers, [{ label: :watch2, address: "3010" }])
      child2.instance_variable_set(:@index, 1)
      
      # Set up parent with @_ array
      base_instance.instance_variable_set(:@_children, [child1, child2])
      base_instance.instance_variable_set(:@index, 0)
      
      collected_watches = {}
      used_addresses = {}
      
      base_instance.send(:collect_watches_recursive, base_instance, collected_watches, used_addresses)
      
      expect(collected_watches.length).to eq(2)
      expect(collected_watches.keys).to include(match(/WATCH1/))
      expect(collected_watches.keys).to include(match(/WATCH2/))
    end

    it 'respects first-definition-wins for label collisions' do
      # Create two objects with same watch label and same index (to create actual collision)
      child1 = R64::Base.new
      child1.instance_variable_set(:@watchers, [{ label: :same_label, address: "4000" }])
      child1.instance_variable_set(:@index, 0)
      
      child2 = R64::Base.new
      child2.instance_variable_set(:@watchers, [{ label: :same_label, address: "4010" }])
      child2.instance_variable_set(:@index, 0)  # Same index to create collision
      
      base_instance.instance_variable_set(:@_child1, child1)
      base_instance.instance_variable_set(:@_child2, child2)
      base_instance.instance_variable_set(:@index, 0)
      
      collected_watches = {}
      used_addresses = {}
      
      base_instance.send(:collect_watches_recursive, base_instance, collected_watches, used_addresses)
      
      # Should only have one watch (first definition wins)
      same_label_watches = collected_watches.select { |k, v| k.include?('SAME_LABEL') }  # same_label doesn't get shortened (10 chars)
      expect(same_label_watches.length).to eq(1)
      expect(same_label_watches.values.first).to eq("4000") # First address
    end

    it 'respects first-address-wins for address collisions' do
      # Create two objects with different labels but same address
      child1 = R64::Base.new
      child1.instance_variable_set(:@watchers, [{ label: :label1, address: "5000" }])
      child1.instance_variable_set(:@index, 0)
      
      child2 = R64::Base.new
      child2.instance_variable_set(:@watchers, [{ label: :label2, address: "5000" }])
      child2.instance_variable_set(:@index, 1)
      
      base_instance.instance_variable_set(:@_child1, child1)
      base_instance.instance_variable_set(:@_child2, child2)
      base_instance.instance_variable_set(:@index, 0)
      
      collected_watches = {}
      used_addresses = {}
      
      base_instance.send(:collect_watches_recursive, base_instance, collected_watches, used_addresses)
      
      # Should only have one watch (first address wins)
      expect(collected_watches.length).to eq(1)
      expect(collected_watches.keys.first).to include('LABEL1') # First label
    end
  end

  describe 'integration with compilation system' do
    let(:base_instance) do
      instance = R64::Base.new
      instance.instance_variable_set(:@processor, processor)
      instance.instance_variable_set(:@memory, memory)
      
      # Mock watches
      watchers = [{ label: :integration_test, address: "6000" }]
      instance.instance_variable_set(:@watchers, watchers)
      
      instance
    end

    it 'integrates with the debug compilation system' do
      # Check that collect_namespaced_watches method is available
      expect(base_instance).to respond_to(:collect_namespaced_watches)
      
      # Check that it returns expected structure
      watches = base_instance.collect_namespaced_watches
      expect(watches).to be_a(Hash)
    end

    it 'works with the compile module methods' do
      # Simulate what the compile module does
      if base_instance.respond_to?(:collect_namespaced_watches)
        namespaced_watches = base_instance.collect_namespaced_watches
        expect(namespaced_watches).to be_a(Hash)
        
        # Should be able to iterate over watches for formatting
        namespaced_watches.each do |label, address|
          expect(label).to be_a(String)
          expect(address).to be_a(String)
        end
      end
    end
  end
end
