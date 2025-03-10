# frozen_string_literal: true

module GPTK
  module AI
    # Anthropic Claude interface
    module Claude
      class << self
        # Sends a query to the Claude API, utilizing memory for context and tracking.
        #
        # This method sends user messages to the Claude API and retrieves a response. It handles
        # string-based or array-based inputs, dynamically constructs the request body and headers,
        # and parses the response for the AI's output. If errors occur, the method retries the query.
        #
        # @param api_key [String] The API key for accessing the Claude API.
        # @param messages [String, Array<Hash>] The user input to be sent to the Claude API. If a string
        #   is provided, it is converted into an array of message hashes with `role` and `content` keys.
        # @param budget_tokens [Integer] The maximum number of tokens for internal reasoning (default: 4096).
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
        def query_with_memory(api_key, messages, budget_tokens: CONFIG[:anthropic_thinking_budget])
          # Convert string input to array of message hashes if necessary
          messages = messages.instance_of?(String) ? [{ role: 'user', content: messages }] : messages

          # Define headers for the API request
          headers = {
            'x-api-key' => api_key,
            'anthropic-version' => '2023-06-01',
            'content-type' => 'application/json',
            'anthropic-beta' => 'prompt-caching-2024-07-31'
          }

          # Construct the request body
          body = {
            'model': CONFIG[:anthropic_gpt_model],
            'max_tokens': CONFIG[:anthropic_max_tokens],
            'messages': messages,
            'thinking': {
              'type': 'enabled',
              'budget_tokens': budget_tokens
            }
          }

          begin
            # Send the POST request to the Claude API
            response = HTTParty.post(
              'https://api.anthropic.com/v1/messages',
              headers: headers,
              body: body.to_json
            )
          rescue => e
            puts "Error: #{e.class}: '#{e.message}'. Retrying query..."
            sleep 10
            return query_with_memory(api_key, messages, budget_tokens: budget_tokens)
          end

          # Avoid race conditions and token throttling
          sleep 1

          # Parse the response safely
          begin
            response_body = JSON.parse(response.body)
          rescue JSON::ParserError => e
            puts "Error parsing JSON: #{e.message}"
            sleep 10
            return query_with_memory(api_key, messages, budget_tokens: budget_tokens)
          end

          # Handle different response scenarios
          if response_body.key?('error')
            puts "API Error: #{response_body['error']['message']}"
            sleep 10
            return query_with_memory(api_key, messages, budget_tokens: budget_tokens)
          elsif !response_body.key?('content')
            puts "Error: No 'content' key in response."
            ap response_body
            sleep 10
            return query_with_memory(api_key, messages, budget_tokens: budget_tokens)
          else
            content = response_body['content']
            unless content.is_a?(Array)
              puts "Error: 'content' is not an array."
              ap content
              sleep 10
              return query_with_memory(api_key, messages, budget_tokens: budget_tokens)
            end

            text_block = content.find { |block| block['type'] == 'text' }
            if text_block
              output = text_block['text']
            else
              puts "Error: No block with type 'text' found in content."
              ap content
              sleep 10
              return query_with_memory(api_key, messages, budget_tokens: budget_tokens)
            end
          end

          # Store and return the output
          @last_output = output
          output
        end

        # Sends a query to the Claude API to generate or update Rails code for specified files.
        #
        # This method interacts with the Claude API to generate or update code for multiple files
        # based on their types, inferred from file extensions. It constructs individual queries
        # per file and writes the generated code to the corresponding files on disk.
        #
        # @param api_key [String] The API key for accessing the Claude API.
        # @param prompt [String, nil] An optional initial prompt to start the code generation process.
        #
        # @return [void] Writes generated code to the specified files and provides previews.
        #
        # @example Generating Rails code with an initial prompt:
        #   api_key = "your_anthropic_api_key"
        #   prompt = "Create a login form using Fomantic-UI components."
        #   GPTK::AI::Claude.query_to_rails_code(api_key, prompt: prompt)
        #
        def query_to_rails_code(api_key, prompt: nil)
          # Retrieve file paths from config (assumed to be an array of strings)
          file_paths = GPTK::CONFIG[:rails_files]
          unless file_paths.is_a?(Array) && !file_paths.empty?
            raise "Invalid or missing file_paths in GPTK::CONFIG[:rails][:file_paths]"
          end

          # Define instructions for known file types
          type_instructions = {
            erb: 'Generate only pure ERB/HTML code for Rails using Fomantic-UI components. Do not include any markdown, code blocks, or explanatory text.',
            sass: 'Generate only pure SASS code for Rails (be sure to generate SASS syntax, not CSS or SCSS) using Fomantic-UI components. Do not include any markdown, code blocks, or explanatory text.',
            coffeescript: 'Generate only pure CoffeeScript code for Rails using Fomantic-UI components. Do not include any markdown, code blocks, or explanatory text.'
          }

          first_iteration = true

          loop do
            # Handle initial prompt or get user input
            if first_iteration && prompt
              current_prompt = prompt
              first_iteration = false
            else
              print "\nEnter prompt (or 'exit' to quit): "
              user_input = gets.chomp
              break if user_input.downcase == 'exit'
              puts 'Submitting query to Claude...'
              current_prompt = user_input
            end

            # Read current code states for all files
            current_codes = {}
            file_paths.each do |file_path|
              current_codes[file_path] = File.exist?(file_path) ? File.read(file_path) : 'No current code.'
            end

            # Generate code for each file
            file_paths.each do |file_path|
              type = get_file_type(file_path)
              if type == :unknown
                puts "Warning: Unknown file type for #{file_path}. Skipping."
                next
              end

              instruction = type_instructions[type] || "Generate only pure code for #{file_path}. Do not include any markdown, code blocks, or explanatory text."

              # Construct the full prompt
              current_codes_str = current_codes.map { |fp, code| "#{fp}:\n\n```\n#{code}\n```" }.join("\n\n")
              full_prompt = "#{instruction}\n\nCurrent code state:\n#{current_codes_str}\n\nAdditional requirements: #{current_prompt}\n\nUpdate the code for '#{file_path}'. Output ONLY the raw code without any formatting, explanation, or code delimiters."

              # Send query to Claude API with extended thinking
              messages = [{ role: 'user', content: full_prompt }]
              result = query_with_memory(api_key, messages)

              # Clean the response
              result = strip_code_blocks(result)

              # Write to file
              FileUtils.mkdir_p(File.dirname(file_path))
              File.write(file_path, result)

              # Show preview
              puts "\nGenerated code for #{file_path}"
              puts 'Preview of generated content:'
              puts '-' * 40
              puts result.lines.first(5).join
              puts '...' if result.lines.count > 5
              puts '-' * 40
            end
          end
        end

        private

        # Determines the file type based on its extension.
        #
        # @param file_path [String] The path to the file.
        # @return [Symbol] The file type (:erb, :sass, :coffeescript, or :unknown).
        def get_file_type(file_path)
          ext = File.extname(file_path).downcase
          case ext
          when '.erb' then :erb
          when '.sass' then :sass
          when '.coffee' then :coffeescript
          else :unknown
          end
        end

        # Removes markdown code blocks from the text if present.
        #
        # @param text [String] The text to process.
        # @return [String] The text with code blocks removed if they were present.
        def strip_code_blocks(text)
          lines = text.lines
          return text unless lines.first&.match?(/^```\w*$/) && lines.last&.match?(/^```$/)

          lines[1..-2].join
        end
      end
    end
  end
end