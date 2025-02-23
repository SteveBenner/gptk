# frozen_string_literal: true

module GPTK
  module AI
    # XAI's Grok interface
    module Grok
      class << self
        # Sends a query to the Grok API and retrieves the AI's response.
        #
        # This method constructs an HTTP request to the Grok API, sending a user prompt and optional
        # system instructions. It handles both single-string and array-based prompts, dynamically
        # builds the request payload, and parses the response for the AI's output. If errors occur,
        # the method retries the query.
        #
        # @param api_key [String] The API key for accessing the Grok API.
        # @param prompt [String, Array<String>] The user input to send to the Grok API. Can be a single string
        #   or an array of strings.
        # @param system_prompt [String, nil] Optional system-level instructions to prepend to the message array.
        #
        # @return [String] The AI's response text.
        #
        # @example Sending a single prompt to the Grok API:
        #   api_key = "your_grok_api_key"
        #   prompt = "Explain the importance of biodiversity."
        #   Grok.query(api_key, prompt)
        #   # => "Biodiversity is crucial for ecosystem resilience and human survival."
        #
        # @example Sending multiple prompts with a system instruction:
        #   api_key = "your_grok_api_key"
        #   prompt = ["What is AI?", "How does machine learning work?"]
        #   system_prompt = "You are an AI educator."
        #   Grok.query(api_key, prompt, system_prompt)
        #   # => "AI, or Artificial Intelligence, refers to the simulation of human intelligence in machines..."
        #
        # @note
        #   - The method retries queries in case of network or JSON parsing errors.
        #   - A delay (`sleep 1`) is included to prevent token throttling and race conditions.
        #   - The method supports both single-string and array-based prompts.
        #   - Currently, token usage tracking is marked as TODO.
        #
        # @raise [RuntimeError] If no valid response is received after multiple retries.
        # @raise [JSON::ParserError] If the response body cannot be parsed as JSON.
        #
        # @see HTTParty.post
        # @see JSON.parse
        #
        # @todo Look into and possibly write a fix for repeated JSON parsing errors (looping)
        def query(api_key, prompt, system_prompt = nil)
          headers = {
            'Authorization' => "Bearer #{api_key}",
            'content-type' => 'application/json'
          }
          messages = if prompt.instance_of?(Array)
                       prompt.collect { |p| { 'role': 'user', 'content': p } }
                     else
                       [{ 'role': 'user', 'content': prompt }]
                     end
          messages.prepend({ 'role': 'system', 'content': system_prompt }) if system_prompt
          body = {
            'model': CONFIG[:xai_gpt_model],
            'stream': false,
            'temperature': CONFIG[:xai_temperature],
            'messages': messages
          }

          max_retries = 5
          retries = 0

          begin
            response = HTTParty.post(
              'https://api.x.ai/v1/chat/completions',
              headers: headers,
              body: body.to_json
            )

            # Check if the response is nil or not successful
            raise "Unexpected response: #{response.inspect}" if response.nil? || response.code != 200

            parsed_response = JSON.parse(response.body)
            output = parsed_response.dig('choices', 0, 'message', 'content')

            raise "Empty or nil output received: #{parsed_response.inspect}" if output.nil? || output.empty?

            output
          rescue Net::ReadTimeout => e
            puts "Network timeout occurred: #{e.class}. Retrying query..."
            retries += 1
            raise 'Exceeded maximum retries due to timeout errors.' unless retries <= max_retries

            sleep(5)
            retry

          rescue JSON::ParserError => e
            puts "JSON parsing error: #{e.class}. Raw response: #{response&.body.inspect}\n Retrying query..."
            retries += 1
            raise 'Exceeded maximum retries due to JSON parsing errors.' unless retries <= max_retries

            sleep(5)
            retry
          rescue => e
            puts "Unexpected Error: #{e.class}: #{e.message}. Raw Response: #{response&.body.inspect}\nRetrying query.."
            retries += 1
            raise 'Exceeded maximum retries due to unexpected errors.' unless retries <= max_retries

            sleep(5)
            retry
          ensure
            @last_output = output || ''
          end
        end

        # Sends a query to the Grok API and retrieves the AI's response, optionally including file uploads for image analysis,
        # to generate Rails code (ERB, SASS, CoffeeScript) for a 4-quadrant layout using Fomantic-UI components.
        #
        # @param api_key [String] The API key for accessing the Grok API.
        # @param content_file [String, nil] Path to an image file for analysis (optional).
        # @param prompt [String, nil] The user input or additional instructions for the AI (optional).
        # @param model [String] The Grok model to use (defaults to CONFIG[:xai_gpt_model]).
        #
        # @return [void] Writes generated code to Rails files (ERB, SASS, CoffeeScript).
        #
        # @example Generating Rails code with an image upload:
        #   api_key = "your_grok_api_key"
        #   content_file = "/path/to/image.jpg"
        #   prompt = "Generate Rails code to display this image in the 4-quadrant layout and describe its content using Fomantic-UI components."
        #   Grok.query_to_rails_code(api_key, content_file: content_file, prompt: prompt)
        #
        # @note
        #   - Supports both text prompts and image file uploads for multimodal analysis.
        #   - Uses JSON payloads with base64-encoded images for image understanding via HTTParty.
        #   - Retries on network or JSON parsing errors, as in the `query` method.
        #   - Generates code incorporating image analysis results into the 4-quadrant layout.
        #
        # @raise [RuntimeError] If the API request fails or no valid response is received.
        # @raise [FileNotFoundError] If the content_file does not exist.
        #
        # @see HTTParty.post
        # @see JSON.parse
        def query_to_rails_code(api_key, content_file: nil, prompt: nil, model: CONFIG[:xai_gpt_model])
          file_paths = {
            erb: GPTK::CONFIG[:rails][:erb_file_path],
            sass: GPTK::CONFIG[:rails][:sass_file_path],
            coffee: GPTK::CONFIG[:rails][:coffeescript_file_path]
          }

          loop do
            current_prompt = if prompt
                               prompt
                             else
                               print "\nEnter additional prompt (or 'exit' to quit): "
                               user_input = gets.chomp
                               break if user_input.downcase == 'exit'

                               user_input
                             end

            file_paths.each do |type, file_path|
              base_prompt = case type
                            when :erb
                              'Generate only pure ERB/HTML code for Rails using Fomantic-UI components. Do not include \
                              any markdown, code blocks, or explanatory text. '
                            when :sass
                              'Generate only pure SASS code for Rails (be sure to generate SASS syntax, not CSS or \
                              SCSS) using Fomantic-UI components. Do not include any markdown, code blocks, or \
                              explanatory text. '
                            when :coffee
                              'Generate only pure CoffeeScript code for Rails using Fomantic-UI components. Do not include any markdown, code blocks, or explanatory text. '
                            else raise 'Invalid file type.'
                            end

              full_prompt = "#{base_prompt}Current code state:\n\n"

              if File.exist?(file_path)
                current_code = File.read(file_path)
                full_prompt += "#{current_code}\n\n"
              end

              full_prompt += "Additional requirements: #{current_prompt}\n\n"
              full_prompt += "If an image file is provided, incorporate its analysis into the 4-quadrant layout \
                             (e.g., display the image, use analysis results for descriptions or interactions). \
                             Remember: Output ONLY the raw code without any formatting, explanation or code delimiters."

              # Use upload_and_generate_response for image uploads, or generate_single_response for text-only prompts
              result = if content_file && File.exist?(content_file)
                         upload_and_generate_response(api_key, content_file, full_prompt, 'grok-2-vision-latest')
                       else
                         generate_single_response(api_key, full_prompt, model)
                       end

              # Strip code blocks if present
              result = strip_code_blocks(result)

              FileUtils.mkdir_p(File.dirname(file_path))
              File.write(file_path, result)

              puts "\nGenerated #{type.upcase} code written to: #{file_path}"
              puts 'Preview of generated content:'
              puts '-' * 40
              puts result.lines.first(5).join
              puts '...' if result.lines.count > 5
              puts "#{'-' * 40}\n"
            end

            break if prompt # Exit after one iteration if a prompt was provided
          end
        end

        private

        # Uploads an image file (base64-encoded) and generates a response from the Grok API for image understanding.
        #
        # @param api_key [String] The API key for accessing the Grok API.
        # @param content_file [String] Path to the image file to upload.
        # @param prompt [String] The prompt or instructions for the AI.
        # @param model [String] The Grok model to use (e.g., a vision model for image understanding).
        #
        # @return [String] The AI's response text, including image analysis results.
        #
        # @raise [FileNotFoundError] If the content_file does not exist.
        # @raise [RuntimeError] If the API request fails.
        def upload_and_generate_response(api_key, content_file, prompt, model)
          raise FileNotFoundError, "Image file not found: #{content_file}" unless File.exist?(content_file)

          # Read and encode the image file as base64
          file_content = File.read(content_file, mode: 'rb')
          base64_image = Base64.encode64(file_content).gsub(/\n/, '')

          # Construct the JSON payload with the image and prompt, as per the provided example
          body = {
            messages: [
              {
                role: 'user',
                content: [
                  {
                    type: 'image_url',
                    image_url: {
                      url: "data:image/jpeg;base64,#{base64_image}", # Adjust MIME type if needed (e.g., 'image/png')
                      detail: 'high'
                    }
                  },
                  {
                    type: 'text',
                    text: prompt
                  }
                ]
              }
            ],
            model: model,
            temperature: GPTK::AI::CONFIG[:xai_temperature],
            max_tokens: GPTK::AI::CONFIG[:xai_max_tokens]
          }.to_json

          # Headers for the request
          headers = {
            'Authorization' => "Bearer #{api_key}",
            'Content-Type' => 'application/json'
          }

          # Send the request using HTTParty, with retry logic
          max_retries = 5
          retries = 0

          begin
            response = HTTParty.post(
              'https://api.x.ai/v1/chat/completions',
              headers: headers,
              body: body,
              no_follow: true,
              raise_on: []
            )

            # Debug output
            unless response.success?
              puts "Debug: Response code: #{response.code}"
              puts "Debug: Response headers: #{response.headers.inspect}"
              puts "Debug: Full response body: #{response.body}"
              raise "API request failed: #{response.code} - #{response.body}"
            end

            # Parse the JSON response, expecting image analysis results
            parsed_response = JSON.parse(response.body)
            # Adjust based on actual response structure from xAI docs (e.g., 'choices', 'analysis', etc.)
            parsed_response.dig('choices', 0, 'message', 'content') || parsed_response['analysis'] || parsed_response['response']
          rescue Net::ReadTimeout, Errno::ETIMEDOUT, JSON::ParserError => e
            puts "Error uploading image or parsing response: #{e.class}. Retrying..."
            retries += 1
            raise 'Exceeded maximum retries due to errors.' unless retries <= max_retries

            sleep(5)
            retry
          rescue => e
            puts 'Full backtrace:'
            puts e.backtrace
            raise e
            puts "Unexpected error: #{e.class}: #{e.message}. Retrying..."
            retries += 1
            raise 'Exceeded maximum retries due to unexpected errors.' unless retries <= max_retries

            sleep(5)
            retry
          end
        end

        def strip_code_blocks(text)
          lines = text.lines

          # Return original text if it's not wrapped in code blocks
          return text unless lines.first&.match?(/^```\w*$/) && lines.last&.match?(/^```$/)

          # Remove first and last lines if they're code block markers
          lines = lines[1..-2] if lines.first.match?(/^```\w*$/) && lines.last.match?(/^```$/)

          # Join the remaining lines back together
          lines.join
        end

        def generate_single_response(api_key, prompt, model)
          headers = {
            'Authorization' => "Bearer #{api_key}",
            'Content-Type' => 'application/json'
          }

          body = {
            messages: [{
              role: 'user',
              content: prompt
            }],
            model: model,
            temperature: GPTK::CONFIG[:xai_temperature],
            max_tokens: GPTK::CONFIG[:xai_max_tokens]
          }

          response = HTTParty.post(
            'https://api.x.ai/v1/chat/completions',
            headers: headers,
            body: body.to_json
          )

          raise "API request failed: #{response.body}" unless response.success?

          response_data = JSON.parse(response.body)
          response_data.dig('choices', 0, 'message', 'content')
        end
      end
    end
  end
end
