module R64
  class Memory < Array
    attr_accessor :start, :finish
    
    def initialize options={}
      @start = options[:start] || 0
      @finish = options[:end] || 0xffff
    end
    
    # Helper method to set the calling object context
    def self.with_caller(caller_obj)
      old_caller = Thread.current[:memory_caller]
      Thread.current[:memory_caller] = caller_obj
      yield
    ensure
      Thread.current[:memory_caller] = old_caller
    end
    
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
    
    def [](index)
      stored = super(index)
      return stored[:value] if stored.is_a?(Hash) && stored.key?(:value)
      stored
    end
    
    # Method to get the full memory entry (hash with value and owner)
    def get_memory_entry(index)
      super(index)
    end
    
    private
    
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

    def inspect
      self.slice(0, 10).push('...')
    end
  end
end
