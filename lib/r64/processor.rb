module R64
  # 6502 processor state management for assembly programming
  #
  # The Processor class manages the state of a 6502 CPU including the
  # program counter (PC) and processor registers. It provides methods
  # for tracking and manipulating the processor state during assembly
  # code generation.
  #
  # @example Basic processor usage
  #   processor = R64::Processor.new(start: 0x2000)
  #   processor.increase_pc(2)  # Move PC forward 2 bytes
  #   puts processor.pc         # => 0x2002
  #
  # @example Processor with register initialization
  #   processor = R64::Processor.new(
  #     start: 0x1000,
  #     a: 0x01,      # Accumulator
  #     x: 0x02,      # X register
  #     y: 0x03,      # Y register
  #     s: 0xff       # Stack pointer
  #   )
  #
  # @example Resetting processor state
  #   processor.set_pc(0x3000)  # Jump to new location
  #   processor.reset_pc        # Reset to start address
  #   puts processor.pc         # => 0x1000 (start address)
  #
  # @see R64::Base For the main assembly programming interface
  # @see R64::Memory For memory management
  class Processor
    # @!attribute [rw] start
    #   @return [Integer] Starting address for the processor (default PC reset value)
    attr_accessor :start
  
    # Default processor initialization options
    #
    # Defines the standard initial state for a 6502 processor including
    # the starting program counter address and register values.
    DEFAULT_OPTIONS = {:start => 0x1000, :a => 0, :x => 0, :y => 0, :s => 0}
    
    # Initialize a new Processor instance
    #
    # Creates a new 6502 processor state with the specified configuration.
    # All processor registers and the program counter are initialized
    # according to the provided options or defaults.
    #
    # @param options [Hash] Configuration options for processor initialization
    # @option options [Integer] :start (0x1000) Starting address and initial PC value
    # @option options [Integer] :a (0) Initial accumulator register value
    # @option options [Integer] :x (0) Initial X index register value  
    # @option options [Integer] :y (0) Initial Y index register value
    # @option options [Integer] :s (0) Initial stack pointer value
    #
    # @example Default processor initialization
    #   processor = R64::Processor.new
    #   # PC starts at 0x1000, all registers at 0
    #
    # @example Custom processor initialization
    #   processor = R64::Processor.new(
    #     start: 0x2000,
    #     a: 0xff,
    #     x: 0x10,
    #     y: 0x20,
    #     s: 0xff
    #   )
    def initialize options={}
      options = DEFAULT_OPTIONS.merge options
      @start = options[:start]
      @pc = options[:start]
      @a = options[:a]
      @x = options[:x]
      @y = options[:y]
      @s = options[:s]
    end
    
    # Get the current processor state
    #
    # Returns a hash containing the current values of all processor
    # registers and the program counter. Useful for debugging and
    # state inspection during assembly code generation.
    #
    # @return [Hash] Hash containing current processor state with keys:
    #   - :pc - Program counter value
    #   - :a - Accumulator register value
    #   - :x - X index register value
    #   - :y - Y index register value
    #   - :s - Stack pointer value
    #
    # @example Checking processor status
    #   processor = R64::Processor.new(start: 0x2000, a: 0x42)
    #   status = processor.status
    #   puts status[:pc]  # => 0x2000
    #   puts status[:a]   # => 0x42
    def status
      {:pc => @pc, :a => @a, :x => @x, :y => @y, :s => @s}
    end
    
    # Get the current program counter value
    #
    # Returns the current program counter (PC) address. The program counter
    # tracks the memory location of the next instruction to be executed
    # or the next byte to be written during assembly.
    #
    # @return [Integer] Current program counter address
    #
    # @example Getting the program counter
    #   processor = R64::Processor.new(start: 0x2000)
    #   puts processor.pc  # => 0x2000
    #   processor.increase_pc(3)
    #   puts processor.pc  # => 0x2003
    def pc
      @pc
    end
    
    # Advance the program counter by a specified number of bytes
    #
    # Increments the program counter to reflect the consumption of
    # memory bytes during instruction generation. This is typically
    # called automatically by instruction methods to track code size.
    #
    # @param count [Integer] Number of bytes to advance the PC (default: 1)
    #
    # @example Advancing the program counter
    #   processor = R64::Processor.new(start: 0x2000)
    #   processor.increase_pc      # PC becomes 0x2001
    #   processor.increase_pc(3)   # PC becomes 0x2004
    #
    # @example Tracking instruction sizes
    #   processor.increase_pc(1)   # Single-byte instruction (implied)
    #   processor.increase_pc(2)   # Two-byte instruction (immediate/zero page)
    #   processor.increase_pc(3)   # Three-byte instruction (absolute)
    def increase_pc count=1
      @pc = @pc + count
    end
    
    # Reset the program counter to the starting address
    #
    # Sets the program counter back to the initial start address that
    # was specified during processor initialization. This is useful for
    # restarting code generation or resetting the processor state.
    #
    # @example Resetting the program counter
    #   processor = R64::Processor.new(start: 0x2000)
    #   processor.increase_pc(10)  # PC becomes 0x200a
    #   processor.reset_pc         # PC back to 0x2000
    #   puts processor.pc          # => 0x2000
    #
    # @see #set_pc For setting PC to an arbitrary address
    def reset_pc
      @pc = @start
    end
    
    # Set the program counter to a specific address
    #
    # Directly sets the program counter to the specified memory address.
    # This is useful for jumping to different code sections or setting
    # up the processor for code generation at a specific location.
    #
    # @param address [Integer] The memory address to set as the new PC value
    #
    # @example Setting a specific program counter
    #   processor = R64::Processor.new(start: 0x2000)
    #   processor.set_pc(0x3000)   # Jump to 0x3000
    #   puts processor.pc          # => 0x3000
    #
    # @example Switching between code sections
    #   processor.set_pc(0x1000)   # Main program area
    #   # ... generate some code ...
    #   processor.set_pc(0x2000)   # Subroutine area
    #   # ... generate subroutine code ...
    #
    # @see #reset_pc For resetting PC to the start address
    def set_pc address
      @pc = address
    end
    
  end

end
