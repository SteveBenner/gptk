# frozen_string_literal: true

module GPTK
  module AI
    # XAI's Grok interface
    module Grok
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
      def self.query(api_key, prompt, system_prompt = nil)
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
          puts "Unexpected Error: #{e.class}: #{e.message}. Raw Response: #{response&.body.inspect}\nRetrying query..."
          retries += 1
          raise 'Exceeded maximum retries due to unexpected errors.' unless retries <= max_retries

          sleep(5)
          retry
        ensure
          @last_output = output
        end
      end
    end
  end
end
