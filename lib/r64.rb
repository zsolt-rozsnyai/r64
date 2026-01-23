# frozen_string_literal: true

require_relative "r64/version"
require_relative "r64/symbol_extensions"
require_relative "r64/assembler"
require_relative "r64/base"
require_relative "r64/bits"
require_relative "r64/memory"
require_relative "r64/processor"

module R64
  class Error < StandardError; end
end
