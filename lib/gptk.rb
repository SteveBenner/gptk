require 'awesome_print'
require 'json'
require 'yaml'
require 'parallel'
%w[ai book config doc file text].each do |lib|
  print "Loading module: #{lib.capitalize}... "
  require_relative "gptk/#{lib}"
  puts 'Success!'
end

module GPTK
  VERSION = '0.1'
  START_TIME = Time.now
  MODE = ARGV[0].to_i # The script run mode is set via CLI argument

  if MODE && !(MODE == 0)
    abort 'Please provide a valid script mode as an argument (1, 2, or 3)' unless [1, 2, 3].include? MODE
  end
  puts 'WARNING: Operating without script mode!' if MODE == 0

  # Load configuration files
  Config.load_openai_setup
  Config.load_book_setup
  puts 'Successfully configured GPTKit.'

  # Benchmarking method to calculate elapsed time
  def self.elapsed_time
    ((Time.now - START_TIME) / 60).round(1)
  end
end