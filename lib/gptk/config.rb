module GPTK
  # This module loads the configuration files into the primary namespace for easy access
  module Config
    def self.load_main_setup
      print 'Loading primary setup code... '
      load ::File.expand_path '../../../config/main_setup.rb', __FILE__
      puts 'Complete.'
    end

    def self.load_openai_setup
      print 'Loading platform-agnostic AI setup code... '
      load ::File.expand_path '../../../config/ai_setup.rb', __FILE__
      puts 'Complete.'
    end

    def self.load_book_setup
      print 'Loading book generation parameters... '
      load ::File.expand_path '../../../config/book_setup.rb', __FILE__
      puts 'Complete.'
    end
  end
end