module R64
  class Base < Assembler
    module Dispatch
      def method_missing(method, *args, &block)
        underscored = "_#{method}".to_sym
        if class_instance_methods.include?(underscored)
          if args.include?(:inline) ||
             respond_to?(:inline_methods) &&
             (inline_methods.include?(underscored) || inline_methods.include?(:method))
            self.send(underscored)
          else
            jsr underscored
          end
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        underscored = "_#{method}".to_sym
        class_instance_methods.include?(underscored) || super
      end

      private

      def class_instance_methods
        methods = []
        current_class = self.class
        
        # Traverse inheritance chain until we reach R64::Base
        while current_class && current_class != R64::Base
          methods.concat(current_class.instance_methods(false))
          current_class = current_class.superclass
        end
        
        # Include methods from R64::Base itself
        methods.concat(R64::Base.instance_methods(false)) if self.class != R64::Base
        
        methods.uniq
      end
    end
  end
end