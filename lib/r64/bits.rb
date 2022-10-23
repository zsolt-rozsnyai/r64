module R64
  module Bits
    R64::Assembler.class_eval do
      DEFAULT_SET_OPTIONS = {
        :load => true,
        :with => :a
      }
    
      def set register, *args
      puts args.to_json if verbose
        args = [args] unless args.is_a?(Array)
        options = extract_set_register_options args
        options[:load] = false if options[:args].empty?
        register = get_label register if register.is_a?(Symbol) 
        register = register + 1 if options.delete(:hi)
        length = options.delete(:length) || 1
      puts args.to_json if verbose
        if options[:with] == :y
          ldy args[0] if options[:load]
          length.times{|i| sty register+i}
        elsif options[:with] == :x
          ldx args[0] if options[:load]
          length.times{|i| stx register+i}
        else
          lda args[0] if options[:load]
          length.times{|i| sta register+i}
        end
      end
      
      def fill length, *args, &block
        puts "Adding data: #{length} #{args.to_json}" if verbose
        args = [args] unless args.is_a?(Array)
        options = args.delete(args.last) if args && args.last.is_a?(Hash)
        if args.length == 1
          if args[0] > 255 
            address = args[0]
            data = 0
          else
            address = @processor.pc
            data = args[0]
          end
        elsif args.length == 2
          address = args[0]
          data = args[1]
        elsif args.length == 0
          data = 0
          address = @processor.pc
        else
          raise Exception.new("Wrong number of arguments")
        end
        options = (options || {}).merge( {
          :length => length,
          :data => data,
          :address => address
        })
        length.times do |i|
          data = yield(i, options) if block_given?
          add_byte address+i, data
        end
        @processor.increase_pc length if address == @processor.pc
      end
      
      def var name, *args, &block
        args = [args] unless args.is_a?(Array)
        options = args.last && args.last.is_a?(Hash) ? args.delete(args.last) : {} 
        default = args.first && args.first.is_a?(Integer) ? args[0] : 0 
        length = options[:length] || 1
        if args.last == :double
          label name
          label "#{name}_lo".to_sym
          hi = (default.to_f / 256).to_i
          fill 1, default-(hi*256), options
          label "#{name}_hi".to_sym
          fill 1, hi, options
        else
          label name
          fill length, default, options, &block
        end
      end
      
      def data name, arr
        label name
        arr.each do |byte|
          add_byte byte
          @processor.increase_pc
        end
      end
      
      def text name, txt
        data name, txt.split(//).map{|l| l.ord < 64 ? l.ord : l.ord-64 }
      end

      def l name
        get_label name
      end
      
      def copy_with from, to, options={}
        if options[:with] == :x
          ldx from
          stx to
        elsif options[:with] == :y
          ldy from
          sty to
        else
          lda from
          sta to
        end
      end
      
      def extract_set_register_options args
        options = {}
        args = [args] unless args.is_a?(Array)
        options = args.pop if args.any? && args.last.is_a?(Hash)
        args[0] = get_color args[0] if args.any? && args[0].is_a?(Symbol)
        options[:args] = args
        DEFAULT_SET_OPTIONS.merge(options)
      end
      
      def sys entry; end
    end
  end
end
