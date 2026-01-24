module R64
  class Assembler
    # Compilation and output generation module for the R64 assembler.
    #
    # This module handles the compilation process, including precompilation for
    # forward reference resolution, final compilation, and output generation in
    # various formats. It also manages debug information output for use with
    # VICE monitor and other debugging tools.
    #
    # == Features
    #
    # * Two-pass compilation (precompile + compile)
    # * PRG file generation with proper C64 format
    # * Debug information output (labels, breakpoints, watches)
    # * Configurable memory ranges and entry points
    # * VICE monitor compatible debug files
    #
    # == Compilation Process
    #
    # 1. Precompilation: Resolves forward references and calculates addresses
    # 2. Final compilation: Generates actual machine code
    # 3. Output generation: Creates PRG files and debug information
    #
    # == Usage
    #
    #   assembler = R64::Assembler.new do
    #     # Assembly code here
    #   end
    #   
    #   # Compile and save
    #   assembler.compile!(save: true, debug: true)
    #   
    #   # Or just precompile for analysis
    #   assembler.precompile
    #
    # @author Maxwell of Graffity
    # @version 0.2.0
    module Compile
      # Performs precompilation to resolve forward references.
      #
      # The precompilation pass executes the main assembly code to calculate
      # all label addresses and resolve forward references. After precompilation,
      # the processor is reset to the starting position for final compilation.
      #
      # @example Precompiling code
      #   assembler.precompile  # Resolves all labels and addresses
      #
      # @note This method calls the main assembly method and then resets
      #   the processor state for final compilation.
      def precompile
        main
        @processor.set_pc @pc_start
        @precompile = false
      end

      # Compiles the assembly code and optionally saves output.
      #
      # This method performs the final compilation pass, generating actual
      # machine code. It can optionally save the compiled program to a PRG
      # file and generate debug information.
      #
      # @param options [Hash] Compilation options
      # @option options [Boolean] :save Save the compiled program to a PRG file
      # @option options [String] :filename Custom filename for output
      # @option options [Symbol] :debug Generate debug information (:debug)
      #
      # @example Basic compilation
      #   assembler.compile!
      #
      # @example Compilation with output
      #   assembler.compile!(save: true, debug: :debug)
      #
      # @note The method respects the global $mode variable for debug output
      def compile!(options = {})
        main
        save! options if options[:save] || options[:filename]
        debug if options[:debug] == :debug || $mode == :debug
      end

      # Generates all debug information files.
      #
      # Creates debug output files including labels, watch points, and
      # breakpoints in both VICE monitor compatible format and RetroDebugger
      # JSON format. Files are saved in the ./output/meta/ directory structure.
      #
      # @example Generating debug info
      #   assembler.debug  # Creates labels, watches, and breakpoints files
      def debug
        save_labels
        save_watches
        save_breakpoints
        save_retrodebugger_labels
        save_retrodebugger_watches
        save_retrodebugger_breakpoints
      end

      # Saves label definitions to a debug file.
      #
      # Creates a labels file containing all defined labels and their
      # addresses in VICE monitor format. The file can be loaded into
      # VICE for symbolic debugging.
      #
      # @example Label file format
      #   # ./output/meta/labels/program.labels
      #   start = $2000
      #   loop = $2003
      #   data = $3000
      def save_labels
        FileUtils.mkdir_p("./output/meta/labels")
        File.open("./output/meta/labels/#{filename}.labels", 'w') do |output|
          output.write formatted_labels
        end
      end

      # Formats labels for debug output.
      #
      # Converts the internal label hash and namespaced labels into VICE monitor 
      # format strings with hexadecimal addresses prefixed by '$'.
      #
      # @return [String] Formatted labels, one per line
      #
      # @private
      def formatted_labels
        flabels = []
        
        # Add regular labels
        (@labels || {}).each_key do |label|
          flabels.push("#{label} = $#{@labels[label].to_s(16)}")
        end
        
        # Add namespaced labels if available
        if respond_to?(:namespaced_labels)
          namespaced_labels.each do |label, address|
            flabels.push("#{label} = $#{address.to_s(16)}")
          end
        end
        
        flabels.join("\n")
      end

      # Saves watch points to a debug file.
      #
      # Creates a watches file containing all defined watch points in
      # VICE monitor format. Watch points allow monitoring of memory
      # locations during debugging.
      #
      # @example Watch file format
      #   # ./output/meta/watches/program.watches
      #   player_x = $2000
      #   addr_d020 = $d020
      def save_watches
        watches_lines = []
        
        # Add regular watches
        (@watchers || []).each do |watcher|
          watches_lines << "#{watcher[:label]} = $#{watcher[:address]}"
        end
        
        # Add namespaced watches if available
        if respond_to?(:collect_namespaced_watches)
          namespaced_watches = collect_namespaced_watches
          namespaced_watches.each do |label, address|
            watches_lines << "#{label} = $#{address}"
          end
        end
        
        file = watches_lines.join("\n")

        FileUtils.mkdir_p("./output/meta/watches")
        File.open("./output/meta/watches/#{filename}.watches", 'w') do |output|
          output.write file
        end
      end

      # Saves breakpoints to a debug file.
      #
      # Creates a breakpoints file containing all defined breakpoints in
      # VICE monitor format. Breakpoints can be loaded into VICE to pause
      # execution at specific conditions.
      #
      # @example Breakpoint file format
      #   # ./output/meta/breakpoints/program.breakpoints
      #   breakonpc 2000
      #   breakmem d020w
      #   breakraster 100
      def save_breakpoints
        breakpoint_lines = []
        
        # Add regular breakpoints
        (@breakpoints || []).each do |breakpoint|
          breakpoint_lines << "#{breakpoint[:type]} #{breakpoint[:params]}"
        end
        
        # Add namespaced breakpoints if available
        if respond_to?(:collect_namespaced_breakpoints)
          namespaced_breakpoints = collect_namespaced_breakpoints
          namespaced_breakpoints.each do |breakpoint|
            # Format: "breakonpc 2010 # MU0"
            comment = " # #{breakpoint['namespace']}"
            breakpoint_lines << "#{breakpoint['type']} #{breakpoint['address']}#{comment}"
          end
        end
        
        file = breakpoint_lines.join("\n")

        FileUtils.mkdir_p("./output/meta/breakpoints")
        File.open("./output/meta/breakpoints/#{filename}.breakpoints", 'w') do |output|
          output.write file
        end
      end

      # Saves labels in RetroDebugger JSON format.
      #
      # Creates a labels file in RetroDebugger's JSON format with all defined
      # labels and their addresses. This format is compatible with RetroDebugger
      # for enhanced debugging features.
      #
      # @example RetroDebugger labels file format
      #   {
      #     "Version": "1",
      #     "Segments": [
      #       {
      #         "Name": "Default",
      #         "CodeLabels": [
      #           {
      #             "Address": "2000",
      #             "Name": "start"
      #           }
      #         ]
      #       }
      #     ]
      #   }
      def save_retrodebugger_labels
        FileUtils.mkdir_p("./output/meta/labels")
        File.open("./output/meta/labels/#{filename}.json.labels", 'w') do |output|
          output.write formatted_retrodebugger_labels
        end
      end

      # Formats labels for RetroDebugger JSON output.
      #
      # Converts the internal label hash and namespaced labels into RetroDebugger's 
      # JSON format with proper structure and metadata.
      #
      # @return [String] JSON formatted labels
      #
      # @private
      def formatted_retrodebugger_labels
        require 'json'
        
        code_labels = []
        
        # Add regular labels
        (@labels || {}).each do |label, address|
          code_labels << {
            "Address" => address.to_s(16),
            "Name" => label.to_s
          }
        end
        
        # Add namespaced labels if available
        if respond_to?(:namespaced_labels)
          namespaced_labels.each do |label, address|
            code_labels << {
              "Address" => address.to_s(16),
              "Name" => label.to_s
            }
          end
        end

        data = {
          "Version" => "1",
          "Segments" => [
            {
              "Name" => "Default",
              "CodeLabels" => code_labels
            }
          ]
        }

        JSON.pretty_generate(data)
      end

      # Saves watches in RetroDebugger JSON format.
      #
      # Creates a watches file in RetroDebugger's JSON format with all defined
      # watch points. This format is compatible with RetroDebugger for enhanced
      # debugging features.
      #
      # @example RetroDebugger watches file format
      #   {
      #     "Version": "1",
      #     "Segments": [
      #       {
      #         "Name": "Default",
      #         "Watches": [
      #           {
      #             "Label": "player_x",
      #             "Address": "2000",
      #             "Format": "hex8"
      #           }
      #         ]
      #       }
      #     ]
      #   }
      def save_retrodebugger_watches
        FileUtils.mkdir_p("./output/meta/watches")
        File.open("./output/meta/watches/#{filename}.json.watches", 'w') do |output|
          output.write formatted_retrodebugger_watches
        end
      end

      # Formats watches for RetroDebugger JSON output.
      #
      # Converts the internal watchers array and namespaced watches into RetroDebugger's 
      # JSON format with proper structure and metadata.
      #
      # @return [String] JSON formatted watches
      #
      # @private
      def formatted_retrodebugger_watches
        require 'json'
        
        watches = []
        
        # Add regular watches
        (@watchers || []).each do |watcher|
          watches << {
            "Label" => watcher[:label].to_s,
            "Address" => watcher[:address].to_s(16),
            "Format" => "hex8"
          }
        end
        
        # Add namespaced watches if available
        if respond_to?(:collect_namespaced_watches)
          namespaced_watches = collect_namespaced_watches
          namespaced_watches.each do |label, address|
            watches << {
              "Label" => label.to_s,
              "Address" => address.to_s,
              "Format" => "hex8"
            }
          end
        end

        data = {
          "Version" => "1",
          "Segments" => [
            {
              "Name" => "Default",
              "Watches" => watches
            }
          ]
        }

        JSON.pretty_generate(data)
      end

      # Saves breakpoints in RetroDebugger JSON format.
      #
      # Creates a breakpoints file in RetroDebugger's JSON format with all defined
      # breakpoints. This format is compatible with RetroDebugger for enhanced
      # debugging features.
      #
      # @example RetroDebugger breakpoints file format
      #   {
      #     "Version": "1",
      #     "Segments": [
      #       {
      #         "Name": "Default",
      #         "Breakpoints": [
      #           {
      #             "Type": "CpuPC",
      #             "Items": [
      #               {
      #                 "IsActive": true,
      #                 "Addr": 8192,
      #                 "Actions": 2,
      #                 "Data": 0
      #               }
      #             ]
      #           }
      #         ]
      #       }
      #     ]
      #   }
      def save_retrodebugger_breakpoints
        FileUtils.mkdir_p("./output/meta/breakpoints")
        File.open("./output/meta/breakpoints/#{filename}.json.breakpoints", 'w') do |output|
          output.write formatted_retrodebugger_breakpoints
        end
      end

      # Formats breakpoints for RetroDebugger JSON output.
      #
      # Converts the internal breakpoints array into RetroDebugger's JSON format
      # with proper structure and metadata.
      #
      # @return [String] JSON formatted breakpoints
      #
      # @private
      def formatted_retrodebugger_breakpoints
        require 'json'
        
        breakpoint_types = {}
        
        # Add regular breakpoints
        (@breakpoints || []).each do |breakpoint|
          type = case breakpoint[:type]
                 when 'breakonpc'
                   'CpuPC'
                 when /breakmem/
                   'Memory'
                 when 'breakraster'
                   'RasterLine'
                 else
                   'CpuPC'
                 end
          
          breakpoint_types[type] ||= []
          
          # Parse the params to extract address and other data
          params = breakpoint[:params].to_s
          addr = params.match(/\h+/) ? params.match(/\h+/)[0].to_i(16) : 0
          
          item = {
            "IsActive" => true,
            "Addr" => addr,
            "Actions" => 2,
            "Data" => 0
          }
          
          # Add memory-specific fields
          if type == 'Memory'
            item["MemoryAccess"] = 6  # Read/Write
            item["Value"] = 255
            item["Comparison"] = 2
          end
          
          breakpoint_types[type] << item
        end
        
        # Add namespaced breakpoints if available
        if respond_to?(:collect_namespaced_breakpoints)
          namespaced_breakpoints = collect_namespaced_breakpoints
          namespaced_breakpoints.each do |breakpoint|
            type = case breakpoint["type"]
                   when 'breakonpc'
                     'CpuPC'
                   when /breakmem/
                     'Memory'
                   when 'breakraster'
                     'RasterLine'
                   else
                     'CpuPC'
                   end
            
            breakpoint_types[type] ||= []
            
            # Parse address from hex string
            addr = breakpoint["address"].match(/\h+/) ? breakpoint["address"].match(/\h+/)[0].to_i(16) : 0
            
            item = {
              "IsActive" => true,
              "Addr" => addr,
              "Actions" => 2,
              "Data" => 0,
              "Namespace" => breakpoint["namespace"]
            }
            
            # Add memory-specific fields
            if type == 'Memory'
              item["MemoryAccess"] = 6  # Read/Write
              item["Value"] = 255
              item["Comparison"] = 2
            end
            
            breakpoint_types[type] << item
          end
        end
        
        breakpoints_array = []
        breakpoint_types.each do |type, items|
          breakpoints_array << {
            "Type" => type,
            "Items" => items
          }
        end

        data = {
          "Version" => "1",
          "Segments" => [
            {
              "Name" => "Default",
              "Breakpoints" => breakpoints_array
            }
          ]
        }

        JSON.pretty_generate(data)
      end

      # Returns the configured entry point address.
      #
      # @return [Integer, nil] The entry point address or nil if not set
      def entrypoint
        @options[:entrypoint]
      end

      # Sets the entry point to the current program counter if not already set.
      #
      # This method is typically called during precompilation to automatically
      # determine the program's entry point based on where code generation begins.
      #
      # @note Only sets the entry point during precompilation and if not already configured
      def set_entrypoint
        if @precompile && @options[:entrypoint].nil?
          puts "Setting entrypoint to #{@processor.pc.to_s(16)}"
          @options[:entrypoint] = @processor.pc
        end
      end

      # Generates a filename based on the class name.
      #
      # Creates a lowercase filename from the class name, truncated to 15
      # characters for compatibility with older file systems.
      #
      # @return [String] The generated filename
      #
      # @example Filename generation
      #   # For class R64::Assembler
      #   filename  # => "r64::assembler"
      def filename
        self.class.name.downcase[0..15]
      end

      # Saves the compiled program to a PRG file.
      #
      # Generates a Commodore 64 PRG file with the proper format:
      # - 2-byte little-endian start address header
      # - Memory contents from start to end address
      # - Unused memory filled with zeros
      #
      # @param options [Hash] Save options
      # @option options [Integer] :start Override start address
      # @option options [Integer] :end Override end address
      #
      # @example Saving a PRG file
      #   assembler.save!(start: 0x0801, end: 0x1000)
      #
      # @note The PRG format is compatible with C64 emulators and real hardware
      def save!(options = {})
        start = @options[:first_byte] || options[:start] || @memory.start || processor.start
        finish = @options[:last_byte] || options[:end] || @memory.finish || 0xffff
        puts start
        puts "./output/#{filename}.prg"
        File.open("./output/#{filename}.prg", 'w') do |output|
          puts "Starting address: #{start.to_json}"
          output.print hi_lo(start)[:lo].chr
          output.print hi_lo(start)[:hi].chr
          (start..finish).each do |byte|
            output.print @memory[byte]&.chr || "\x00"
          end
        end
      end
    end
  end
end