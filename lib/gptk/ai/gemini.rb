# frozen_string_literal: true

module GPTK
  module AI
    # Google's Gemini interface
    module Gemini
      BASE_URL = 'https://generativelanguage.googleapis.com/v1beta'

      MIME_TYPES = {
        'gif' => 'image/gif',
        'jpg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp'
      }.freeze

      class << self
        # Sends a query to the Gemini API and retrieves the AI's response.
        #
        # This method constructs an HTTP request to the Gemini API, sending a user prompt and specifying
        # the model to use. It processes the response to extract the AI's output text. The method includes
        # retry logic to handle errors such as JSON parsing issues or bad responses.
        #
        # @param api_key [String] The API key for accessing the Gemini API.
        # @param prompt [String] The user input to be sent to the Gemini API.
        # @param model [String] The AI model to use for processing the prompt. Defaults to the value of
        #   `CONFIG[:google_gpt_model]`.
        #
        # @return [String] The AI's response text.
        #
        # @example Querying the Gemini API with a prompt:
        #   api_key = "your_gemini_api_key"
        #   prompt = "What is the role of photosynthesis in plants?"
        #   Gemini.query(api_key, prompt)
        #   # => "Photosynthesis allows plants to convert light energy into chemical energy stored in glucose."
        #
        # @note
        #   - The method retries queries in case of network errors or JSON parsing failures.
        #   - A delay (`sleep 1`) is included to prevent token throttling and race conditions.
        #   - Token usage tracking is marked as TODO.
        #
        # @raise [JSON::ParserError] If the response body cannot be parsed as JSON.
        # @raise [RuntimeError] If no valid response is received after multiple retries.
        #
        # @see HTTParty.post
        # @see JSON.parse
        def query(api_key, prompt, model = CONFIG[:google_gpt_model])
          model_name = model.sub('models/', '')
          url = "#{BASE_URL}/models/#{model_name}:generateContent"

          headers = {
            'Content-Type' => 'application/json',
            # Remove 'Bearer' prefix - Gemini uses the API key directly
            'x-goog-api-key' => api_key
          }


          body = {
            contents: [{
              parts: [{ text: prompt }]
            }]
          }

          begin
            response = HTTParty.post(url,
              body: body.to_json,
              headers: headers,
              debug_output: $stdout # This will show us the actual HTTP request/response
            )

            puts "Response code: #{response.code}"
            puts "Response body: #{response.body}"

            raise "API request failed with status #{response.code}: #{response.body}" unless response.success?

            parsed_response = JSON.parse(response.body)
            parsed_response.dig('candidates', 0, 'content', 'parts', 0, 'text')
          rescue JSON::ParserError => e
            puts "Failed to parse JSON response: #{e.message}"
            puts "Raw response body: #{response.body}"
            raise
          rescue => e
            puts "Unexpected error: #{e.class} - #{e.message}"
            raise
          end
        end

        # Sends a cached query to the Gemini API and retrieves the AI's response.
        #
        # TODO: RE-DOCUMENT THIS
        #
        # This method constructs an HTTP request to the Gemini API using the provided API key, body, and model.
        # It processes the response to extract the AI's output text. The method includes retry logic to handle
        # errors, such as JSON parsing failures or bad responses, and is designed for use with cached requests.
        #
        # @param api_key [String] The API key for accessing the Gemini API.
        # @param body [Hash] The request body to send to the Gemini API. This includes prompt data and other
        #   configuration options.
        # @param model [String] The AI model to use for processing the request. Defaults to the value of
        #   `CONFIG[:google_gpt_model]`.
        #
        # @return [String] The AI's response text.
        #
        # @example Sending a cached query to the Gemini API:
        #   api_key = "your_gemini_api_key"
        #   body = {
        #     'contents': [{ 'parts': [{ 'text': "What is the capital of Japan?" }] }]
        #   }
        #   Gemini.query_with_cache(api_key, body)
        #   # => "The capital of Japan is Tokyo."
        #
        # @note
        #   - The method retries queries in case of network errors or JSON parsing failures.
        #   - A delay (`sleep 1`) is included to prevent token throttling and race conditions.
        #   - The method is designed to work with cached queries and currently lacks explicit
        #     tracking functionality (marked as TODO).
        #
        # @raise [JSON::ParserError] If the response body cannot be parsed as JSON.
        # @raise [RuntimeError] If no valid response is received after multiple retries.
        #
        # @see HTTParty.post
        # @see JSON.parse
        def query_with_cache(api_key, body, model = CONFIG[:google_gpt_model])
          max_retries = 5
          retries = 0

          begin
            response = HTTParty.post(
              "#{BASE_URL}/#{model}:generateContent?key=#{api_key}",
              headers: { 'content-type' => 'application/json' },
              body: body.to_json
            )

            # Explicitly check the response body for nil or empty
            raise 'Unexpected response: Body is nil or empty.' if response.body.nil? || response.body.empty?

            # Parse the response to extract the output
            output = JSON.parse(response.body).dig('candidates', 0, 'content', 'parts', 0, 'text')

            # Check if the output is nil or empty
            raise "Empty or nil output received: #{response.body.inspect}" if output.nil? || output.empty?

            output
          rescue JSON::ParserError => e
            puts "JSON Parsing Error: #{e.class}: #{e.message}. Retrying..."
            retries += 1
            raise 'Exceeded maximum retries due to JSON parsing errors.' unless retries <= max_retries

            sleep(5)
            retry
          rescue Errno::ECONNRESET, Net::ReadTimeout => e
            puts "Network Error: #{e.class}: #{e.message}. Retrying..."
            retries += 1
            raise 'Exceeded maximum retries due to network errors.' unless retries <= max_retries

            sleep(5)
            retry
          rescue => e
            puts "Unexpected Error: #{e.class}: #{e.message}. Raw Response: #{response&.body.inspect}"
            retries += 1
            raise 'Exceeded maximum retries due to unexpected errors.' unless retries <= max_retries

            sleep(5)
            retry
          ensure
            @last_output = output
          end
        end

        def query_to_rails_code(api_key, content_file: nil, prompt: nil, model: CONFIG[:google_gpt_model])
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
                              "Generate only pure ERB/HTML code for Rails using semantic-ui components. Do not include any markdown, code blocks, or explanatory text. "
                            when :sass
                              "Generate only pure SASS code for Rails (be sure to generate sass syntax, not css or scss) using semantic-ui components. Do not include any markdown, code blocks, or explanatory text. "
                            when :coffee
                              "Generate only pure CoffeeScript code for Rails using semantic-ui components. Do not include any markdown, code blocks, or explanatory text. "
                            end

              full_prompt = "#{base_prompt}Current code state:\n\n"

              if File.exist?(file_path)
                current_code = File.read(file_path)
                full_prompt += "#{current_code}\n\n"
              end

              full_prompt += "Additional requirements: #{current_prompt}\n\n"
              full_prompt += "Remember: Output ONLY the raw code without any formatting, explanation, or code block delimiters."

              result = generate_single_response(api_key, content_file, full_prompt, model)

              # Strip code blocks if present
              result = strip_code_blocks(result)

              FileUtils.mkdir_p(File.dirname(file_path))
              File.write(file_path, result)

              puts "\nGenerated #{type.upcase} code written to: #{file_path}"
              puts "Preview of generated content:"
              puts "-" * 40
              puts result.lines.first(5).join
              puts "..." if result.lines.count > 5
              puts "-" * 40 + "\n"
            end

            break if prompt # Exit after one iteration if prompt was provided
          end
        end

        private

        def strip_code_blocks(text)
          lines = text.lines

          # Return original text if it's not wrapped in code blocks
          return text unless lines.first&.match?(/^```\w*$/) && lines.last&.match?(/^```$/)

          # Remove first and last lines if they're code block markers
          lines = lines[1..-2] if lines.first.match?(/^```\w*$/) && lines.last.match?(/^```$/)

          # Join the remaining lines back together
          lines.join
        end

        def generate_single_response(api_key, content_file, prompt, model)
          parts = [{ text: prompt }]

          if content_file && File.exist?(content_file)
            mime_type = 'image/jpeg'
            file_content = File.binread(content_file)
            base64_content = Base64.strict_encode64(file_content)

            parts << {
              inline_data: {
                mime_type: mime_type,
                data: base64_content
              }
            }
          end

          body = {
            contents: [{
              parts: parts
            }]
          }

          headers = {
            'Content-Type' => 'application/json',
            'x-goog-api-key' => api_key
          }

          response = HTTParty.post(
            "https://generativelanguage.googleapis.com/v1/models/#{model}:generateContent",
            body: body.to_json,
            headers: headers
          )

          if response.code != 200 || response.body.nil? || response.body.empty?
            raise "Unexpected response: #{response.body}"
          end

          parsed_response = JSON.parse(response.body)
          parsed_response.dig('candidates', 0, 'content', 'parts', 0, 'text')
        end
      end
    end
  end
end