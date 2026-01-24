module R64
  class Base
    # Namespaced labels module for R64::Base that provides functionality to generate
    # namespaced labels from all objects in the hierarchy.
    #
    # This module creates unique, collision-free labels by prefixing each label with
    # a 2-character namespace derived from the object's class name and index.
    # It recursively traverses all @_ instance variables to collect labels from
    # the entire object hierarchy.
    #
    # == Features
    #
    # * Automatic namespace generation (e.g., Sprite0 => SP0, SpriteManager0 => SM0)
    # * Recursive traversal of @_ instance variables
    # * Label collision detection and resolution (first definition wins)
    # * Memory address collision detection (first address wins)
    # * 16-character label truncation for compatibility
    #
    # == Usage
    #
    #   class Main < R64::Base
    #     def _main
    #       namespaced_labels.each do |label, address|
    #         puts "#{label}: #{address.to_s(16)}"
    #       end
    #     end
    #   end
    #
    # @author Maxwell of Graffity
    # @version 0.2.0
    module NamespacedLabels
      # Returns all labels from this object and its @_ children with proper namespacing.
      #
      # This method recursively traverses all @_ instance variables and collects
      # labels from each object, applying appropriate namespacing to prevent
      # collisions. Labels are truncated to 16 characters and deduplicated.
      #
      # @return [Hash] Hash of namespaced labels mapping to their addresses
      #
      # @example Getting namespaced labels from main object
      #   main = Main.new
      #   labels = main.namespaced_labels
      #   # => {"MA0_main_loop" => 8195, "SC0_irq" => 8200, "SP0_sprite_data" => 8250}
      #
      # @note Label collisions are resolved by keeping the first definition
      # @note Address collisions are resolved by keeping the first label for that address
      def namespaced_labels
        collected_labels = {}
        used_addresses = {}
        
        # Collect labels from this object and all @_ children recursively
        collect_labels_recursive(self, collected_labels, used_addresses)
        
        collected_labels
      end

      # Returns all watches from this object and its @_ children with proper namespacing.
      #
      # This method recursively traverses all @_ instance variables and collects
      # watches from each object, applying appropriate namespacing to prevent
      # collisions. Watch labels are truncated to 16 characters and deduplicated.
      #
      # @return [Hash] Hash of namespaced watch labels mapping to their addresses
      #
      # @example Getting namespaced watches from main object
      #   main = Main.new
      #   watches = main.collect_namespaced_watches
      #   # => {"MU0_SORTED_SPRITE_ORDER" => "20e2", "SP0_XPOS" => "2b2e"}
      #
      # @note Watch collisions are resolved by keeping the first definition
      # @note Address collisions are resolved by keeping the first watch for that address
      def collect_namespaced_watches
        collected_watches = {}
        used_addresses = {}
        
        # Collect watches from this object and all @_ children recursively
        collect_watches_recursive(self, collected_watches, used_addresses)
        
        collected_watches
      end

      # Returns all breakpoints from this object and its @_ children with proper namespacing.
      #
      # This method recursively traverses all @_ instance variables and collects
      # breakpoints from each object, applying appropriate namespacing to prevent
      # collisions. Breakpoint labels are truncated to 16 characters and deduplicated.
      #
      # @return [Array] Array of namespaced breakpoint hashes with type, address, and namespace info
      #
      # @example Getting namespaced breakpoints from main object
      #   main = Main.new
      #   breakpoints = main.collect_namespaced_breakpoints
      #   # => [{"type" => "breakonpc", "address" => "2010", "namespace" => "MU0"}]
      #
      # @note Breakpoint collisions are resolved by keeping the first definition
      # @note Address collisions are resolved by keeping the first breakpoint for that address
      def collect_namespaced_breakpoints
        collected_breakpoints = []
        used_addresses = {}
        
        # Collect breakpoints from this object and all @_ children recursively
        collect_breakpoints_recursive(self, collected_breakpoints, used_addresses)
        
        collected_breakpoints
      end

      private

      # Recursively collects labels from an object and its @_ children.
      #
      # This method traverses the object hierarchy by examining all instance variables
      # that start with @_ and recursively collecting labels from each child object.
      #
      # @param obj [R64::Base] The object to collect labels from
      # @param collected_labels [Hash] Hash to store collected labels (modified in place)
      # @param used_addresses [Hash] Hash to track used addresses (modified in place)
      #
      # @private
      def collect_labels_recursive(obj, collected_labels, used_addresses)
        # Get labels from current object
        if obj.respond_to?(:instance_variable_get) && obj.instance_variable_get(:@labels)
          namespace = generate_namespace(obj)
          obj_labels = obj.instance_variable_get(:@labels) || {}
          
          obj_labels.each do |label_name, address|
            namespaced_label = create_namespaced_label(namespace, label_name.to_s)
            
            # Skip if label name already exists (first definition wins)
            next if collected_labels.key?(namespaced_label)
            
            # Skip if address already used (first address wins)
            next if used_addresses.key?(address)
            
            collected_labels[namespaced_label] = address
            used_addresses[address] = namespaced_label
          end
        end
        
        # Recursively process @_ instance variables
        obj.instance_variables.each do |var_name|
          next unless var_name.to_s.start_with?('@_')
          
          var_value = obj.instance_variable_get(var_name)
          
          if var_value.is_a?(Array)
            # Handle arrays of objects
            var_value.each do |item|
              collect_labels_recursive(item, collected_labels, used_addresses) if item.respond_to?(:instance_variables)
            end
          elsif var_value.respond_to?(:instance_variables)
            # Handle single objects
            collect_labels_recursive(var_value, collected_labels, used_addresses)
          end
        end
      end

      # Recursively collects watches from an object and its @_ children.
      #
      # This method traverses the object hierarchy by examining all instance variables
      # that start with @_ and recursively collecting watches from each child object.
      #
      # @param obj [R64::Base] The object to collect watches from
      # @param collected_watches [Hash] Hash to store collected watches (modified in place)
      # @param used_addresses [Hash] Hash to track used addresses (modified in place)
      #
      # @private
      def collect_watches_recursive(obj, collected_watches, used_addresses)
        # Get watches from current object
        if obj.respond_to?(:instance_variable_get) && obj.instance_variable_get(:@watchers)
          namespace = generate_namespace(obj)
          obj_watchers = obj.instance_variable_get(:@watchers) || []
          
          obj_watchers.each do |watcher|
            # Create namespaced label for the watch
            original_label = watcher[:label].to_s
            namespaced_label = create_namespaced_label(namespace, original_label)
            
            # Skip if label name already exists (first definition wins)
            next if collected_watches.key?(namespaced_label)
            
            # Get the address (could be hex string or integer)
            address = watcher[:address]
            address = address.is_a?(String) ? address : address.to_s(16)
            
            # Skip if address already used (first address wins)
            next if used_addresses.key?(address)
            
            collected_watches[namespaced_label] = address
            used_addresses[address] = namespaced_label
          end
        end
        
        # Recursively process @_ instance variables
        obj.instance_variables.each do |var_name|
          next unless var_name.to_s.start_with?('@_')
          
          var_value = obj.instance_variable_get(var_name)
          
          if var_value.is_a?(Array)
            # Handle arrays of objects
            var_value.each do |item|
              collect_watches_recursive(item, collected_watches, used_addresses) if item.respond_to?(:instance_variables)
            end
          elsif var_value.respond_to?(:instance_variables)
            # Handle single objects
            collect_watches_recursive(var_value, collected_watches, used_addresses)
          end
        end
      end

      # Recursively collects breakpoints from an object and its @_ children.
      #
      # This method traverses the object hierarchy by examining all instance variables
      # that start with @_ and recursively collecting breakpoints from each child object.
      #
      # @param obj [R64::Base] The object to collect breakpoints from
      # @param collected_breakpoints [Array] Array to store collected breakpoints (modified in place)
      # @param used_addresses [Hash] Hash to track used addresses (modified in place)
      #
      # @private
      def collect_breakpoints_recursive(obj, collected_breakpoints, used_addresses)
        # Get breakpoints from current object
        if obj.respond_to?(:instance_variable_get) && obj.instance_variable_get(:@breakpoints)
          namespace = generate_namespace(obj)
          obj_breakpoints = obj.instance_variable_get(:@breakpoints) || []
          
          obj_breakpoints.each do |breakpoint|
            # Get the address from the breakpoint params
            address = breakpoint[:params].to_s
            
            # Skip if address already used (first address wins)
            next if used_addresses.key?(address)
            
            # Create namespaced breakpoint entry
            namespaced_breakpoint = {
              "type" => breakpoint[:type],
              "address" => address,
              "namespace" => namespace
            }
            
            collected_breakpoints << namespaced_breakpoint
            used_addresses[address] = namespace
          end
        end
        
        # Recursively process @_ instance variables
        obj.instance_variables.each do |var_name|
          next unless var_name.to_s.start_with?('@_')
          
          var_value = obj.instance_variable_get(var_name)
          
          if var_value.is_a?(Array)
            # Handle arrays of objects
            var_value.each do |item|
              collect_breakpoints_recursive(item, collected_breakpoints, used_addresses) if item.respond_to?(:instance_variables)
            end
          elsif var_value.respond_to?(:instance_variables)
            # Handle single objects
            collect_breakpoints_recursive(var_value, collected_breakpoints, used_addresses)
          end
        end
      end

      # Generates a 2-character namespace from an object's class name and index.
      #
      # The namespace is created by taking the first two consonants from the class name
      # (excluding 'R64::' prefix) and appending the object's index.
      #
      # @param obj [R64::Base] The object to generate namespace for
      # @return [String] 2-character namespace plus index (e.g., "SP0", "SM1")
      #
      # @example Namespace generation
      #   generate_namespace(sprite_obj)        # => "SP0"
      #   generate_namespace(sprite_manager)    # => "SM0"
      #   generate_namespace(multiplexer)       # => "ML0"
      #
      # @private
      def generate_namespace(obj)
        class_name = obj.class.name.gsub(/^R64::/, '')
        
        # Extract consonants from class name, prioritizing uppercase letters
        consonants = class_name.scan(/[BCDFGHJKLMNPQRSTVWXYZ]/)
        
        # If we don't have enough consonants, fall back to all letters
        if consonants.length < 2
          consonants = class_name.scan(/[A-Z]/)
        end
        
        # If still not enough, use first two characters
        if consonants.length < 2
          consonants = class_name[0, 2].upcase.chars
        end
        
        # Take first two consonants and add index
        namespace_chars = consonants[0, 2].join
        index = obj.respond_to?(:instance_variable_get) && obj.instance_variable_get(:@index) || 0
        
        "#{namespace_chars}#{index}"
      end

      # Creates a namespaced label with proper formatting and collision prevention.
      #
      # This method combines a namespace with a label name, applying appropriate
      # formatting rules and truncation to ensure compatibility with debugging tools.
      #
      # @param namespace [String] The namespace prefix (e.g., "SP0", "MU0")
      # @param label_name [String] The original label name
      # @return [String] Formatted namespaced label (max 16 characters)
      #
      # @example Creating namespaced labels
      #   create_namespaced_label("SP0", "xpos")           # => "SP0_XPOS"
      #   create_namespaced_label("MU0", "_get_order")     # => "MU0!GETORD"
      #   create_namespaced_label("SC0", "very_long_name") # => "SC0_VERLON"
      #
      # @private
      def create_namespaced_label(namespace, label_name)
        # Check if label starts with underscore (method label)
        method_label = label_name.to_s.start_with?('_')
        
        # Remove preceding underscore if it's a method label
        cleaned_name = method_label ? label_name.to_s[1..-1] : label_name.to_s
        
        # Create shortened version using new algorithm
        processed_label = shorten_label_name(cleaned_name)
        
        # Use ! prefix for method labels, _ for regular labels
        separator = method_label ? '!' : '_'
        
        # Create full label with namespace prefix and convert to uppercase
        full_label = "#{namespace}#{separator}#{processed_label}".upcase
        
        # Truncate to 16 characters if necessary
        full_label.length > 16 ? full_label[0, 16] : full_label
      end

      # Creates a shortened version of a label name using dynamic character allocation.
      #
      # This method creates a compact representation of label names by:
      # 1. Splitting by underscores into words
      # 2. Calculating characters per word: (10 / words.count).to_i
      # 3. Taking that many characters from each word
      # 4. Joining all parts
      #
      # @param label_name [String] The original label name (without leading underscores)
      # @return [String] Shortened label name (max 10 characters)
      #
      # @example Shortening label names
      #   shorten_label_name("get_precalculated_order") # => "getpreord" (3 words, 3 chars each)
      #   shorten_label_name("very_long_method_name")   # => "verlonmet" (4 words, 2 chars each)
      #   shorten_label_name("set_sprite_position")     # => "setsprpos" (3 words, 3 chars each)
      #   shorten_label_name("single")                  # => "single"    (1 word, 10 chars)
      #
      # @private
      def shorten_label_name(label_name)
        # Split by underscores into words
        words = label_name.split('_')
        
        # Calculate how many characters to take from each word
        chars_per_word = (10 / words.count).to_i
        
        # Ensure we take at least 1 character per word
        chars_per_word = [chars_per_word, 1].max
        
        # Take calculated number of characters from each word
        shortened_parts = words.map { |word| word[0, chars_per_word] }
        
        # Join all parts
        shortened = shortened_parts.join
        
        # Truncate to 10 characters if still too long
        shortened[0, 10]
      end
    end
  end
end
