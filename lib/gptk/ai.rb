# frozen_string_literal: true

Bundler.require :default, :ai
load "#{__dir__}/ai/chat_gpt.rb" # TODO: change to 'require' for production
load "#{__dir__}/ai/claude.rb"   # TODO: change to 'require' for production
load "#{__dir__}/ai/grok.rb"     # TODO: change to 'require' for production
load "#{__dir__}/ai/gemini.rb"   # TODO: change to 'require' for production
load "#{__dir__}/ai/auto_coder.rb"   # TODO: change to 'require' for production

module GPTK
  # AI interfaces and tools
  module AI
    @last_output = nil # Track the cached output of the latest operation

    class << self
      attr_reader :last_output

      # Executes a query against an AI client and processes the response.
      #
      # This method sends a query to the specified AI client (e.g., OpenAI's ChatGPT or Anthropic's Claude)
      # and returns the AI's response. It adjusts for differences between client APIs and handles token
      # usage tracking, response parsing, and error recovery in case of null outputs. The method also
      # includes a delay to prevent token throttling and race conditions.
      #
      # @param client [Object] The AI client instance, such as `OpenAI::Client` or Anthropic's Claude client.
      # @param data [Hash, nil] A hash for tracking token usage statistics. Keys include:
      #   - `:prompt_tokens` [Integer] Total tokens used in the prompt.
      #   - `:completion_tokens` [Integer] Total tokens generated by the AI.
      #   - `:cached_tokens` [Integer] Tokens retrieved from the cache, if applicable.
      # @param params [Hash] The query parameters to send to the AI client.
      #   - For OpenAI: Must include `parameters` key for the `chat` method.
      #   - For Anthropic: Must include `messages` key for the `create` method.
      #
      # @return [String] The AI's response message content as a string.
      #
      # @example Querying OpenAI's ChatGPT:
      #   client = OpenAI::Client.new(api_key: "your_api_key")
      #   data = { prompt_tokens: 0, completion_tokens: 0, cached_tokens: 0 }
      #   params = { model: "gpt-4", messages: [{ role: "user", content: "Hello!" }] }
      #   GPTK.query(client, data, params)
      #   # => "Hello! How can I assist you today?"
      #
      # @example Querying Anthropic's Claude:
      #   client = Anthropic::Client.new(api_key: "your_api_key")
      #   data = { prompt_tokens: 0, completion_tokens: 0, cached_tokens: 0 }
      #   params = { messages: [{ role: "user", content: "Tell me a story." }] }
      #   GPTK.query(client, data, params)
      #   # => "Once upon a time..."
      #
      # @note
      #   - The method automatically retries the query if the response is null.
      #   - A `sleep` delay of 1 second is included to prevent token throttling or race conditions.
      #   - The `data` hash is updated in-place with token usage statistics.
      #
      # @raise [RuntimeError] If no valid response is received after multiple retries.
      #
      # @see OpenAI::Client#chat
      # @see Anthropic::Client#messages
      #
      def query(client, data, params)
        response = if client.instance_of? OpenAI::Client
                     client.chat parameters: params
                   else # Anthropic Claude
                     client.messages.create params
                   end
        # Count token usage
        if data
          data[:prompt_tokens] += response.dig 'usage', 'prompt_tokens'
          data[:completion_tokens] += response.dig 'usage', 'completion_tokens'
          data[:cached_tokens] += response.dig 'usage', 'prompt_tokens_details', 'cached_tokens'
        end
        sleep 1 # Important to avoid race conditions and especially token throttling!

        # Return the AI's response message (object deconstruction must be ABSOLUTELY precise!)
        output = if client.instance_of? OpenAI::Client
                   response.dig 'choices', 0, 'message', 'content'
                 else # Anthropic Claude
                   response.dig 'content', 0, 'text'
                 end
        if output.nil?
          puts 'Error! Null output received from ChatGPT query.'
          until output
            puts 'Retrying...'
            output = client.chat parameters: params
            sleep 10
          end
        end

        output
      end

      # Categorizes a list of items based on provided categories using an AI model.
      # TODO: update this documentation
      #
      # This method sends prompts to an AI model to categorize a given list of items into specified
      # categories. It iterates through the items, constructs categorization prompts, and collects
      # responses from the AI. The results are grouped by category and returned as a hash. Errors
      # and progress are logged throughout the process.
      #
      # @param doc [Object] An instance containing the AI client and data context for querying.
      # @param items [Array<String>] The list of items to be categorized.
      # @param categories [String] A string describing the available categories, typically enumerated.
      # @param model [String, nil] Optional model identifier to override the default model in CONFIG.
      #
      # @return [Hash] A hash where keys are category numbers (integers) and values are arrays of items
      #   belonging to those categories.
      #
      # @example Categorizing a list of items:
      #   doc = Document.new(client: ChatGPT::Client.new, data: { prompt_tokens: 0 })
      #   items = ["Apple", "Carrot", "Chicken"]
      #   categories = "1. Fruit\n2. Vegetable\n3. Protein"
      #   AI.categorize_items(doc, items, categories)
      #   # => { 1 => ["Apple"], 2 => ["Carrot"], 3 => ["Chicken"] }
      #
      # @example Categorizing with a specific model:
      #   doc = Document.new(client: ChatGPT::Client.new, data: { prompt_tokens: 0 })
      #   items = ["Apple", "Carrot", "Chicken"]
      #   categories = "1. Fruit\n2. Vegetable\n3. Protein"
      #   AI.categorize_items(doc, items, categories, model: "gpt-4o")
      #   # => { 1 => ["Apple"], 2 => ["Carrot"], 3 => ["Chicken"] }
      #
      # @note
      #   - The method aborts execution if the `items` or `categories` are empty.
      #   - The AI prompt is dynamically constructed for each item using the categories.
      #   - Progress is logged to the console during the operation.
      #   - Results are cached in the `@last_output` instance variable for reuse.
      #
      # @raise [RuntimeError] If the AI fails to generate a viable response.
      # @raise [Abort] If the input items or categories are empty, or no output is generated.
      #
      # @see ChatGPT.query
      def categorize_items(client, items, categories, model: nil)
        abort 'Error: no items found!' if items.empty?
        abort 'Error: no categories found!' if categories.empty?
        puts "Categorizing #{items.count} items..."

        # Compose the list of prompts, one per item
        prompts = items.map do |item|
          <<~PROMPT
            Based on the following categories:

            #{categories}

            Please categorize the following item:

            #{item}

            Please return JUST the category NUMBER (excluding zero), and no other text. Ensure that every item receives a valid non-zero category number.
          PROMPT
        end

        # Run the batch and get responses (one response per item/prompt)
        responses = ChatGPT.run_batch(client, prompts, model: model)

        # Build a hash: { "item_text" => category_number }
        item_category_map = {}
        responses.each_with_index do |resp, index|
          category_num = resp.to_i
          item_category_map[items[index]] = category_num
        end

        # Some basic checks
        if item_category_map.empty?
          puts 'Error: no output!'
        else
          puts "Successfully categorized #{item_category_map.size} items!"
        end

        # Cache the results for later use, if needed
        @last_output = item_category_map

        item_category_map
      end
    end
  end
end
