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
        # and parses the response for the AI's output. If errors occur, the method retries the query
        # up to a maximum number of times, yielding retry counts to a block if provided.
        #
        # @param api_key [String] The API key for accessing the Claude API.
        # @param messages [String, Array<Hash>] The user input to be sent to the Claude API. If a string
        #   is provided, it is converted into an array of message hashes with `role` and `content` keys.
        #
        # @yield [retry_count] Yields the number of retries attempted to the caller for tracking purposes.
        # @return [String] The AI's response text.
        #
        # @example Sending a single message as a string:
        #   api_key = "your_anthropic_api_key"
        #   messages = "What is the capital of Italy?"
        #   Claude.query_with_memory(api_key, messages) { |retry_count| puts "Retry ##{retry_count}" }
        #   # => "The capital of Italy is Rome."
        #
        # @note
        #   - Retries are limited to 5 attempts for network errors, JSON parsing errors, or bad responses.
        #   - A delay (`sleep 10`) is used between retries to prevent throttling.
        #   - A final delay (`sleep 1`) avoids race conditions and token throttling.
        #
        # @raise [RuntimeError] If no valid response is received after maximum retries.
        #
        # @see HTTParty.post
        # @see JSON.parse
        def query_with_memory(api_key, messages)
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

          max_retries = 5
          retries = 0
          output = nil

          while retries <= max_retries
            begin
              response = HTTParty.post(
                'https://api.anthropic.com/v1/messages',
                headers: headers,
                body: body.to_json
              )
              output = JSON.parse(response.body).dig('content', 0, 'text')
              break unless output.nil? # Success if output is non-nil

              puts 'Error: Claude API provided a bad response. Retrying query...'
              retries += 1
              yield retries if block_given? # Report retry count
              sleep 10
            rescue => e # Catch all errors (network, JSON parsing, etc.)
              puts "Error: #{e.class}: '#{e.message}'. Retrying query..."
              retries += 1
              yield retries if block_given? # Report retry count
              sleep 10
            end
          end

          if output.nil?
            raise "Claude failed to provide a valid response after #{max_retries} retries."
          end

          sleep 1 # Avoid race conditions and token throttling
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
          # Retrieve file paths from config (now an array of strings)
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
              puts "\nEnter your prompt (paste multi-line text and press Ctrl-D (Unix) or Ctrl-Z (Windows) when done, or type 'exit' to quit):"
              input = String.new
              begin
                while (line = STDIN.gets)
                  # If the user types 'exit' on a line by itself, exit the loop
                  if line.strip.downcase == 'exit'
                    puts 'Exiting...'
                    return  # Exit the entire method
                  end
                  input << line
                end
              rescue EOFError
                # Ctrl-D (Unix) or Ctrl-Z (Windows) was pressed, proceed with the input
              end
              user_input = input.chomp
              if user_input.strip.empty?
                puts 'No input provided. Please try again.'
                next
              end
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

              # Send query to Claude API
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