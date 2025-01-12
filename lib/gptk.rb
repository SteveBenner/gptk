require 'json'
require 'yaml'
require 'base64'
require 'fileutils'
require 'open3'
require 'set'
require 'bundler'
%w[ai book config doc text utils].each do |lib|
  print "Loading module: #{lib.capitalize}... "
  load "#{__dir__}/gptk/#{lib}.rb" # TODO: change to use 'require' for production
  puts 'Success!'
end

# GPT Kit - A collection of useful tools for interacting with GPT agents and generating content
module GPTK
  START_TIME = Time.now
  VERSION = '0.19'.freeze

  # Load configuration files
  Config.load_main_setup
  Config.load_openai_setup
  Config.load_book_setup
  puts 'Successfully configured GPTKit.'

  # Benchmarking method to calculate elapsed time since loading the library
  def self.elapsed_time(start_time = nil)
    ((Time.now - (start_time || START_TIME)) / 60).round 2
  end
end