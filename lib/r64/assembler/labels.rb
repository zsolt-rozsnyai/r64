module R64
  class Assembler
    # Label management module for the R64 assembler.
    #
    # This module provides functionality for defining, resolving, and managing
    # labels in assembly code. Labels are symbolic names that represent memory
    # addresses, making code more readable and maintainable.
    #
    # == Features
    #
    # * Label definition with automatic or explicit addresses
    # * Label resolution and reference tracking
    # * Double-byte label support for 16-bit addresses
    # * Precompilation support with placeholder values
    # * Dynamic label access via method_missing
    #
    # == Usage
    #
    #   # Define a label at current PC
    #   label :start
    #   
    #   # Define a label at specific address
    #   label :data_area, 0x2000
    #   
    #   # Create double-byte labels (lo/hi)
    #   label :address, :double
    #   
    #   # Reference labels in instructions
    #   jmp :start
    #   lda :data_area
    #
    # @author Maxwell of Graffity
    # @version 0.2.0
    module Labels
      # Retrieves a label's address and tracks the reference.
      #
      # This method is used internally by the assembler to resolve label
      # references in instructions. It maintains a list of all locations
      # where each label is referenced for debugging and linking purposes.
      #
      # @param arg [Symbol] The label name to retrieve
      # @param options [Hash] Additional options (currently unused)
      #
      # @return [Integer] The label's address, or current PC during precompilation
      #
      # @raise [Exception] If the label doesn't exist during final compilation
      #
      # @example Getting a label address
      #   label :start
      #   address = get_label(:start)  # Returns the address of :start
      #
      # @note During precompilation, returns the current PC value
      #   to allow forward references to be processed.
      def get_label(arg, options = {})
        @labels ||= {}
        @references ||= {}
        @references[arg] ||= []
        @references[arg].push @processor.pc unless @references[arg].include?(@processor.pc)
        @precompile ? @processor.pc : @labels[arg] ? @labels[arg] : raise(Exception.new("Label does not exists '#{arg}', #{@labels.to_json}"))
      end

      # Defines a new label at the specified or current address.
      #
      # Labels can be defined at the current program counter location or at
      # a specific address. Special support is provided for double-byte labels
      # which create separate low and high byte labels for 16-bit addresses.
      #
      # @param name [Symbol] The label name
      # @param address [Integer, Symbol, false] The address for the label.
      #   - Integer: Specific address
      #   - :double: Creates name_lo and name_hi labels for 16-bit values
      #   - false/nil: Uses current program counter
      #
      # @raise [Exception] If attempting to redefine an existing label during precompilation
      #
      # @example Basic label definition
      #   label :start          # Label at current PC
      #   label :data, 0x2000   # Label at specific address
      #
      # @example Double-byte label
      #   label :vector, :double  # Creates :vector_lo and :vector_hi
      #
      # @note Double-byte labels automatically increment the PC for the high byte
      def label(name, address = false)
        if address === :double
          label "#{name}_lo".to_sym
          label "#{name}_hi".to_sym, processor.pc + 1
          address = false
        end
        @labels ||= {}
        if @labels[name] && @precompile
          raise Exception.new("Double definition of label '#{name}'")
        else
          @labels[name] = address || @processor.pc
        end
      end

      # Provides dynamic access to label values via method calls.
      #
      # This method allows labels to be accessed as if they were methods,
      # providing a more natural syntax for label references in assembly code.
      # During precompilation, returns a placeholder value for forward references.
      #
      # @param method [Symbol] The method name (label name)
      # @param args [Array] Method arguments (unused for labels)
      #
      # @return [Integer] The label's address or placeholder value
      #
      # @example Accessing labels as methods
      #   label :start
      #   jmp start    # Calls method_missing(:start) -> returns label address
      #
      # @note Falls back to super if the method is not a defined label
      def method_missing(method, *args)
        if @labels&.[](method)
          @labels[method]
        elsif @precompile
          12345
        else
          super
        end
      end
    end
  end
end