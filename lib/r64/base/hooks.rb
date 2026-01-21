module R64
  class Base < Assembler
    # Provides lifecycle hook functionality for R64::Base objects.
    #
    # The Hooks module enables classes to register callback blocks that are executed
    # at specific points during the object lifecycle, such as before/after creation,
    # compilation, and rendering. This allows for flexible customization of behavior
    # without modifying the core class methods.
    #
    # == Available Hooks
    #
    # * +before+: Executed during object initialization
    # * +after+: Executed after rendering/compilation
    # * +before_compile+: Executed before compilation starts
    # * +after_compile+: Executed after compilation completes
    #
    # == Usage
    #
    #   class MySprite < R64::Base
    #     before do
    #       puts "Initializing sprite"
    #       @color = 0x01
    #     end
    #
    #     after_compile do
    #       puts "Sprite compiled at #{processor.pc}"
    #     end
    #   end
    #
    # @see R64::Base For the main class that includes this module
    module Hooks
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Class methods added to R64::Base when Hooks module is included.
      #
      # These methods provide the DSL for registering lifecycle hooks and
      # managing instance counting for unique object identification.
      module ClassMethods
        # Gets the current instance count for this class.
        #
        # @return [Integer] The number of instances created for this class
        def instance_count
          @instance_count ||= 0
        end

        # Sets the instance count for this class.
        #
        # @param value [Integer] The new instance count value
        def instance_count=(value)
          @instance_count = value
        end

        # Registers or retrieves before hooks (executed during initialization).
        #
        # @param block [Proc] Optional block to register as a before hook
        # @return [Array<Proc>] Array of registered before hooks
        # @yield Executes the block during object initialization
        def before(&block)
          @before ||= []
          return @before unless block_given?
          @before.push block
        end

        # Registers or retrieves after hooks (executed after rendering).
        #
        # @param block [Proc] Optional block to register as an after hook
        # @return [Array<Proc>] Array of registered after hooks
        # @yield Executes the block after rendering/compilation
        def after(&block)
          @after ||= []
          return @after unless block_given?
          @after.push block
        end

        # Registers or retrieves before_compile hooks.
        #
        # @param block [Proc] Optional block to register as a before_compile hook
        # @return [Array<Proc>] Array of registered before_compile hooks
        # @yield Executes the block before compilation starts
        def before_compile(&block)
          @before_compile ||= []
          return @before_compile unless block_given?
          @before_compile.push block
        end

        # Registers or retrieves after_compile hooks.
        #
        # @param block [Proc] Optional block to register as an after_compile hook
        # @return [Array<Proc>] Array of registered after_compile hooks
        # @yield Executes the block after compilation completes
        def after_compile(&block)
          @after_compile ||= []
          return @after_compile unless block_given?
          @after_compile.push block
        end
      end

      private

      # Executes all registered before_compile hooks.
      #
      # This method is called internally before compilation begins to run
      # any setup code registered via the before_compile class method.
      #
      # @api private
      def run_before_compile
        self.class.before_compile.each do |block|
          instance_exec(&block)
        end if self.class.before_compile
      end

      # Executes all registered after_compile hooks.
      #
      # This method is called internally after compilation completes to run
      # any cleanup or post-processing code registered via the after_compile class method.
      #
      # @api private
      def run_after_compile
        self.class.after_compile.each do |block|
          instance_exec(&block)
        end if self.class.after_compile
      end
    end
  end
end