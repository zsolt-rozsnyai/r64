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
##
## TODO:
## * test all opcodes
## * overview and update length and cycles data
## * add VIC, SID and CIA helpers
## * create debugger

module R64
  
  class Assembler
  
    require 'json'
    require 'memory'
    require 'vic'
    require 'processor'
  
    DEFAULT_SET_OPTIONS = {
      :load => true,
      :with => :a
    }
    
    ADDRESSES = {
      :nmi => 0xfffa,
      :irq => 0xfffe
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
      :and => {
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
  
    def initialize
      @memory = R64::Memory.new
      @vic = R64::Vic.new
      @processor = R64::Processor.new
    end
    
    ## accessors

    def memory
      @memory.drop(@processor.start)
    end
    
    def processor
      @processor
    end

    ## labeling
    def get_label arg, options={}
      @precompile ? 12345 : @labels[arg] - 1
    end
    
    def label name
      @labels ||= {}
      @labels[name] = @processor.pc + 1
    end
    
    ## store a double
    def address store, what, options={}
      store = ADDRESSES[store] if store.is_a?(Symbol)
      what = get_label what if what.is_a?(Symbol)
      set store, [hi_lo(what)[:lo], options]
      set store, [hi_lo(what)[:hi], options.merge(:hi => true)]
    end
    
    ## Split double
    def hi_lo number
      hi = (number/256).to_i
      lo = number-hi*256
      {:hi => hi, :lo => lo}
    end
    
    ## Extended nop
    def nop number=1
      number.times do
        add_code(:token => :nop, :args => [])
      end
    end
    
    ## irq shortcut
    def irq entry=:irq, options={}
      address :irq, entry, options
    end
    
    ## compiling

    def precompile
      @precompile = true
      main
      @processor.reset_pc
      @precompile = false
    end
    
    def compile!
      puts "1. round --------------------------------"
      precompile
      puts "2. round --------------------------------"
      main
      save!
      puts memory.to_json
    end
    
    def filename
      self.class.name
    end
    
    def save! fn=nil
      fn ||= filename.downcase[0..15]
      File.open( "./prg/#{fn}.prg", 'w' ) do |output|
        start = hi_lo(processor.start)
        output.print start[:lo].chr
        output.print start[:hi].chr
        memory.each do | byte |
          output.print byte.chr
        end
      end
    end
    
    def set register, args=[]
      args = [args] unless args.is_a?(Array)
      options = extract_set_register_options args
      options[:load] = false if options[:args].empty?
      register = register + 1 if options.delete(:hi)
      if options[:with] == :y
        ldy args[0] if options[:load]
        sty register
      elsif options[:with] == :x
        ldx args[0] if options[:load]
        stx register
      else
        lda args[0] if options[:load]
        sta register
      end
    end
    
    def method_missing method, *args
      #TODO: this should be in Vic
      if num = method.to_s.split('spritex')[1]
        _spritex num.to_i, args
      elsif num = method.to_s.split('spritey')[1]
        _spritey num.to_i, args
      ##This is in place:
      elsif OPCODES.has_key? method
        puts "Adding: #{method} --------------------------------------------------"
        add_code(:token => method, :args => args)
      else
        super
      end
    end


private

    def extract_set_register_options args
      options = {}
      args = [args] unless args.is_a?(Array)
      options = args.pop if args.any? && args.last.is_a?(Hash)
      args[0] = get_color args[0] if args.any? && args[0].is_a?(Symbol)
      options[:args] = args
      DEFAULT_SET_OPTIONS.merge(options)
    end  
    
    ## interpret opcodes
    def add_code options
      puts options.to_json
      options = extract_arguments(options) if options[:args]
      options = extract_address(options) if options[:args]
      if OPCODES[options[:token]][:rel]
        options[:type] = :rel
        options[:address] = options[:address] - @processor.pc if options[:address] > 255
      end
      options[:address] = 254+options[:address] if options[:address] && options[:address] < 0
      options[:type] ||= :noop
      puts options.to_json
      opcode = OPCODES[options[:token]][options[:type]]
      @memory[@processor.pc] = opcode[:code]
      @processor.increase_pc
      if opcode[:length] == 2
        @memory[@processor.pc] = options[:address]
        @processor.increase_pc
      elsif opcode[:length] == 3
        hi = (options[:address] / 256).to_i
        lo = options[:address] - (hi*256)
        @memory[@processor.pc] = lo
        @memory[@processor.pc+1] = hi
        @processor.increase_pc 2
      end
    end
    
    def extract_arguments options
      args = options[:args]
      options.merge!(args.pop) if args.any? && args.last.is_a?(Hash)
      options
    end
    
    def extract_address options
      args = options.delete(:args)
      args[0] = get_label(args[0], options) if args[0].is_a?(Symbol)
      options[:address] = args[0] || nil
      if args.length == 1
        if args[0] < 256
          options[:type] = :zp if options[:zeropage]
          options[:type] = :imm unless options[:zeropage]
        else
          options[:type] = :abs unless options[:indirect]
          options[:type] = :ind if options[:indirect]
        end
      elsif args.length == 2
        if args[0] < 256
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
  end
end
