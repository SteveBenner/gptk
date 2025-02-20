# frozen_string_literal: true

module GPTK
  module AI
    # Anthropic Claude interface
    module Claude
      # This method assumes you MUST pass either a prompt OR a messages array
      # TODO: FIX OR REMOVE THIS METHOD! CURRENTLY RETURNING 400 ERROR
      # def self.query(client, prompt: nil, messages: nil, data: nil)
      #   AI.query client, data, {
      #     model: CONFIG[:anthropic_gpt_model],
      #     max_tokens: CONFIG[:anthropic_max_tokens],
      #     messages: messages || [{ role: 'user', content: prompt }]
      #   }
      # end

      # Sends a query to the Claude API, utilizing memory for context and tracking.
      #
      # This method sends user messages to the Claude API and retrieves a response. It handles
      # string-based or array-based inputs, dynamically constructs the request body and headers,
      # and parses the response for the AI's output. If errors occur, the method retries the query.
      #
      # @param api_key [String] The API key for accessing the Claude API.
      # @param messages [String, Array<Hash>] The user input to be sent to the Claude API. If a string
      #   is provided, it is converted into an array of message hashes with `role` and `content` keys.
      #
      # @return [String] The AI's response text.
      #
      # @example Sending a single message as a string:
      #   api_key = "your_anthropic_api_key"
      #   messages = "What is the capital of Italy?"
      #   Claude.query_with_memory(api_key, messages)
      #   # => "The capital of Italy is Rome."
      #
      # @example Sending multiple messages as an array:
      #   api_key = "your_anthropic_api_key"
      #   messages = [
      #     { role: "user", content: "Tell me a joke." },
      #     { role: "user", content: "Explain quantum mechanics simply." }
      #   ]
      #   Claude.query_with_memory(api_key, messages)
      #   # => "Here’s a joke: Why did the physicist cross the road? To observe the other side!"
      #
      # @note
      #   - The method retries the query in case of errors, such as network failures, JSON parsing errors,
      #     or bad responses from the Claude API.
      #   - A delay (`sleep 1`) is included to prevent token throttling and race conditions.
      #   - The method currently lacks data tracking functionality (marked as TODO).
      #
      # @raise [JSON::ParserError] If the response body cannot be parsed as JSON.
      # @raise [RuntimeError] If no valid response is received after retries.
      #
      # @see HTTParty.post
      # @see JSON.parse
      def self.query_with_memory(api_key, messages)
        messages = messages.instance_of?(String) ? [{ role: 'user', content: messages }] : messages
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
        begin
          response = HTTParty.post(
            'https://api.anthropic.com/v1/messages',
            headers: headers,
            body: body.to_json
          )
          # TODO: track data
          # Return text content of the Claude API response
        rescue => e # We want to catch ALL errors, not just those under StandardError
          puts "Error: #{e.class}: '#{e.message}'. Retrying query..."
          sleep 10
          output = query_with_memory api_key, messages
        end
        sleep 1 # Important to avoid race conditions and especially token throttling!
        begin
          output = JSON.parse(response.body).dig 'content', 0, 'text'
        rescue JSON::ParserError => e
          puts "Error: #{e.class}. Retrying query..."
          sleep 10
          output = query_with_memory api_key, messages
        end
        if output.nil?
          ap JSON.parse response.body
          puts 'Error: Claude API provided a bad response. Retrying query...'
          sleep 10
          output = query_with_memory api_key, messages
        end
        @last_output = output
        output
      end

      # TODO: remove or re-write this to take into account Claude doesn't process image uploads...
      def self.query_to_rails_code(api_key, content_file: nil, messages: [], prompt: nil)
        require 'base64'
        require 'json'
        require 'awesome_print'

        raise 'Content file is required' if content_file.nil?

        # Read and encode the content file (assumed to be an image) as Base64
        file_content = File.read(content_file, mode: 'rb')
        base64_content = Base64.strict_encode64(file_content)

        # Define the file types (and labels) that you want to include in the current snapshot.
        file_types = { erb: 'ERB', sass: 'SASS', coffeescript: 'CoffeeScript' }

        # Build a snapshot of the current state of these code files
        current_code_snapshot = file_types.map do |file_type, label|
          file_path = GPTK::CONFIG[:rails]["#{file_type}_file_path".to_sym]
          if File.exist?(file_path)
            content = File.read(file_path)
            "Current #{label} code from #{file_path}:\n#{content}\n"
          else
            "No existing #{label} file found at #{file_path}\n"
          end
        end.join("\n")

        # Build the initial prompt including both the encoded image and the current code snapshot
        initial_message = {
          role: 'user',
          content: <<~PROMPT
            Analyze the following base64-encoded JPG image and the current state of the code files provided below.
            Use the design elements from the image along with the existing code structure to generate updated code.
            ONLY output raw code in the specified format.
            Use SASS style without semicolons, reserve JavaScript for the CoffeeScript file, and avoid including it in ERB.

            Here is the base64-encoded image:
            #{base64_content}

            And here is the current state of the code files:
            #{current_code_snapshot}
          PROMPT
        }

        conversation_messages = [initial_message]

        # Start the user interaction loop
        loop do
          print 'Enter your prompt (type "exit" to quit): '
          user_input = gets.strip
          break if user_input.downcase == 'exit'

          # Process each file type for code generation
          file_types.each do |file_type, label|
            puts "Generating #{label} code..."

            # Add the user prompt for generating code for this file type
            current_prompt = {
              role: 'user',
              content: "#{user_input}. Generate #{label} code."
            }

            conversation_messages << current_prompt

            # Get response from Claude
            response = GPTK::AI::Claude.query_with_memory(
              api_key,
              conversation_messages
            )

            generated_code = response

            if generated_code
              # Remove any Markdown formatting and extra whitespace
              generated_code = generated_code.gsub(/```.*\n/, '').strip

              file_path = GPTK::CONFIG[:rails]["#{file_type}_file_path".to_sym]
              File.write(file_path, generated_code)
              puts "Successfully wrote #{label} code to #{file_path}"

              # Add the assistant's response to the conversation history
              conversation_messages << {
                role: 'assistant',
                content: generated_code
              }
            else
              puts "Error: No #{label} code generated."
            end
          end
        end

        puts 'Rails code generation completed!'
      end
    end
  end
end
