require 'awesome_print'
require 'json'
require 'yaml'
require 'parallel'
%w[ai book config doc file text].each {|lib| require_relative "gptk/#{lib}" }

module GPTK
  VERSION = '0.1'
  START_TIME = Time.now
  MODE = ARGV[0].to_i

  abort 'Please provide the mode as an argument (1, 2, or 3)' unless [1, 2, 3].include? MODE

  # Load configuration files
  Config.load_openai_setup
  Config.load_book_setup

  # Benchmarking method to calculate elapsed time
  def self.elapsed_time
    ((Time.now - START_TIME) / 60).round(1)
  end
end