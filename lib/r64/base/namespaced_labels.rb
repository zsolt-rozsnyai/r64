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

      # Creates a namespaced label name, with smart shortening and uppercase formatting.
      #
      # Combines the namespace with the original label name. For label names longer
      # than 10 characters, creates a shortened version by removing underscores and
      # vowels, then truncating. Labels starting with underscore use '!' notation.
      # All characters are converted to uppercase.
      #
      # @param namespace [String] The namespace prefix (e.g., "SP0")
      # @param label_name [String] The original label name
      # @return [String] Namespaced label with smart shortening and uppercase formatting
      #
      # @example Creating namespaced labels
      #   create_namespaced_label("SP0", "xpos")                  # => "SP0_XPOS"
      #   create_namespaced_label("SP0", "_set_xpos")             # => "SP0!SET_XPOS"
      #   create_namespaced_label("MU0", "_get_precalculated_order") # => "MU0!GETPREORD"
      #   create_namespaced_label("SM0", "very_long_method_name") # => "SM0_VERLONMET"
      #
      # @private
      def create_namespaced_label(namespace, label_name)
        # Determine if label starts with underscore for special notation
        starts_with_underscore = label_name.to_s.start_with?('_')
        
        # Create shortened version if label name is longer than 10 characters
        processed_label = label_name.length > 10 ? shorten_label_name(label_name) : label_name.to_s
        
        # Use ! notation for labels that originally started with underscore, _ for others
        separator = starts_with_underscore ? '!' : '_'
        
        # Create full label and convert to uppercase
        full_label = "#{namespace}#{separator}#{processed_label}".upcase
        
        # Truncate to 16 characters if necessary
        full_label.length > 16 ? full_label[0, 16] : full_label
      end

      # Creates a shortened version of a label name by splitting on underscores and taking parts.
      #
      # This method creates a compact representation of long label names by:
      # 1. Removing leading underscores
      # 2. Splitting by underscores into words
      # 3. Taking first 3 characters from each word
      # 4. Joining and truncating to 10 characters
      #
      # @param label_name [String] The original label name
      # @return [String] Shortened label name (max 10 characters)
      #
      # @example Shortening label names
      #   shorten_label_name("_get_precalculated_order") # => "getpreord"
      #   shorten_label_name("very_long_method_name")    # => "verlonmet"
      #   shorten_label_name("set_sprite_position")      # => "setsprpos"
      #
      # @private
      def shorten_label_name(label_name)
        # Remove leading underscores
        cleaned = label_name.gsub(/^_+/, '')
        
        # Split by underscores into words
        words = cleaned.split('_')
        
        # Take first 3 characters from each word
        shortened_parts = words.map { |word| word[0, 3] }
        
        # Join all parts
        shortened = shortened_parts.join
        
        # Truncate to 10 characters
        shortened[0, 10]
      end
    end
  end
end
