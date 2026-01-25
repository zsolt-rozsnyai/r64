require_relative 'base/hooks'
require_relative 'base/dispatch'
require_relative 'base/rendering'
require_relative 'base/namespaced_labels'

module R64
  # Base class for R64 assembly objects that provides enhanced functionality over the basic Assembler.
  #
  # The Base class extends the core Assembler with three key capabilities:
  # - Hooks: Lifecycle callbacks for before/after compilation and creation
  # - Dispatch: Method dispatch system for calling assembly subroutines
  # - Rendering: Code generation and binary output functionality
  #
  # This class is designed to be subclassed for creating reusable assembly components
  # that can be composed together to build larger Commodore 64 programs.
  #
  # == Features
  #
  # * Hierarchical object system with parent-child relationships
  # * Automatic instance counting and unique naming
  # * Lifecycle hooks for customizing compilation behavior
  # * Method dispatch for calling assembly subroutines (JSR vs inline)
  # * Code rendering and binary generation
  # * Memory and processor state management
  #
  # == Usage
  #
  #   class MyScreen < R64::Base
  #     def _set_background_color
  #       lda 0x01
  #       sta 0xd020
  #     end
  #   end
  #   
  #   screen = MyScreen.new
  #   screen.setup(start: 0x2000, end: 0x3000)
  #   screen.set_background_color  # Calls _set_background_color as a subroutine
  #   binary = screen.to_binary
  #
  # == Inheritance Hierarchy
  #
  # Base inherits from Assembler and includes three modules:
  # - Hooks: Provides before/after callbacks
  # - Dispatch: Handles method_missing for subroutine calls
  # - Rendering: Manages code generation and output
  #
  # @see R64::Assembler The parent class providing core assembly functionality
  # @see R64::Base::Hooks Module providing lifecycle callbacks
  # @see R64::Base::Dispatch Module providing method dispatch
  # @see R64::Base::Rendering Module providing code generation
  #
  # @author Maxwell of Graffity
  # @version 0.2.0
  class Base < Assembler
    include Hooks
    include Dispatch
    include Rendering
    include NamespacedLabels

    # Creates a new Base instance with optional parent relationship.
    #
    # The initialize method sets up the object hierarchy, inherits memory and processor
    # state from the parent (if provided), assigns a unique instance index, and
    # executes any registered before hooks.
    #
    # @param parent [R64::Base, nil] Optional parent object to inherit memory and processor from.
    #   When provided, this instance will share the same memory and processor state as the parent,
    #   enabling hierarchical composition of assembly objects.
    #
    # @example Creating a standalone Base object
    #   base = R64::Base.new
    #
    # @example Creating a child object that inherits from parent
    #   parent = R64::Base.new
    #   child = R64::Base.new(parent)
    #   # child now shares parent's memory and processor
    #
    # @note The instance index is automatically assigned from the class instance counter
    #   and is used for generating unique object names and debugging output.
    #
    # @note Any before hooks registered with the class will be executed during initialization.
    #
    # @see #object_name For how the instance index is used in naming
    # @see R64::Base::Hooks::ClassMethods#before For registering before hooks
    def initialize(parent=nil)
      @parent = parent
      puts "parent: #{@parent}" if verbose
      super memory: @parent&.memory, processor: @parent&.processor
      @index = self.class.instance_count
      self.class.instance_count += 1
      @rendered = false

      self.class.before.each do |block|
        instance_exec(&block)
      end if self.class.before
    end

    # Configures the memory and processor state for this Base instance.
    #
    # This method sets up the memory boundaries and processor program counter
    # based on the provided options. It's typically called after initialization
    # to define where in memory this object's code will be placed.
    #
    # @param options [Hash] Configuration options for memory and processor setup
    # @option options [Integer] :start The starting memory address for this object's code.
    #   Sets both the processor PC and memory start address.
    # @option options [Integer] :end The ending memory address for this object's code.
    #   Sets the memory finish boundary.
    #
    # @example Setting up memory boundaries
    #   base = R64::Base.new
    #   base.setup(start: 0x2000, end: 0x3000)
    #   # Code will be placed between $2000 and $3000
    #
    # @example Minimal setup with just start address
    #   base.setup(start: 0x0801)  # Standard C64 BASIC start
    #
    # @note The method calls set_entrypoint after configuring memory and processor,
    #   which may be overridden in subclasses for custom entry point behavior.
    #
    # @see R64::Processor#set_pc For processor program counter management
    # @see R64::Memory For memory boundary management
    def setup options={}
      processor.set_pc(options[:entry] || options[:start])
      processor.start = options[:start]
      memory.start = options[:start]
      memory.finish = options[:end]
      set_entrypoint
    end

    # Returns a unique name for this object instance.
    #
    # The object name combines the class name with the instance index to create
    # a unique identifier. This is useful for debugging, logging, and generating
    # unique labels in the assembly output.
    #
    # @return [String] A unique name in the format "ClassName#index"
    #
    # @example Getting object names
    #   base1 = R64::Base.new
    #   base2 = R64::Base.new
    #   puts base1.object_name  # => "R64::Base0"
    #   puts base2.object_name  # => "R64::Base1"
    #
    # @example With custom subclass
    #   class MySprite < R64::Base; end
    #   sprite = MySprite.new
    #   puts sprite.object_name  # => "MySprite0"
    #
    # @note The index is automatically assigned during initialization and
    #   increments for each new instance of the class.
    #
    # @see #initialize For how the index is assigned
    def object_name
      "#{self.class.name}#{@index}"
    end

    # Returns a detailed string representation of this Base instance for debugging.
    #
    # The inspect method provides a comprehensive view of the object's state,
    # including the unique object name, instance index, and parent relationship.
    # This is particularly useful for debugging hierarchical object structures
    # and understanding the composition of complex assembly programs.
    #
    # @return [String] A detailed string representation in the format:
    #   "#<ObjectName @index=N @parent=ParentName>"
    #   where ObjectName is from {#object_name}, N is the instance index,
    #   and ParentName is the parent's object name (or nil if no parent)
    #
    # @example Standalone object inspection
    #   base = R64::Base.new
    #   puts base.inspect
    #   # => "#<R64::Base0 @index=0 @parent=nil>"
    #
    # @example Parent-child relationship inspection
    #   parent = R64::Base.new
    #   child = R64::Base.new(parent)
    #   puts parent.inspect  # => "#<R64::Base0 @index=0 @parent=nil>"
    #   puts child.inspect   # => "#<R64::Base1 @index=1 @parent=R64::Base0>"
    #
    # @example Custom subclass inspection
    #   class MySprite < R64::Base; end
    #   sprite = MySprite.new
    #   puts sprite.inspect  # => "#<MySprite0 @index=0 @parent=nil>"
    #
    # @note This method overrides Ruby's default Object#inspect to provide
    #   R64-specific debugging information that's more useful than the default
    #   object ID representation.
    #
    # @note The parent information uses safe navigation (&.) to handle cases
    #   where the parent might be nil, displaying "nil" instead of raising an error.
    #
    # @see #object_name For how the object name is generated
    # @see #initialize For how the index and parent are assigned
    def inspect
      parent_name = @parent&.object_name || 'nil'
      "#<#{object_name} @index=#{@index} @parent=#{parent_name}>"
    end
  end
end