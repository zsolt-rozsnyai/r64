module R64
  class Assembler
    module Labels
      def get_label(arg, options = {})
        @labels ||= {}
        @references ||= {}
        @references[arg] ||= []
        @references[arg].push @processor.pc unless @references[arg].include?(@processor.pc)
        @precompile ? 12345 : @labels[arg] ? @labels[arg] : raise(Exception.new("Label does not exists '#{arg}', #{@labels.to_json}"))
      end

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