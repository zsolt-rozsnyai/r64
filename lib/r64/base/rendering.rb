module R64
  class Base < Assembler
    module Rendering
      def to_code
        render_instance!
      end

      def main
        to_binary
      end

      def to_binary
        render_instance!

        self.class.after.each do |block|
          instance_exec(&block)
        end if self.class.after
      end

      private

      def render_underscored_methods
        underscored_methods.each do |m|
          next if respond_to?(:inline_methods) && inline_methods.include?(m)
          label m
          self.send(m)
          rts
        end
      end

      def render_variables
        variables if respond_to?(:variables)
      end

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

      def run_compile
        run_before_compile
        render_variables
        render_underscored_methods
        run_after_compile
      end

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

      def underscored_methods
        @underscored_methods ||= class_instance_methods
          .select { |m| m.to_s.start_with?("_") }
          .sort { |a, b| a.to_s <=> b.to_s }
      end

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