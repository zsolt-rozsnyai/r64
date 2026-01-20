require_relative 'base/hooks'
require_relative 'base/dispatch'
require_relative 'base/rendering'

module R64
  class Base < Assembler
    include Hooks
    include Dispatch
    include Rendering

    def initialize(parent=nil)
      @parent = parent
      puts "parent: #{@parent}" if verbose
      super memory: @parent&.memory, processor: @parent&.processor
      @index = self.class.instance_count
      self.class.instance_count += 1
      @rendered = false

      self.class.before.each do |block|
        instance_exec(&block)
      end if self.class.before
    end

    def setup options={}
      processor.set_pc(options[:start])
      processor.start = options[:start]
      memory.start = options[:start]
      memory.finish = options[:end]
      set_entrypoint
    end

    def object_name
      "#{self.class.name}#{@index}"
    end
  end
end