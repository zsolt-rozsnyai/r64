#!/usr/bin/ruby -w
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../lib'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '../apps'))
require 'assembler'

ARGV.each do |arg|
  $LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "../apps/#{arg}/lib"))
  require "#{arg}/project.rb"
end



