module R64
  # Memory management class for 6502 assembly programming
  #
  # The Memory class extends Array to provide specialized memory management
  # for Commodore 64 assembly programming. It tracks memory ownership to
  # prevent conflicts when multiple objects write to the same memory locations.
  #
  # @example Basic memory usage
  #   memory = R64::Memory.new(start: 0x2000, end: 0x3000)
  #   memory[0x2000] = 0x60  # RTS instruction
  #   puts memory[0x2000]    # => 96 (0x60)
  #
  # @example Memory ownership tracking
  #   # When used with R64::Base objects, memory tracks ownership
  #   class MyProgram < R64::Base
  #     def setup
  #       memory[0x2000] = 0x60  # This object owns location 0x2000
  #     end
  #   end
  #
  # @example Using with_caller for context tracking
  #   R64::Memory.with_caller(my_object) do
  #     memory[0x2000] = 0xa9  # LDA immediate
  #     memory[0x2001] = 0x01  # Value 1
  #   end
  #
  # @see R64::Base For the main assembly programming interface
  # @see R64::Processor For CPU state management
  class Memory < Array
    # @!attribute [rw] start
    #   @return [Integer] Starting address of the memory range
    # @!attribute [rw] finish  
    #   @return [Integer] Ending address of the memory range
    attr_accessor :start, :finish
    
    # Initialize a new Memory instance
    #
    # Creates a new memory array with specified address range. The memory
    # behaves like a standard Array but with additional ownership tracking
    # and conflict detection capabilities.
    #
    # @param options [Hash] Configuration options for the memory instance
    # @option options [Integer] :start (0) Starting address of memory range
    # @option options [Integer] :end (0xffff) Ending address of memory range
    #
    # @example Create memory for a specific range
    #   memory = R64::Memory.new(start: 0x2000, end: 0x3000)
    #
    # @example Create memory with default full 64K range
    #   memory = R64::Memory.new
    def initialize options={}
      @start = options[:start] || 0
      @finish = options[:end] || 0xffff
    end
    
    # Set the calling object context for memory operations
    #
    # This class method temporarily sets the calling object context for
    # memory operations within the given block. This is used internally
    # by the R64 framework to track which object is writing to memory
    # locations, enabling ownership tracking and conflict detection.
    #
    # @param caller_obj [Object] The object that should be considered the
    #   owner of any memory writes within the block
    # @yield Block of code where memory operations will be attributed
    #   to the specified caller object
    #
    # @example Setting caller context
    #   R64::Memory.with_caller(my_program) do
    #     memory[0x2000] = 0xa9  # Owned by my_program
    #     memory[0x2001] = 0x01  # Also owned by my_program
    #   end
    #
    # @note This method is thread-safe and properly restores the previous
    #   caller context even if an exception occurs
    # @api private This method is primarily for internal framework use
    def self.with_caller(caller_obj)
      old_caller = Thread.current[:memory_caller]
      Thread.current[:memory_caller] = caller_obj
      yield
    ensure
      Thread.current[:memory_caller] = old_caller
    end
    
    # Write a value to a memory location with ownership tracking
    #
    # Sets a value at the specified memory index while tracking ownership.
    # If the memory location is already owned by a different object, an
    # exception is raised to prevent conflicts.
    #
    # @param index [Integer] Memory address/index to write to
    # @param value [Integer] Byte value to store (0-255)
    # @raise [RuntimeError] If the memory location is owned by another object
    #
    # @example Writing to memory
    #   memory[0x2000] = 0xa9  # LDA immediate
    #   memory[0x2001] = 0x01  # Load value 1
    #
    # @example Ownership conflict
    #   # This will raise an exception if another object owns 0x2000
    #   memory[0x2000] = 0x60  # RuntimeError: Memory location owned by...
    #
    # @note The actual storage includes both the value and ownership metadata
    def []=(index, value)
      owner = get_calling_object

      # Get the existing raw data using Array's [] method to avoid recursion
      existing_raw = Array.instance_method(:[]).bind(self).call(index)
      
      if existing_raw.is_a?(Hash) && existing_raw.key?(:owner)
        if existing_raw[:owner] != owner
          existing_owner_name = get_object_display_name(existing_raw[:owner])
          current_owner_name = get_object_display_name(owner)
          raise "Memory location #{index} (0x#{index.to_s(16).upcase}) is owned by #{existing_owner_name} and cannot be reassigned by #{current_owner_name}"
        end
      end

      super(index, { value: value, owner: owner })
    end
    
    # Read a value from a memory location
    #
    # Retrieves the byte value stored at the specified memory index.
    # This method abstracts away the internal ownership tracking and
    # returns only the actual byte value.
    #
    # @param index [Integer] Memory address/index to read from
    # @return [Integer, nil] The byte value (0-255) stored at the location,
    #   or nil if nothing has been stored there
    #
    # @example Reading from memory
    #   memory[0x2000] = 0xa9
    #   puts memory[0x2000]  # => 169 (0xa9)
    #
    # @example Reading uninitialized memory
    #   puts memory[0x3000]  # => nil
    def [](index)
      stored = super(index)
      return stored[:value] if stored.is_a?(Hash) && stored.key?(:value)
      stored
    end
    
    # Get the complete memory entry including ownership metadata
    #
    # Returns the full internal representation of a memory location,
    # including both the stored value and ownership information.
    # This is primarily used for debugging and internal framework operations.
    #
    # @param index [Integer] Memory address/index to inspect
    # @return [Hash, nil] Hash containing :value and :owner keys, or nil
    #   if the location is uninitialized
    #
    # @example Inspecting memory entry
    #   memory[0x2000] = 0xa9
    #   entry = memory.get_memory_entry(0x2000)
    #   # => { value: 169, owner: #<MyProgram:0x...> }
    #
    # @api private This method exposes internal implementation details
    def get_memory_entry(index)
      super(index)
    end
    
    private
    
    # Get a human-readable display name for an object
    #
    # Formats object information for error messages and debugging output.
    # Handles different object types including R64::Base objects and
    # call stack information hashes.
    #
    # @param obj [Object] The object to get a display name for
    # @return [String] Human-readable representation of the object
    # @api private
    def get_object_display_name(obj)
      # If the object responds to object_name (like R64::Base), use that
      if obj.respond_to?(:object_name)
        return obj.object_name
      end
      
      # If it's a hash with object information, format it nicely
      if obj.is_a?(Hash)
        if obj.key?(:object_name)
          return "#{obj[:object_name]} (#{obj[:file]}:#{obj[:line]})"
        else
          return "#{obj[:file]}:#{obj[:line]} in #{obj[:method]}"
        end
      end
      
      # Fallback to inspect for other objects
      obj.inspect
    end
    
    # Determine the object responsible for the current memory operation
    #
    # Uses thread-local storage and call stack introspection to identify
    # which object is performing a memory write operation. This enables
    # ownership tracking and conflict detection.
    #
    # @return [Object, Hash] The calling object or call stack information
    # @api private
    def get_calling_object
      calling_object = Thread.current[:memory_caller]
      return calling_object unless calling_object.nil?
      
      # Try to capture the actual calling object using Ruby introspection
      begin
        # First try to get the actual object from the call stack
        # Look through the call stack to find an R64::Base object
        caller_locations(2, 10).each_with_index do |location, i|
          # Try to get the binding at this level and evaluate 'self'
          begin
            # This is a heuristic approach - we look for method calls that might be from R64::Base objects
            if location.path.include?('r64') && !location.path.include?('memory.rb')
              # Try to infer the calling object from the call stack context
              # This is limited but better than nothing
              calling_object = {
                file: File.basename(location.path),
                line: location.lineno,
                method: location.label || 'unknown_method',
                source_line: get_source_line(location.path, location.lineno)
              }
              break
            end
          rescue
            # Continue to next caller if this one fails
            next
          end
        end
        
        # Fallback to the immediate caller if we didn't find anything better
        if calling_object.nil?
          caller_location = caller_locations(2, 1).first # Skip []= and get_calling_object
          
          if caller_location
            calling_object = {
              file: File.basename(caller_location.path),
              line: caller_location.lineno,
              method: caller_location.label || 'unknown_method',
              source_line: get_source_line(caller_location.path, caller_location.lineno)
            }
          else
            calling_object = 'no_caller_info'
          end
        end
      rescue => e
        calling_object = "error: #{e.message}"
      end
      
      calling_object
    end
    
    # Read a specific line from a source file
    #
    # Helper method to extract source code lines for debugging and
    # error reporting purposes. Used when building call stack information.
    #
    # @param file_path [String] Path to the source file
    # @param line_number [Integer] Line number to read (1-indexed)
    # @return [String] The source line content, or error message
    # @api private
    def get_source_line(file_path, line_number)
      return 'unknown' unless File.exist?(file_path)
      
      begin
        lines = File.readlines(file_path)
        if line_number <= lines.length && line_number > 0
          lines[line_number - 1].strip
        else
          'invalid_line_number'
        end
      rescue
        'error_reading_file'
      end
    end

    # Provide a concise string representation of the memory object
    #
    # Returns a truncated view of the memory contents to avoid overwhelming
    # output when inspecting large memory arrays. Shows only the first 10
    # elements followed by an ellipsis.
    #
    # @return [Array] Truncated array representation for display
    #
    # @example Memory inspection
    #   memory = R64::Memory.new
    #   memory[0] = 0xa9
    #   memory[1] = 0x01
    #   puts memory.inspect  # Shows first 10 elements + "..."
    def inspect
      self.slice(0, 10).push('...')
    end
  end
end
