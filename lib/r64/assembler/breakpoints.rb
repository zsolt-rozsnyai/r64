module R64
  class Assembler
    # Debugging breakpoints and watch points module for the R64 assembler.
    #
    # This module provides functionality for setting up debugging breakpoints
    # and watch points that can be used with VICE monitor or other C64 debuggers.
    # Breakpoints allow you to pause execution at specific conditions, while
    # watch points monitor memory locations or labels.
    #
    # == Features
    #
    # * Program counter breakpoints
    # * Memory access breakpoints with conditions
    # * Raster line breakpoints for graphics debugging
    # * Watch points for memory locations and labels
    # * VICE monitor compatible output format
    #
    # == Usage
    #
    #   # Set breakpoint at current PC
    #   break_pc
    #   
    #   # Set memory breakpoint with condition
    #   break_mem(0xd020, 'w')  # Break on write to border color
    #   
    #   # Set raster breakpoint
    #   break_raster(100)       # Break at raster line 100
    #   
    #   # Add watch points
    #   watch :player_x         # Watch a label
    #   watch 0xd000           # Watch specific address
    #
    # @author Maxwell of Graffity
    # @version 0.2.0
    module Breakpoints
      # Sets a breakpoint at the current program counter location.
      #
      # This creates a breakpoint that will trigger when the processor
      # reaches the current PC address during execution. Useful for
      # debugging specific code locations.
      #
      # @example Setting a PC breakpoint
      #   label :debug_point
      #   break_pc              # Break when execution reaches this point
      #   lda #$01
      #
      # @note Only active during final compilation, ignored during precompilation
      def break_pc
        add_breakpoint 'breakonpc', @processor.pc.to_s(16)
      end

      # Sets a memory access breakpoint with specified condition.
      #
      # Creates a breakpoint that triggers when memory at the specified
      # address is accessed according to the given condition. Conditions
      # can be read ('r'), write ('w'), or execute ('x').
      #
      # @param address [Integer] The memory address to monitor
      # @param condition [String] The access condition ('r', 'w', 'x', or combinations)
      #
      # @example Memory breakpoints
      #   break_mem(0xd020, 'w')   # Break on write to border color
      #   break_mem(0x0400, 'r')   # Break on read from screen memory
      #   break_mem(0x1000, 'rw')  # Break on read or write
      #
      # @note Condition format follows VICE monitor conventions
      def break_mem(address, condition)
        add_breakpoint 'breakmem', "#{address.to_s(16)}#{condition}"
      end

      # Sets a raster line breakpoint for graphics debugging.
      #
      # Creates a breakpoint that triggers when the video chip reaches
      # the specified raster line. Particularly useful for debugging
      # raster interrupts and graphics effects.
      #
      # @param raster [Integer] The raster line number (0-312 for PAL)
      #
      # @example Raster breakpoints
      #   break_raster(50)    # Break at raster line 50
      #   break_raster(250)   # Break near bottom of screen
      #
      # @note Raster line numbers are system-dependent (PAL vs NTSC)
      def break_raster(raster)
        add_breakpoint 'breakraster', raster
      end

      # Adds a breakpoint to the internal breakpoint list.
      #
      # This is an internal method used by the specific breakpoint methods
      # to register breakpoints for output during debug compilation.
      #
      # @param type [String] The breakpoint type ('breakonpc', 'breakmem', 'breakraster')
      # @param params [String, Integer] The breakpoint parameters
      #
      # @private
      def add_breakpoint(type, params)
        return if @precompile

        @breakpoints ||= []
        @breakpoints.push({
          type: type,
          params: params
        })
      end

      # Adds a watch point for monitoring memory locations or labels.
      #
      # Watch points allow you to monitor the value of specific memory
      # locations or labels during debugging. They don't stop execution
      # but provide visibility into changing values.
      #
      # @param what [Symbol, Integer, nil] What to watch:
      #   - Symbol: A label name to watch
      #   - Integer: A specific memory address
      #   - nil: Current program counter location
      #
      # @example Watch points
      #   watch :player_score     # Watch a label
      #   watch 0xd020           # Watch border color register
      #   watch                  # Watch current PC location
      #
      # @note Watch points are output in VICE monitor format during debug compilation
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