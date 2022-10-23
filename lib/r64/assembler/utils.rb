module R64
  class Assembler
    module Utils
      def resources
        { processor: @processor, memory: @memory }
      end

      def memory
        @memory
      end

      def processor
        @processor
      end

      def address(store, what, options = {})
        store = Opcodes::ADDRESSES[store] if store.is_a?(Symbol) && defined?(Opcodes::ADDRESSES)
        store = ADDRESSES[store] if store.is_a?(Symbol) && defined?(ADDRESSES)
        what = get_label what if what.is_a?(Symbol)
        set store, hi_lo(what)[:lo], options
        set store, hi_lo(what)[:hi], options.merge(hi: true)
      end

      def hi_lo(number)
        raise Exception.new("Number out of range") if number > 65_535 || number < 0
        hi = (number / 256).to_i
        lo = number - hi * 256
        { hi: hi, lo: lo }
      end

      def nop(number = 1)
        number.times do
          add_code(token: :nop, args: [])
        end
      end

      def irq(entry = :irq, options = {})
        address :irq, entry, options
      end

      def clear_memory(options)
        @memory.clear options
      end

      def compile(*args, &block)
        instance_exec(*args, &block)
      end

      def self.included(base)
        base.define_singleton_method(:descendants) do
          ObjectSpace.each_object(Class).select { |klass| klass < self }
        end
      end
    end
  end
end