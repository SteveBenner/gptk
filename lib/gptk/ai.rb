module GPTK
  module AI
    @last_output = nil # Track the cached output of the latest operation
    def self.last_output
      @last_output
    end

    # Query a an AI API for categorization of each and every item in a given set
    # @param [GPTK::Doc] doc
    # @param [Array] items
    # @param [Hash<Integer => Hash<title: String, description: String>>] categories
    # @return [Hash<Integer => Array<String>>] categorized items
    def self.categorize_items(doc, items, categories)
      abort 'Error: no items found!' if items.empty?
      abort 'Error: no categories found!' if categories.empty?
      puts "Categorizing #{items.count} items..."
      i = 0
      results = items.group_by do |item|
        prompt = "Based on the following categories:\n\n#{categories}\n\nPlease categorize the following prompt:\n\n#{item}\n\nPlease return JUST the category number, and no other output text."
        # Send the prompt to the AI using the chat API, and retrieve the response
        begin
          response = doc.client.chat(
            parameters: {
              model: GPTK::AI::CONFIG[:openai_gpt_model],
              messages: [{ role: 'user', content: prompt }],
              temperature: GPTK::AI::CONFIG[:openai_temperature]
            }
          )
        rescue => e
          puts "Error: #{e.class}: #{e.message}"
          puts 'Please try operation again, or review the code.'
          puts 'Last operation response:'
          print response
          return response
        end
        content = response.dig 'choices', 0, 'message', 'content' # This must be ABSOLUTELY precise!
        abort 'Error: failed to generate a viable response!' unless content
        puts "#{((i.to_f / items.count) * 100).round 3}% complete..."
        i += 1
        content.to_i
      end
      abort 'Error: no output!' unless results && !results.empty?
      puts "Successfully categorized #{results.values.reduce(0) {|j, loe| j += loe.count; j }} items!"
      @last_output = results # Cache results of the complete operation
      results
    end
  end
end
