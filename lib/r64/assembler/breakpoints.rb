module R64
  class Assembler
    module Breakpoints
      def break_pc
        add_breakpoint 'breakonpc', @processor.pc.to_s(16)
      end

      def break_mem(address, condition)
        add_breakpoint 'breakmem', "#{address.to_s(16)}#{condition}"
      end

      def break_raster(raster)
        add_breakpoint 'breakraster', raster
      end

      def add_breakpoint(type, params)
        return if @precompile

        @breakpoints ||= []
        @breakpoints.push({
          type: type,
          params: params
        })
      end

      def watch(what = nil)
        return if @precompile

        what ||= processor.pc

        watcher = if what.is_a? Symbol
          {
            label: what,
            address: @labels[what].to_s(16)
          }
        else
          {
            label: "addr_#{what.to_s(16)}",
            address: what.to_s(16)
          }
        end

        @watchers ||= []
        @watchers.push(watcher)
      end
    end
  end
end