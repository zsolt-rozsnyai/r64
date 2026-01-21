module R64
  class Base < Assembler
    # Provides code generation and binary output functionality for R64::Base objects.
    #
    # The Rendering module handles the compilation and output generation process,
    # including rendering underscored methods as subroutines, managing child objects,
    # executing lifecycle hooks, and generating binary output for Commodore 64.
    #
    # == Rendering Process
    #
    # The rendering process uses a two-pass compilation system for forward reference resolution:
    #
    # === Pass 1 (Precompile Phase):
    # 1. Execute before_compile hooks
    # 2. Render variables (if defined)
    # 3. Render underscored methods as labeled subroutines
    # 4. Execute after_compile hooks
    # 5. Render child objects
    #
    # === Pass 2 (Final Compilation):
    # 6. Reset processor to instance start address
    # 7. Re-execute before_compile hooks
    # 8. Re-render variables (if defined)
    # 9. Re-render underscored methods with resolved addresses
    # 10. Re-execute after_compile hooks
    # 11. Execute after hooks (only in final pass)
    #
    # == Usage
    #
    #   class MyScreen < R64::Base
    #     def _set_bg_color
    #       lda :color
    #       sta 0xd020
    #     end
    #
    #     def variables
    #       var :color, 0x01
    #     end
    #   end
    #
    #   screen = MyScreen.new
    #   binary_data = screen.to_binary  # Renders and returns binary
    #
    # @see R64::Base For the main class that includes this module
    # @see R64::Base::Hooks For lifecycle hook functionality
    module Rendering
      # Alias for to_binary, provides the main entry point for binary generation.
      #
      # @return [Object] Binary representation of the rendered code
      # @see #to_binary
      def main
        to_binary
      end

      # Renders the instance and executes after hooks to generate binary output.
      #
      # This is the primary method for generating the final binary representation
      # of the assembly code. It performs the full rendering process including
      # all lifecycle hooks.
      #
      # @return [Object] Binary representation of the rendered code
      def to_binary
        render_instance!

        self.class.after.each do |block|
          instance_exec(&block)
        end if self.class.after
      end

      private

      # Renders all underscored methods as labeled subroutines.
      #
      # This method iterates through all underscored methods in the class
      # and renders them as assembly subroutines with labels and RTS instructions,
      # unless they are marked as inline methods.
      #
      # @api private
      def render_underscored_methods
        underscored_methods.each do |m|
          next if respond_to?(:inline_methods) && inline_methods.include?(m)
          label m
          self.send(m)
          rts
        end
      end

      # Renders variables if the variables method is defined.
      #
      # This method calls the variables method if it exists, allowing
      # classes to define data variables that will be included in the output.
      #
      # @api private
      def render_variables
        variables if respond_to?(:variables)
      end

      # Renders child objects stored in instance variables.
      #
      # This method looks for instance variables that start with "@_" and
      # calls to_binary on them if they respond to it. This enables hierarchical
      # composition where child objects are automatically rendered.
      #
      # @api private
      def render_children
        instance_variables.each do |iv|
          next unless iv.start_with?("@_")

          value = instance_variable_get(iv)

          if value.is_a?(Array)
            value.each do |i|
              i.to_binary if i.respond_to?(:to_binary)
            end
          else
            value.to_binary if value.respond_to?(:to_binary)
          end
        end
      end

      # Executes the compilation process in the correct order.
      #
      # This method orchestrates the compilation by calling the rendering
      # methods in the proper sequence with lifecycle hooks.
      #
      # @api private
      def run_compile
        run_before_compile
        render_variables
        render_underscored_methods
        run_after_compile
      end

      # Performs the complete instance rendering process using two-pass compilation.
      #
      # This is the core rendering method that implements the two-pass compilation
      # system described in the module documentation. The first pass (precompile)
      # establishes labels and calculates sizes, while the second pass generates
      # the final code with resolved forward references.
      #
      # The method:
      # 1. Records the starting processor address
      # 2. Executes Pass 1 (precompile) - run_compile + render_children
      # 3. Sets @precompile = false to indicate final compilation phase
      # 4. Resets processor to start address for Pass 2
      # 5. Executes Pass 2 (final) - run_compile again with resolved references
      # 6. Records the ending address and restores processor state
      # 7. Outputs debugging information if verbose mode is enabled
      #
      # @api private
      def render_instance!
        @instance_start = processor.pc
        run_compile
        render_children

        @precompile = false

        processor_save = @processor.pc
        @processor.set_pc @instance_start

        run_compile

        @instance_end = processor.pc
        @processor.set_pc processor_save

        puts "References for #{self.class.name}##{@index}: #{references_to_print.to_json}" if verbose
        puts "Location for #{self.class.name}##{@index}: #{@instance_start.to_s(16).upcase} - #{(@instance_end - 1).to_s(16).upcase}"
      end

      # Returns a sorted list of underscored methods for this class.
      #
      # This method filters the class instance methods to find those that
      # start with an underscore, which are treated as assembly subroutines.
      # The methods are sorted alphabetically for consistent output.
      #
      # @return [Array<Symbol>] Sorted array of underscored method names
      # @api private
      def underscored_methods
        @underscored_methods ||= class_instance_methods
          .select { |m| m.to_s.start_with?("_") }
          .sort { |a, b| a.to_s <=> b.to_s }
      end

      # Formats references for debugging output.
      #
      # This method converts memory addresses in the references hash to
      # hexadecimal strings for readable debugging output.
      #
      # @return [Hash] Hash of references with addresses formatted as hex strings
      # @api private
      def references_to_print
        references_to_print = @references.dup || {}
        references_to_print.each_key do |k|
          references_to_print[k] = references_to_print[k].map { |i| "0x#{i.to_s(16).upcase}" }
        end
        references_to_print
      end
    end
  end
end