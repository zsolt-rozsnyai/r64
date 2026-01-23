module R64
  class Assembler
    # 6502 instruction set implementation module for the R64 assembler.
    #
    # This module provides the complete 6502 instruction set with all addressing
    # modes, cycle counts, and instruction lengths. It dynamically generates
    # methods for each instruction, allowing natural assembly syntax within Ruby.
    #
    # == Features
    #
    # * Complete 6502 instruction set (56 instructions)
    # * All addressing modes (immediate, zero page, absolute, indexed, indirect)
    # * Accurate cycle counts and instruction lengths
    # * Automatic method generation for all opcodes
    # * Branch instruction range validation
    # * Predefined system addresses (vectors)
    #
    # == Addressing Modes
    #
    # * :imm - Immediate (#$nn)
    # * :zp - Zero Page ($nn)
    # * :zpx - Zero Page,X ($nn,X)
    # * :zpy - Zero Page,Y ($nn,Y)
    # * :abs - Absolute ($nnnn)
    # * :abx - Absolute,X ($nnnn,X)
    # * :aby - Absolute,Y ($nnnn,Y)
    # * :izx - Indexed Indirect (($nn,X))
    # * :izy - Indirect Indexed (($nn),Y)
    # * :ind - Indirect (($nnnn))
    # * :rel - Relative (branch instructions)
    # * :noop - Implied/No operand
    #
    # == Usage
    #
    #   # Load instructions
    #   lda 0x01        # LDA #$01 (immediate)
    #   lda 0x80        # LDA $80 (zero page)
    #   lda 0x1000      # LDA $1000 (absolute)
    #   
    #   # Store instructions
    #   sta 0xd020      # STA $D020 (border color)
    #   
    #   # Branch instructions
    #   bne :loop       # BNE loop (relative)
    #   
    #   # System instructions
    #   jsr :subroutine # JSR subroutine
    #   rts             # RTS (no operand)
    #
    # @author Maxwell of Graffity
    # @version 0.2.0
    module Opcodes
      # Predefined system addresses for common 6502 vectors.
      #
      # These addresses represent important system vectors in the 6502
      # memory map, particularly for interrupt handling.
      #
      # @example Using system addresses
      #   address(:nmi, :nmi_handler)  # Store NMI vector
      #   address(:irq, :irq_handler)  # Store IRQ vector
      ADDRESSES = {
        :nmi => 0xfffa,  # Non-Maskable Interrupt vector
        :irq => 0xfffe   # Interrupt Request vector
      }

      OPCODES = {
        ##Logical, arithmetical
        :ora => {
          :imm => {:code => 0x09, :length => 2, :cycles => 2},
          :zp  => {:code => 0x05, :length => 2, :cycles => 3},
          :zpx => {:code => 0x15, :length => 2, :cycles => 4},
          :izx => {:code => 0x01, :length => 3, :cycles => 3},
          :izy => {:code => 0x11, :length => 3, :cycles => 3},
          :abs => {:code => 0x0d, :length => 3, :cycles => 3},
          :abx => {:code => 0x1d, :length => 3, :cycles => 3},
          :aby => {:code => 0x19, :length => 3, :cycles => 3}
        },
        :ana => {
          :imm => {:code => 0x29, :length => 2, :cycles => 2},
          :zp  => {:code => 0x25, :length => 2, :cycles => 3},
          :zpx => {:code => 0x35, :length => 2, :cycles => 4},
          :izx => {:code => 0x21, :length => 3, :cycles => 3},
          :izy => {:code => 0x31, :length => 3, :cycles => 3},
          :abs => {:code => 0x2d, :length => 3, :cycles => 3},
          :abx => {:code => 0x3d, :length => 3, :cycles => 3},
          :aby => {:code => 0x39, :length => 3, :cycles => 3}
        },
        :eor => {
          :imm => {:code => 0x49, :length => 2, :cycles => 2},
          :zp  => {:code => 0x45, :length => 2, :cycles => 3},
          :zpx => {:code => 0x55, :length => 2, :cycles => 4},
          :izx => {:code => 0x41, :length => 3, :cycles => 3},
          :izy => {:code => 0x51, :length => 3, :cycles => 3},
          :abs => {:code => 0x4d, :length => 3, :cycles => 3},
          :abx => {:code => 0x5d, :length => 3, :cycles => 3},
          :aby => {:code => 0x59, :length => 3, :cycles => 3}
        },
        :adc => {
          :imm => {:code => 0x69, :length => 2, :cycles => 2},
          :zp  => {:code => 0x65, :length => 2, :cycles => 3},
          :zpx => {:code => 0x75, :length => 2, :cycles => 4},
          :izx => {:code => 0x61, :length => 3, :cycles => 3},
          :izy => {:code => 0x71, :length => 3, :cycles => 3},
          :abs => {:code => 0x6d, :length => 3, :cycles => 3},
          :abx => {:code => 0x7d, :length => 3, :cycles => 3},
          :aby => {:code => 0x79, :length => 3, :cycles => 3}
        },
        :sbc => {
          :imm => {:code => 0xe9, :length => 2, :cycles => 2},
          :zp  => {:code => 0xe5, :length => 2, :cycles => 3},
          :zpx => {:code => 0xf5, :length => 2, :cycles => 4},
          :izx => {:code => 0xe1, :length => 3, :cycles => 3},
          :izy => {:code => 0xf1, :length => 3, :cycles => 3},
          :abs => {:code => 0xed, :length => 3, :cycles => 3},
          :abx => {:code => 0xfd, :length => 3, :cycles => 3},
          :aby => {:code => 0xf9, :length => 3, :cycles => 3}
        },
        :cmp => {
          :imm => {:code => 0xc9, :length => 2, :cycles => 2},
          :zp  => {:code => 0xc5, :length => 2, :cycles => 3},
          :zpx => {:code => 0xd5, :length => 2, :cycles => 4},
          :izx => {:code => 0xc1, :length => 3, :cycles => 3},
          :izy => {:code => 0xd1, :length => 3, :cycles => 3},
          :abs => {:code => 0xcd, :length => 3, :cycles => 3},
          :abx => {:code => 0xdd, :length => 3, :cycles => 3},
          :aby => {:code => 0xd9, :length => 3, :cycles => 3}
        },
        :cpx => {
          :imm => {:code => 0xe0, :length => 2, :cycles => 2},
          :zp  => {:code => 0xe4, :length => 2, :cycles => 3},
          :abs => {:code => 0xec, :length => 3, :cycles => 3}
        },
        :cpy => {
          :imm => {:code => 0xc0, :length => 2, :cycles => 2},
          :zp  => {:code => 0xc4, :length => 2, :cycles => 3},
          :abs => {:code => 0xcc, :length => 3, :cycles => 3}
        },
        :dec => {
          :zp  => {:code => 0xc6, :length => 2, :cycles => 3},
          :zpx => {:code => 0xd6, :length => 2, :cycles => 4},
          :abs => {:code => 0xce, :length => 3, :cycles => 3},
          :abx => {:code => 0xde, :length => 3, :cycles => 3}
        },
        :inc => {
          :zp  => {:code => 0xe6, :length => 2, :cycles => 3},
          :zpx => {:code => 0xf6, :length => 2, :cycles => 4},
          :abs => {:code => 0xee, :length => 3, :cycles => 3},
          :abx => {:code => 0xfe, :length => 3, :cycles => 3}
        },
        :dex => {:noop => {:code => 0xca, :length => 1, :cycles => 6}},
        :dey => {:noop => {:code => 0x88, :length => 1, :cycles => 6}},
        :inx => {:noop => {:code => 0xe8, :length => 1, :cycles => 6}},
        :iny => {:noop => {:code => 0xc8, :length => 1, :cycles => 6}},
        :asl => {
          :noop => {:code => 0x0a, :length => 1, :cycles => 6},
          :zp  => {:code => 0x06, :length => 2, :cycles => 3},
          :zpx => {:code => 0x16, :length => 2, :cycles => 4},
          :abs => {:code => 0x0e, :length => 3, :cycles => 3},
          :abx => {:code => 0x1e, :length => 3, :cycles => 3}
        },
        :rol => {
          :noop => {:code => 0x2a, :length => 1, :cycles => 6},
          :zp  => {:code => 0x26, :length => 2, :cycles => 3},
          :zpx => {:code => 0x36, :length => 2, :cycles => 4},
          :abs => {:code => 0x2e, :length => 3, :cycles => 3},
          :abx => {:code => 0x3e, :length => 3, :cycles => 3}
        },
        :lsr => {
          :noop => {:code => 0x4a, :length => 1, :cycles => 6},
          :zp  => {:code => 0x46, :length => 2, :cycles => 3},
          :zpx => {:code => 0x56, :length => 2, :cycles => 4},
          :abs => {:code => 0x4e, :length => 3, :cycles => 3},
          :abx => {:code => 0x5e, :length => 3, :cycles => 3}
        },
        :ror => {
          :noop => {:code => 0x6a, :length => 1, :cycles => 6},
          :zp  => {:code => 0x66, :length => 2, :cycles => 3},
          :zpx => {:code => 0x76, :length => 2, :cycles => 4},
          :abs => {:code => 0x6e, :length => 3, :cycles => 3},
          :abx => {:code => 0x7e, :length => 3, :cycles => 3}
        },
        ## Move
        :lda => {
          :imm => {:code => 0xa9, :length => 2, :cycles => 2},
          :zp  => {:code => 0xa5, :length => 2, :cycles => 3},
          :zpx => {:code => 0xb5, :length => 2, :cycles => 4},
          :izx => {:code => 0xa1, :length => 3, :cycles => 3},
          :izy => {:code => 0xb1, :length => 3, :cycles => 3},
          :abs => {:code => 0xad, :length => 3, :cycles => 3},
          :abx => {:code => 0xbd, :length => 3, :cycles => 3},
          :aby => {:code => 0xb9, :length => 3, :cycles => 3}
        },
        :sta => {
          :zp  => {:code => 0x85, :length => 2, :cycles => 2},
          :zpx => {:code => 0x95, :length => 2, :cycles => 2},
          :izx => {:code => 0x81, :length => 3, :cycles => 3},
          :izy => {:code => 0x91, :length => 3, :cycles => 3},
          :abs => {:code => 0x8d, :length => 3, :cycles => 3},
          :abx => {:code => 0x9d, :length => 3, :cycles => 3},
          :aby => {:code => 0x99, :length => 3, :cycles => 3}
        },
        :ldx => {
          :imm => {:code => 0xa2, :length => 2, :cycles => 2},
          :zp  => {:code => 0xa6, :length => 2, :cycles => 3},
          :zpy => {:code => 0xb6, :length => 2, :cycles => 4},
          :abs => {:code => 0xae, :length => 3, :cycles => 3},
          :aby => {:code => 0xbe, :length => 3, :cycles => 3}
        },
        :stx => {
          :zp  => {:code => 0x86, :length => 2, :cycles => 2},
          :zpy => {:code => 0x96, :length => 2, :cycles => 2},
          :abs => {:code => 0x8e, :length => 3, :cycles => 3}
        },
        :ldy => {
          :imm => {:code => 0xa0, :length => 2, :cycles => 2},
          :zp  => {:code => 0xa4, :length => 2, :cycles => 3},
          :zpx => {:code => 0xb4, :length => 2, :cycles => 4},
          :abs => {:code => 0xac, :length => 3, :cycles => 3},
          :abx => {:code => 0xbc, :length => 3, :cycles => 3}
        },
        :sty => {
          :zp  => {:code => 0x84, :length => 2, :cycles => 2},
          :zpx => {:code => 0x94, :length => 2, :cycles => 2},
          :abs => {:code => 0x8c, :length => 3, :cycles => 3}
        },
        :tax => {:noop => {:code => 0xaa, :length => 1, :cycles => 6}},
        :txa => {:noop => {:code => 0x8a, :length => 1, :cycles => 6}},
        :tay => {:noop => {:code => 0xa8, :length => 1, :cycles => 6}},
        :tya => {:noop => {:code => 0x98, :length => 1, :cycles => 6}},
        :tsx => {:noop => {:code => 0xba, :length => 1, :cycles => 6}},
        :txs => {:noop => {:code => 0x9a, :length => 1, :cycles => 6}},
        :pla => {:noop => {:code => 0x68, :length => 1, :cycles => 6}},
        :pha => {:noop => {:code => 0x48, :length => 1, :cycles => 6}},
        :plp => {:noop => {:code => 0x28, :length => 1, :cycles => 6}},
        :php => {:noop => {:code => 0x08, :length => 1, :cycles => 6}},

        ## Jump
        :bpl => {:rel => {:code => 0x10, :length => 2, :cycles => 6}},
        :bmi => {:rel => {:code => 0x30, :length => 2, :cycles => 6}},
        :bvc => {:rel => {:code => 0x50, :length => 2, :cycles => 6}},
        :bvs => {:rel => {:code => 0x70, :length => 2, :cycles => 6}},
        :bcc => {:rel => {:code => 0x90, :length => 2, :cycles => 6}},
        :bcs => {:rel => {:code => 0xb0, :length => 2, :cycles => 6}},
        :bne => {:rel => {:code => 0xd0, :length => 2, :cycles => 6}},
        :beq => {:rel => {:code => 0xf0, :length => 2, :cycles => 6}},

        :jsr => {:abs => {:code => 0x20, :length => 3, :cycles => 6}},
        :jmp => {
          :abs => {:code => 0x4c, :length => 3, :cycles => 3},
          :ind => {:code => 0x6c, :length => 3, :cycles => 3}
        },
        :bit => {
          :zp  => {:code => 0x24, :length => 2, :cycles => 2},
          :abs => {:code => 0x2c, :length => 3, :cycles => 3}
        },
        :rts => {:noop => {:code => 0x60, :length => 1, :cycles => 6}},
        :rti => {:noop => {:code => 0x40, :length => 1, :cycles => 6}},

        ## Flags
        :cli => {:noop => {:code => 0x58, :length => 1, :cycles => 2}},
        :sei => {:noop => {:code => 0x78, :length => 1, :cycles => 2}},
        :clc => {:noop => {:code => 0x18, :length => 1, :cycles => 2}},
        :sec => {:noop => {:code => 0x38, :length => 1, :cycles => 2}},
        :cld => {:noop => {:code => 0xd8, :length => 1, :cycles => 2}},
        :sed => {:noop => {:code => 0xf8, :length => 1, :cycles => 2}},
        :clv => {:noop => {:code => 0xb8, :length => 1, :cycles => 2}},
        :nop => {:noop => {:code => 0xea, :length => 1, :cycles => 1}}
      }

      # Dynamically creates methods for all 6502 instructions when module is included.
      #
      # This hook method automatically generates a Ruby method for each instruction
      # in the OPCODES hash when the module is included in a class. Each generated
      # method accepts arguments and calls add_code to generate the appropriate
      # machine code.
      #
      # @param base [Class] The class that is including this module
      #
      # @example Generated methods
      #   # After inclusion, these methods become available:
      #   lda(0x01)     # Calls add_code(token: :lda, args: [0x01])
      #   sta(0xd020)   # Calls add_code(token: :sta, args: [0xd020])
      #   jmp(:loop)    # Calls add_code(token: :jmp, args: [:loop])
      #
      # @note This creates 56 instruction methods covering the complete 6502 instruction set
      def self.included(base)
        OPCODES.each_key do |opcode|
          base.class_eval do
            define_method(opcode) do |*args|
              add_code(token: opcode, args: args)
            end
          end
        end
      end

    private

      # Generates machine code for a 6502 instruction.
      #
      # This method handles the complex process of converting high-level instruction
      # calls into actual 6502 machine code. It determines the appropriate addressing
      # mode, handles operand encoding, validates branch ranges, and outputs the
      # correct opcodes and operands.
      #
      # @param options [Hash] Instruction options
      # @option options [Symbol] :token The instruction mnemonic
      # @option options [Array] :args The instruction arguments
      # @option options [Symbol] :type The addressing mode (determined automatically)
      # @option options [Integer] :address The operand address/value
      #
      # @private
      def add_code(options)
        options = extract_arguments(options) if options[:args]
        options = extract_address(options) if options[:args]
        if OPCODES[options[:token]][:rel]
          options[:type] = :rel
          puts options[:address] if verbose
          options[:address] = options[:address] - (@processor.pc + 2)
          puts options[:address] if verbose
          raise Exception.new('Branch out of range') if !@precompile && (options[:address] > 127 || options[:address] < -128)
          options[:address] = 256 + options[:address] if options[:address] < 0
          puts options[:address] if verbose
        end
        options[:type] ||= :noop
        opcode = OPCODES[options[:token]][options[:type]]
        add_byte opcode[:code]
        @processor.increase_pc
        if opcode[:length] == 2
          add_byte options[:address]
          @processor.increase_pc
        elsif opcode[:length] == 3
          hi = (options[:address] / 256).to_i
          lo = options[:address] - (hi * 256)
          add_byte lo
          @processor.increase_pc
          add_byte hi
          @processor.increase_pc
        end
      end

      # Writes a byte value to memory at the current PC or specified address.
      #
      # This method handles writing byte values to memory with proper caller context
      # tracking for debugging and memory ownership. It supports two calling modes:
      # writing to the current program counter location or to a specific address.
      #
      # @param args [Array] Variable arguments for byte writing
      #   - Single argument: writes byte to current PC location
      #   - Two arguments: writes byte to specified address
      #
      # @example Writing to current PC
      #   add_byte(0x42)        # Writes 0x42 to current PC
      #   add_byte(255)         # Writes 255 to current PC
      #
      # @example Writing to specific address
      #   add_byte(0x1000, 0x42)  # Writes 0x42 to address $1000
      #   add_byte(4096, 255)     # Writes 255 to address 4096
      #
      # @raise [Exception] If wrong number of arguments provided (not 1 or 2)
      #
      # @note Uses R64::Memory.with_caller to properly track the calling object
      #   for debugging and memory ownership purposes.
      #
      # @see R64::Memory.with_caller For caller context management
      def add_byte(*args)
        args = [args] unless args.is_a?(Array)
        
        # Use with_caller to properly identify the calling R64::Base object
        R64::Memory.with_caller(self) do
          if args.length == 1
            @memory[@processor.pc] = args[0].to_i
          elsif args.length == 2
            @memory[args[0]] = args[1].to_i
          else
            raise Exception.new("Wrong number of arguments")
          end
        end
      end

      # Extracts and processes arguments from the options hash for opcode generation.
      #
      # This method handles the common pattern where the last argument in an instruction
      # call might be a hash of options (like :zeropage, :indirect, etc.). If the last
      # argument is a hash, it merges those options into the main options hash.
      #
      # @param options [Hash] The options hash containing instruction arguments and flags
      # @option options [Array] :args Array of arguments passed to the instruction
      #
      # @return [Hash] Modified options hash with extracted argument options merged in
      #
      # @example Basic usage
      #   # For instruction: lda 0x42, zeropage: true
      #   options = { args: [0x42, { zeropage: true }] }
      #   result = extract_arguments(options)
      #   # => { args: [0x42, { zeropage: true }], zeropage: true }
      #
      # @example Without hash argument
      #   # For instruction: lda 0x42
      #   options = { args: [0x42] }
      #   result = extract_arguments(options)
      #   # => { args: [0x42] }
      #
      # @note This method modifies the original options hash by merging in any
      #   hash-based arguments, enabling flexible instruction syntax.
      def extract_arguments(options)
        args = options[:args]
        options.merge!(args.pop) if args.any? && args.last.is_a?(Hash)
        options
      end

      # Extracts address information and determines the appropriate addressing mode.
      #
      # This method processes instruction arguments to determine the correct 6502
      # addressing mode based on the address value, register usage, and instruction
      # flags. It handles label resolution and automatically selects the most
      # appropriate addressing mode for the given arguments.
      #
      # @param options [Hash] The options hash containing instruction arguments and flags
      # @option options [Array] :args Array of arguments (address, registers)
      # @option options [Boolean] :zeropage Force zero page addressing mode
      # @option options [Boolean] :indirect Use indirect addressing mode
      #
      # @return [Hash] Modified options hash with :address and :type set
      #
      # @example Immediate/Zero Page addressing
      #   # For: lda 0x42
      #   options = { args: [0x42] }
      #   result = extract_address(options)
      #   # => { address: 0x42, type: :imm }
      #
      # @example Absolute addressing
      #   # For: lda 0x1000
      #   options = { args: [0x1000] }
      #   result = extract_address(options)
      #   # => { address: 0x1000, type: :abs }
      #
      # @example Indexed addressing
      #   # For: lda 0x42, :x
      #   options = { args: [0x42, :x] }
      #   result = extract_address(options)
      #   # => { address: 0x42, type: :zpx }
      #
      # @example Indirect addressing
      #   # For: jmp 0x1000, indirect: true
      #   options = { args: [0x1000], indirect: true }
      #   result = extract_address(options)
      #   # => { address: 0x1000, type: :ind }
      #
      # @example Label resolution
      #   # For: lda :my_label
      #   options = { args: [:my_label] }
      #   result = extract_address(options)
      #   # => { address: <resolved_address>, type: <determined_type> }
      #
      # @note The method automatically determines addressing modes:
      #   - Values < 256: Zero page (:zp) or immediate (:imm)
      #   - Values >= 256: Absolute (:abs) or indirect (:ind)
      #   - With X/Y registers: Indexed modes (:zpx, :zpy, :abx, :aby)
      #   - With indirect flag: Indirect modes (:ind, :izx, :izy)
      #
      # @see #get_label For label resolution functionality
      def extract_address(options)
        puts options.to_json if verbose
        args = options.delete(:args)
        args[0] = get_label(args[0], options) if args[0].is_a?(Symbol)
        options[:address] = args[0] || nil
        if args.length == 1
          if options[:zeropage]
            # Force zero page addressing when explicitly requested
            options[:type] = :zp
          elsif args[0] < 256
            options[:type] = :imm
          else
            options[:type] = :abs unless options[:indirect]
            options[:type] = :ind if options[:indirect]
          end
        elsif args.length == 2
          if options[:zeropage]
            # Force zero page indexed addressing when explicitly requested
            if options[:indirect]
              options[:type] = :izx if args[1] == :x
              options[:type] = :izy if args[1] == :y
            else
              options[:type] = :zpx if args[1] == :x
              options[:type] = :zpy if args[1] == :y
            end
          elsif args[0] < 256
            if options[:indirect]
              options[:type] = :izx if args[1] == :x
              options[:type] = :izy if args[1] == :y
            else
              options[:type] = :zpx if args[1] == :x
              options[:type] = :zpy if args[1] == :y
            end
          else
            options[:type] = :abx if args[1] == :x
            options[:type] = :aby if args[1] == :y
          end
        end
        options
      end

      def verbose
        false
      end
    end
  end
end