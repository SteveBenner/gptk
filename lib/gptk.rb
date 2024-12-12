require 'json'
require 'yaml'
require 'parallel'
%w[ai book config doc file text utils].each do |lib|
  print "Loading module: #{lib.capitalize}... "
  load "#{__dir__}/gptk/#{lib}.rb" # TODO: change to use 'require' for production
  puts 'Success!'
end

# GPT Kit - A collection of useful tools for interacting with GPT agents and generating content
module GPTK
  START_TIME = Time.now
  VERSION = '0.11.3'.freeze
  class << self
    attr_accessor :mode
  end

  self.mode = ARGV[0] || 0 # The script run mode is set via CLI argument

  self.mode = self.mode.zero? ? 1 : self.mode # Default to mode 1
  abort 'Please provide a valid script mode as an argument (1, 2, or 3)' if self.mode && ![1, 2, 3].include?(self.mode)

  # Load configuration files
  Config.load_openai_setup
  Config.load_book_setup
  puts 'Successfully configured GPTKit.'

  puts 'WARNING: Operating without script mode!' if self.mode.zero?

  # Benchmarking method to calculate elapsed time since loading the library
  def self.elapsed_time(start_time = nil)
    ((Time.now - (start_time || START_TIME)) / 60).round 2
  end
end