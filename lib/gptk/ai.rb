module GPTK
  module AI
    @last_output = nil # Track the cached output of the latest operation
    def self.last_output
      @last_output
    end

    # Run a single AI API query (generic) and return the results of a single prompt
    def self.query(client, data, params)
      method = client.class == OpenAI::Client ? :chat : :messages
      response = client.send method, parameters: params
      # Count token usage
      if data
        data[:prompt_tokens] += response.dig 'usage', 'prompt_tokens'
        data[:completion_tokens] += response.dig 'usage', 'completion_tokens'
        data[:cached_tokens] += response.dig 'usage', 'prompt_tokens_details', 'cached_tokens'
      end
      # puts response # todo: remove for production
      # Return the AI's response message
      if client.class == OpenAI::Client
        response.dig 'choices', 0, 'message', 'content' # This must be ABSOLUTELY precise!
      else
        response.dig 'content', 0, 'text'
      end
    end

    module ChatGPT
      def self.query(client, prompt, data)
        AI.query client, data, {
          model: CONFIG[:openai_gpt_model],
          temperature: CONFIG[:openai_temperature],
          max_tokens: CONFIG[:max_tokens],
          messages: [{ role: 'user', content: prompt }]
        }
      end
    end

    module Claude
      def self.query(client, prompt, data)
        AI.query client, nil, {
          model: CONFIG[:anthropic_gpt_model],
          max_tokens: CONFIG[:anthropic_max_tokens],
          messages: [{ role: 'user', content: prompt }]
        }
      end
    end

    # Query a an AI for categorization of each and every item in a given set
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
          content = ChatGPT.query doc.client, prompt, doc.data
        rescue => e
          puts "Error: #{e.class}: #{e.message}"
          puts 'Please try operation again, or review the code.'
          puts 'Last operation response:'
          print content
          return content
        end
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
