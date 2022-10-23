module R64
  class Assembler
    module Compile
      def precompile
        main
        @processor.set_pc @pc_start
        @precompile = false
      end

      def compile!(options = {})
        main
        save! options if options[:save] || options[:filename]
        debug if options[:debug] == :debug || $mode == :debug
      end

      def debug
        save_labels
        save_watches
        save_breakpoints
      end

      def save_labels
        FileUtils.mkdir_p("./output/meta/labels")
        File.open("./output/meta/labels/#{filename}.labels", 'w') do |output|
          output.write formatted_labels
        end
      end

      def formatted_labels
        flabels = []
        (@labels || {}).each_key do |label|
          flabels.push("#{label} = $#{@labels[label].to_s(16)}")
        end
        flabels.join("\n")
      end

      def save_watches
        file = (@watchers || []).map do |watcher|
          "#{watcher[:label]} = $#{watcher[:address]}"
        end.join("\n")

        FileUtils.mkdir_p("./output/meta/watches")
        File.open("./output/meta/watches/#{filename}.watches", 'w') do |output|
          output.write file
        end
      end

      def save_breakpoints
        file = (@breakpoints || []).map do |breakpoint|
          "#{breakpoint[:type]} #{breakpoint[:params]}"
        end.join("\n")

        FileUtils.mkdir_p("./output/meta/breakpoints")
        File.open("./output/meta/breakpoints/#{filename}.breakpoints", 'w') do |output|
          output.write file
        end
      end

      def entrypoint
        @options[:entrypoint]
      end

      def set_entrypoint
        if @precompile && @options[:entrypoint].nil?
          puts "Setting entrypoint to #{@processor.pc.to_s(16)}"
          @options[:entrypoint] = @processor.pc
        end
      end

      def filename
        self.class.name.downcase[0..15]
      end

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