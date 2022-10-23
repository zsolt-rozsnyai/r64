## R64 alias Ruby Commodore 64 Assembler
## Version 0.1
##
## By Maxwell of Graffity
##
## References:
## * http://www.oxyron.de/html/opcodes02.html
## * http://unusedino.de/ec64/technical/aay/c64/bmain.htm
## * http://sta.c64.org/cbm64mem.html
##
## Debug Tool:
## * http://csdb.dk/release/?id=100129

require 'json'
require_relative 'assembler/labels'
require_relative 'assembler/breakpoints'
require_relative 'assembler/compile'
require_relative 'assembler/opcodes'
require_relative 'assembler/utils'

module R64
  class Assembler
    include Labels
    include Breakpoints
    include Compile
    include Opcodes
    include Utils


    def initialize options={}
      @options = options || {}
      @charsets = @options[:charsets] || {}
      @memory = @options[:memory] || R64::Memory.new(@options)
      @processor = @options[:processor] || R64::Processor.new(@options)
      @pc_start = @processor.pc
      @precompile = true
      yield if block_given?
    end
  end
end
