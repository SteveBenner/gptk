require 'json'
require 'yaml'
require 'parallel'
%w[ai book config doc file text].each do |lib|
  print "Loading module: #{lib.capitalize}... "
  load "#{__dir__}/gptk/#{lib}.rb"
  puts 'Success!'
end

module GPTK
  VERSION = '0.4'
  @@mode = 1 # The script run mode is set via CLI argument
  def self.mode
    @@mode
  end
  def self.mode=(value)
    @@mode = value
  end

  if @@mode && !@@mode.zero?
    abort 'Please provide a valid script mode as an argument (1, 2, or 3)' unless [1, 2, 3].include? @@mode
  end

  # Load configuration files
  Config.load_openai_setup
  Config.load_book_setup
  puts 'Successfully configured GPTKit.'
  puts "If you don't know where to begin, type `GPTK.help` to get started!"

  puts 'WARNING: Operating without script mode!' if @@mode.zero?

  # Benchmarking method to calculate elapsed time
  def self.elapsed_time
    ((Time.now - START_TIME) / 60).round(1)
  end

  # A helpful quickstart guide for using the library
  def self.help
    puts 'Welcome to GPTKit! This brief demo will show you how to use the library.'
    puts '-' * 72
    puts "Let's get started. First, to connect to a GPT, we need access to a platform."
    puts 'Assuming you are using software such as .env or have stored your API key in'
    puts "the ENVIRONMENT, let's connect to the OpenAI API so we can use ChatGPT."
    puts "$> OPENAI_API_KEY = ENV['OPENAI_API_KEY']"
    puts
    puts "Next, initialize the API client (don't forget to add any custom headers!)."
    puts "$> require 'openai'"
    puts '$> client = OpenAI.Client.new access_token: OPEN_API_KEY, log_errors: true'
    puts
    puts 'NOTE: The syntax for API client use will vary between platforms. Refer to'
    puts 'the documentation of the specific platform you are trying to connect to.'
    puts
    puts 'Next, define a file path for data output. Use `GPTK::File.fname_increment`'
    puts 'To intelligently increment the name of your output file based on existing'
    puts 'documents in the directory you are writing to. This ensures no overwrites!'
    puts "$> output_file = GPTK::File.fname_increment File.expand_path('output.md')"
    puts
    puts 'Now, initialize a new `GPTK::Doc` object to represent and track your work.'
    puts '$> doc = GPTK::Doc.new client, output_file'
    puts
    puts '`Doc.new` takes an API client, followed by optional additional parameters:'
    puts '@param [String] The path to a file where the output will be written'
    puts '@param [Object] An object representing the content to write to file'
    puts '@param [Integer] The script run mode (1, 2, or 3)'
    puts
    puts 'To perform an operation, we need to define some content to work with.'
    puts "For example, we can generate a document with a title and several 'chapters'."
    puts "First, process a markdown file containing an enumerated list of categories."
    puts "$> category_text = File.read File.expand_path('categories.md')"
    puts '$> categories = GPTK::Text.parse_categories_str category_text'
    puts
    puts 'The `GPTK::Text.parse_categories_str` method will return formatted data'
    puts 'we can use in document composition. See `GPTK::Text` for more parsing tools.'
    puts 'We are going to use the sorted categories along with a list of enumerated'
    puts 'items in a separate file to produce a document with organized content.'
    puts 'Parse in the list of items we want to categorize:'
    puts "$> input_file = File.read(File.expand_path('input.md'))"
    puts '$> items = GPTK::Text.parse_numbered_list input_file'
    puts
    puts 'Now we are ready to perform an AI operation. `GPTK::AI.categorize_items` is a'
    puts 'method that uses AI to group a list of items into categories meaningfully,'
    puts "based on the given category descriptions and each item's content/value."
    puts '$> grouped_items = GPTK::AI.categorize_items doc, items, categories'
    puts
    puts 'The AI may take several minutes to process the list of data. When it is'
    puts 'finished, we can use `GPTK::Doc.create_doc1` to generate our final output.'
    puts "$> output = doc.create_doc1 'Echoes of Silence', categories, grouped_items"
    puts
    puts 'Now you just have to write the results to a file! This concludes the demo.'
  end
end