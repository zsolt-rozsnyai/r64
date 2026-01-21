module R64
  class Assembler
    # Utility methods module for the R64 assembler.
    #
    # This module provides various utility methods for common assembly operations,
    # memory and processor access, address manipulation, and code generation helpers.
    # It serves as a collection of convenience methods that make assembly programming
    # more ergonomic and less error-prone.
    #
    # == Features
    #
    # * Memory and processor access methods
    # * 16-bit address manipulation (hi/lo byte splitting)
    # * Address storage utilities for vectors and pointers
    # * NOP instruction generation
    # * Code compilation helpers
    # * Class introspection utilities
    #
    # == Usage
    #
    #   # Access memory and processor
    #   memory[0x1000] = 0x42
    #   processor.set_pc(0x2000)
    #   
    #   # Handle 16-bit addresses
    #   addr_parts = hi_lo(0x1234)  # => {hi: 0x12, lo: 0x34}
    #   
    #   # Store addresses in memory
    #   address(0x0314, :irq_handler)  # Store IRQ vector
    #   
    #   # Generate padding
    #   nop(5)  # Insert 5 NOP instructions
    #
    # @author Maxwell of Graffity
    # @version 0.2.0
    module Utils
      # Returns a hash containing processor and memory resources.
      #
      # Provides access to the core assembler resources in a structured format.
      # Useful for passing both processor and memory to other components or
      # for debugging and introspection.
      #
      # @return [Hash] Hash with :processor and :memory keys
      #
      # @example Accessing resources
      #   resources = assembler.resources
      #   proc = resources[:processor]
      #   mem = resources[:memory]
      def resources
        { processor: @processor, memory: @memory }
      end

      # Returns the memory instance.
      #
      # Provides direct access to the assembler's memory object for reading
      # and writing memory locations, setting up data structures, and
      # managing memory layout.
      #
      # @return [R64::Memory] The memory instance
      #
      # @example Using memory
      #   memory[0x1000] = 0x42        # Write byte
      #   value = memory[0x1000]       # Read byte
      #   memory.start = 0x0801        # Set memory bounds
      def memory
        @memory
      end

      # Returns the processor instance.
      #
      # Provides direct access to the assembler's processor object for
      # managing the program counter, processor state, and execution flow.
      #
      # @return [R64::Processor] The processor instance
      #
      # @example Using processor
      #   processor.set_pc(0x2000)     # Set program counter
      #   current_pc = processor.pc    # Get current PC
      #   processor.start = 0x0801     # Set start address
      def processor
        @processor
      end

      # Stores a 16-bit address in memory as low and high bytes.
      #
      # This utility method handles the common task of storing 16-bit addresses
      # in memory using the 6502's little-endian format (low byte first).
      # It can resolve symbolic addresses and handle predefined address constants.
      #
      # @param store [Integer, Symbol] Where to store the address (memory location or symbol)
      # @param what [Integer, Symbol] The address to store (value or label)
      # @param options [Hash] Additional options passed to the set method
      #
      # @example Storing addresses
      #   # Store IRQ vector at $0314-$0315
      #   address(0x0314, :irq_handler)
      #   
      #   # Store using symbolic constants
      #   address(:nmi, :nmi_handler)
      #   
      #   # Store literal address
      #   address(0x1000, 0x2000)
      #
      # @note Addresses are stored in little-endian format (low byte, then high byte)
      def address(store, what, options = {})
        store = Opcodes::ADDRESSES[store] if store.is_a?(Symbol) && defined?(Opcodes::ADDRESSES)
        store = ADDRESSES[store] if store.is_a?(Symbol) && defined?(ADDRESSES)
        what = get_label what if what.is_a?(Symbol)
        set store, hi_lo(what)[:lo], options
        set store, hi_lo(what)[:hi], options.merge(hi: true)
      end

      # Splits a 16-bit number into high and low bytes.
      #
      # This utility method converts a 16-bit integer into its constituent
      # high and low bytes, which is essential for 6502 programming where
      # addresses and 16-bit values must be handled as separate bytes.
      #
      # @param number [Integer] The 16-bit number to split (0-65535)
      #
      # @return [Hash] Hash with :hi and :lo keys containing the byte values
      #
      # @raise [Exception] If the number is outside the valid 16-bit range
      #
      # @example Splitting addresses
      #   parts = hi_lo(0x1234)
      #   puts parts[:hi]  # => 18 (0x12)
      #   puts parts[:lo]  # => 52 (0x34)
      #   
      #   # Use in assembly
      #   lda hi_lo(0x1000)[:lo]  # Load low byte
      #   ldx hi_lo(0x1000)[:hi]  # Load high byte
      def hi_lo(number)
        raise Exception.new("Number out of range") if number > 65_535 || number < 0
        hi = (number / 256).to_i
        lo = number - hi * 256
        { hi: hi, lo: lo }
      end

      # Generates the specified number of NOP instructions.
      #
      # This utility method inserts NOP (No Operation) instructions, which
      # is useful for timing delays, code alignment, or creating space for
      # future code modifications.
      #
      # @param number [Integer] The number of NOP instructions to generate (default: 1)
      #
      # @example Generating NOPs
      #   nop        # Single NOP
      #   nop(5)     # Five NOPs for timing
      #   nop(16)    # Align to 16-byte boundary
      def nop(number = 1)
        number.times do
          add_code(token: :nop, args: [])
        end
      end

      # Executes a block of code in the assembler's context.
      #
      # This method allows dynamic compilation of assembly code by executing
      # a block within the assembler's instance context. Useful for conditional
      # code generation and modular assembly programming.
      #
      # @param args [Array] Arguments to pass to the block
      # @param block [Proc] The code block to execute
      #
      # @example Dynamic compilation
      #   compile do
      #     lda #$01
      #     sta $d020
      #   end
      #   
      #   # With arguments
      #   compile(color_value) do |color|
      #     lda color
      #     sta $d020
      #   end
      def compile(*args, &block)
        instance_exec(*args, &block)
      end

      # Adds class introspection capabilities when the module is included.
      #
      # This hook method automatically adds a `descendants` class method to
      # any class that includes the Utils module. The descendants method
      # returns all classes that inherit from the including class.
      #
      # @param base [Class] The class that is including this module
      #
      # @example Using descendants
      #   class MyAssembler < R64::Assembler
      #     include Utils
      #   end
      #   
      #   MyAssembler.descendants  # Returns array of subclasses
      #
      # @note This method uses ObjectSpace for introspection, which may have
      #   performance implications in large applications.
      def self.included(base)
        base.define_singleton_method(:descendants) do
          ObjectSpace.each_object(Class).select { |klass| klass < self }
        end
      end
    end
  end
end