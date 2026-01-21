module R64
  class Base < Assembler
    # Provides method dispatch functionality for calling assembly subroutines.
    #
    # The Dispatch module implements a method_missing mechanism that allows calling
    # assembly methods without the underscore prefix. It automatically determines
    # whether to call methods inline or as subroutines (JSR) based on configuration
    # and method arguments.
    #
    # == Method Naming Convention
    #
    # Assembly methods should be defined with an underscore prefix (e.g., +_draw+)
    # and can be called without the prefix (e.g., +draw+). The dispatch system
    # will automatically:
    #
    # * Call the method inline if +:inline+ is passed as an argument
    # * Call the method inline if it's listed in +inline_methods+
    # * Call the method as a subroutine (JSR) otherwise
    #
    # == Usage
    #
    #   class MyScreen < R64::Base
    #     def _to_black
    #       lda 0x00
    #       sta 0xd020
    #     end
    #
    #     def _to_white
    #       lda 0x01
    #       sta 0xd020
    #     end
    #
    #     def inline_methods
    #       [:_to_black]  # will always be called inline
    #     end
    #   end
    #
    #   screen = MyScreen.new
    #   screen.to_black          # Renders _to_black inline
    #   screen.to_white          # Renders a JSR to _to_white subroutine
    #   screen.to_white(:inline) # Renders _to_white inline (due to :inline argument)
    #
    # @see R64::Base For the main class that includes this module
    module Dispatch
      # Handles method dispatch for assembly subroutines.
      #
      # This method intercepts calls to undefined methods and checks if there's
      # a corresponding underscored method (e.g., +draw+ -> +_draw+). If found,
      # it calls the method either inline or as a JSR subroutine based on the
      # arguments and configuration.
      #
      # @param method [Symbol] The method name being called
      # @param args [Array] Arguments passed to the method
      # @param block [Proc] Block passed to the method (unused)
      # @return [Object] Result of the method call
      # @raise [NoMethodError] If no corresponding underscored method exists
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

      # Checks if the object responds to a method via the dispatch system.
      #
      # This method is called by Ruby's respond_to? mechanism to determine
      # if an object can handle a particular method call. It checks for
      # corresponding underscored methods in the class hierarchy.
      #
      # @param method [Symbol] The method name to check
      # @param include_private [Boolean] Whether to include private methods
      # @return [Boolean] True if the object can respond to the method
      def respond_to_missing?(method, include_private = false)
        underscored = "_#{method}".to_sym
        class_instance_methods.include?(underscored) || super
      end

      private

      # Collects all instance methods from the class hierarchy.
      #
      # This method traverses the inheritance chain up to R64::Base and
      # collects all instance methods defined in each class. This is used
      # to determine which underscored methods are available for dispatch.
      #
      # @return [Array<Symbol>] Array of method names available for dispatch
      # @api private
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