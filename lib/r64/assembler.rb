# R64 - Ruby Commodore 64 Assembler
#
# A Ruby-based assembler for the Commodore 64 that provides a DSL for writing
# 6502 assembly code with modern Ruby syntax and features.
#
# == Features
#
# * Full 6502 instruction set support
# * Label management and resolution
# * Breakpoint and debugging support
# * Memory and processor simulation
# * Compilation to PRG format
# * Watch points for debugging
#
# == Usage
#
#   assembler = R64::Assembler.new do
#     # Your assembly code here
#   end
#   assembler.compile!(save: true, debug: true)
#
# == References
#
# * http://www.oxyron.de/html/opcodes02.html - 6502 opcodes reference
# * http://unusedino.de/ec64/technical/aay/c64/bmain.htm - C64 technical reference
# * http://sta.c64.org/cbm64mem.html - C64 memory map
#
# == Debug Tool
#
# * http://csdb.dk/release/?id=100129 - VICE monitor compatible debug output
#
# @author Maxwell of Graffity
# @version 0.2.0

require 'json'
require_relative 'assembler/labels'
require_relative 'assembler/breakpoints'
require_relative 'assembler/compile'
require_relative 'assembler/opcodes'
require_relative 'assembler/utils'

module R64
  # The main Assembler class that provides a Ruby DSL for writing 6502 assembly code.
  #
  # This class combines multiple modules to provide a complete assembler environment:
  # - Labels: Label definition and resolution
  # - Breakpoints: Debugging breakpoints and watch points
  # - Compile: Compilation and output generation
  # - Opcodes: 6502 instruction set implementation
  # - Utils: Utility methods for memory and processor access
  #
  # @example Basic usage
  #   assembler = R64::Assembler.new do
  #     label :start
  #     lda 0x01
  #     sta 0xd020
  #     jmp :start
  #   end
  #   assembler.compile!(save: true)
  #
  # @example With custom options
  #   assembler = R64::Assembler.new(
  #     memory: custom_memory,
  #     processor: custom_processor
  #   )
  class Assembler
    include Labels
    include Breakpoints
    include Compile
    include Opcodes
    include Utils

    # @return [Hash] Configuration options for the assembler
    attr_reader :options
    
    # @return [R64::Memory] Memory instance for the assembler
    attr_reader :memory
    
    # @return [R64::Processor] Processor instance for the assembler
    attr_reader :processor

    # Initialize a new Assembler instance.
    #
    # The assembler can be configured with custom memory and processor instances,
    # character sets, and other options. If a block is provided, it will be
    # executed in the context of the assembler instance.
    #
    # @param options [Hash] Configuration options
    # @option options [R64::Memory] :memory Custom memory instance
    # @option options [R64::Processor] :processor Custom processor instance
    # @option options [Integer] :entrypoint Program entry point address
    # @option options [Integer] :first_byte Starting address for output
    # @option options [Integer] :last_byte Ending address for output
    #
    # @yield Block to execute in the assembler context
    #
    # @example Basic initialization
    #   assembler = R64::Assembler.new
    #
    # @example With options and block
    #   assembler = R64::Assembler.new(entrypoint: 0x1000) do
    #     # Assembly code here
    #   end
    def initialize options={}, &block
      @options = options || {}
      @memory = @options[:memory] || R64::Memory.new(@options)
      @processor = @options[:processor] || R64::Processor.new(@options)
      @pc_start = @processor.pc
      @precompile = true
      instance_exec(&block) if block_given?
    end
  end
end
