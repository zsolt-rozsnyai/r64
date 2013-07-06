$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../apps'))

require 'assembler'
require 'demo.rb'
#these don't work:
#require '../apps/*.r64'
#puts Dir["apps/*.r64"]
#Dir["apps/*.r64"].each {|file| require file }


