module GPTK
  module AI
    # Query a an AI API for categorization of each and every item in a given set
    # @param doc (GPTK::Doc)
    # @param items (Array)
    # @param categories (Hash<Integer => Hash<title: String, description: String>>)
    # @return ??? todo
    # todo: test
    def self.categorize_items(doc, items, categories)
      abort 'Error: no items found!' if items.empty?
      abort 'Error: no categories found!' if categories.empty?
      puts "Categorizing #{items.count} items..."
      i = 0
      results = items.group_by do |item|
        prompt = "Based on the following categories:\n\n#{categories}\n\nPlease categorize the following prompt:\n\n#{item}\n\nPlease return JUST the category number, and no other output text."
        # Send the prompt to ChatGPT using the chat API, and retrieve the response
        response = doc.client.chat(
          parameters: {
            model: GPTK::AI::OPENAI_GPT_MODEL,
            messages: [{ role: 'user', content: prompt }],
            temperature: GPTK::AI::OPENAI_TEMPERATURE
          }
        )
        content = response.dig 'choices', 0, 'message', 'content' # This must be ABSOLUTELY precise!
        abort 'Error: failed to generate a viable response!' unless content
        puts "#{((i.to_f / items.count) * 100).round 3}% complete..."
        i += 1
        content.to_i
      end
      abort 'Error: no output!' unless results && !results.empty?
      puts "Successfully categorized #{results.values.reduce(0) {|j, loe| j += loe.count; j }} items!"
      doc.last_output = results # Cache results of the complete operation
      results
    end
  end
end
