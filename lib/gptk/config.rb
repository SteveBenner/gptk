module GPTK
  module Config
    def self.load_openai_setup
      print 'Loading platform-agnostic AI setup code... '
      load 'config/ai_setup.rb'
      puts 'Complete.'
    end

    def self.load_book_setup
      print 'Loading Book setup parameters... '
      load 'config/book_setup.rb'
      puts 'Complete.'
    end
  end
end