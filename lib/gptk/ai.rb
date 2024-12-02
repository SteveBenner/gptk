module GPTK
  module AI
    @last_output = nil # Track the cached output of the latest operation
    def self.last_output
      @last_output
    end

    # Run a single AI API query (generic) and return the results of a single prompt
    def self.query(client, data, params)
      response = if client.class == OpenAI::Client
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
      # Return the AI's response message (object deconstruction must be ABSOLUTELY precise!)
      if client.class == OpenAI::Client
        response.dig 'choices', 0, 'message', 'content'
      else # Anthropic Claude
        response.dig 'content', 0, 'text'
      end
    end

    module ChatGPT
      def self.query(client, data, prompt)
        AI.query client, data, {
          model: CONFIG[:openai_gpt_model],
          temperature: CONFIG[:openai_temperature],
          max_tokens: CONFIG[:max_tokens],
          messages: [{ role: 'user', content: prompt }]
        }
        # todo: track token usage
      end

      def self.create_assistant(client, name, instructions, description=nil, tools=nil, tool_resources=nil, metadata=nil)
        parameters = {
          model: CONFIG[:openai_gpt_model],
          name: name,
          description: description,
          instructions: instructions
        }
        parameters.update({tools: tools}) if tools
        parameters.update({tool_resources: tool_resources}) if tool_resources
        parameters.update({metadata: metadata}) if metadata
        response = client.assistants.create parameters: parameters
        response['id']
      end

      def self.run_assistant_thread(client, thread_id, assistant_id, prompts)
        abort 'Error: no prompts given!' if prompts.empty?
        # Populate the thread with messages using given prompts
        if prompts.class == String
          client.messages.create thread_id: thread_id, parameters: { role: 'user', content: prompts }
        else # Array
          prompts.each do |prompt|
            client.messages.create thread_id: thread_id, parameters: { role: 'user', content: prompt }
          end
        end

        # Create a run using given thread
        response = client.runs.create thread_id: thread_id, parameters: { assistant_id: assistant_id }
        run_id = response['id']

        # Loop while awaiting status of the run
        messages = []
        while true do
          response = client.runs.retrieve id: run_id, thread_id: thread_id
          status = response['status']

          case status
            when 'queued', 'in_progress', 'cancelling'
              puts 'Processing...'
              sleep 1
            when 'completed'
              order, limit = 'asc', 100
              initial_response = client.messages.list(thread_id: thread_id, parameters: { order: order, limit: limit })
              messages.concat initial_response['data']
              # todo: FINISH THIS
              # if initial_response['has_more'] == true
              #   until ['has_more'] == false
              #     messages.concat client.messages.list(thread_id: thread_id, parameters: { order: order, limit: limit })
              #   end
              # end
              break
            when 'requires_action'
              puts 'Error: unhandled "Requires Action"'
            when 'cancelled', 'failed', 'expired'
              puts response['last_error'].inspect
              break
            else puts "Unknown status response: #{status}"
          end
        end

        # Return the response text received from the Assistant after processing the run
        response = messages.last['content'].first['text']['value']
        puts 'CHATGPT PROMPT(s)'
        ap prompts
        puts "CHATGPT RESPONSE: #{response}"
        bad_response = (prompts.class == String) ? (response == prompts) : (prompts.include? response)
        while bad_response
          puts 'Error: echoed response detected from ChatGPT. Retrying...'
          sleep 10
          response = self.run_assistant_thread client, thread_id, assistant_id, 'Avoid repeating the input. Turn over to Claude.'
        end
        return '' if bad_response
        sleep 1 # Important to avoid race conditions and token throttling!
        response
      end
    end

    module Claude
      # This method assumes you MUST pass either a prompt OR a messages array
      def self.query(client, prompt: nil, messages: nil, data: nil)
        AI.query client, data, {
          model: CONFIG[:anthropic_gpt_model],
          max_tokens: CONFIG[:anthropic_max_tokens],
          messages: messages ? messages : [{ role: 'user', content: prompt }]
        }
      end

      def self.query_with_memory(api_key, messages)
        # Anthropic manual HTTP setup
        headers = {
          'x-api-key' => api_key,
          'anthropic-version' => '2023-06-01',
          'content-type' => 'application/json',
          'anthropic-beta' => 'prompt-caching-2024-07-31'
        }
        body = {
          'model': CONFIG[:anthropic_gpt_model],
          'max_tokens': CONFIG[:anthropic_max_tokens],
          'messages': messages
        }
        response = HTTParty.post(
          'https://api.anthropic.com/v1/messages',
          headers: headers,
          body: body.to_json
        )
        # todo: track data
        # Return text content of the Claude API response
        sleep 60 # Important to avoid race conditions and token throttling!
        output = JSON.parse(response.body).dig 'content', 0, 'text'
        if output.nil?
          ap JSON.parse response.body
          puts 'Error: Claude API provided an empty response!'
        else
          puts "CLAUDE RESPONSE: #{output}"
          output
        end
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
      puts 'Error: no output!' unless results && !results.empty?
      puts "Successfully categorized #{results.values.reduce(0) {|j, loe| j += loe.count; j }} items!"
      @last_output = results # Cache results of the complete operation
      results
    end
  end
end
