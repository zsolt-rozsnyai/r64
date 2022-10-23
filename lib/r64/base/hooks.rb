module R64
  class Base < Assembler
    module Hooks
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def instance_count
          @instance_count ||= 0
        end

        def instance_count=(value)
          @instance_count = value
        end

        def after_create(&block)
          @after_create ||= []
          return @after_create unless block_given?
          @after_create.push block
        end

        def before(&block)
          @before ||= []
          return @before unless block_given?
          @before.push block
        end

        def after(&block)
          @after ||= []
          return @after unless block_given?
          @after.push block
        end

        def before_compile(&block)
          @before_compile ||= []
          return @before_compile unless block_given?
          @before_compile.push block
        end

        def after_compile(&block)
          @after_compile ||= []
          return @after_compile unless block_given?
          @after_compile.push block
        end
      end

      private

      def run_before_compile
        self.class.before_compile.each do |block|
          instance_exec(&block)
        end if self.class.before_compile
      end

      def run_after_compile
        self.class.after_compile.each do |block|
          instance_exec(&block)
        end if self.class.after_compile
      end
    end
  end
end