# frozen_string_literal: true

module GPTK
  module AI
    # OpenAI's ChatGPT interface
    module ChatGPT
      # Sends a query to an AI client using a simple prompt and predefined configurations.
      #
      # This method wraps around the `AI.query` method to send a query to an AI client, using
      # predefined configurations such as model, temperature, and maximum tokens. The prompt
      # is packaged into a `messages` parameter, which is compatible with OpenAI's API.
      #
      # @param client [Object] The AI client instance, such as `OpenAI::Client`.
      # @param data [Hash] A hash for tracking token usage statistics. Keys include:
      #   - `:prompt_tokens` [Integer] Total tokens used in the prompt.
      #   - `:completion_tokens` [Integer] Total tokens generated by the AI.
      #   - `:cached_tokens` [Integer] Tokens retrieved from the cache, if applicable.
      # @param prompt [String] The text input from the user to be sent to the AI client.
      # @param model [String, nil] Optional model identifier to override the default model in CONFIG.
      #
      # @return [String] The AI's response message content as a string, returned by `AI.query`.
      #
      # @example Querying with a prompt:
      #   client = OpenAI::Client.new(api_key: "your_api_key")
      #   data = { prompt_tokens: 0, completion_tokens: 0, cached_tokens: 0 }
      #   prompt = "What is the capital of France?"
      #   GPTK.query(client, data, prompt)
      #   # => "The capital of France is Paris."
      #
      # @example Querying with a specific model:
      #   client = OpenAI::Client.new(api_key: "your_api_key")
      #   data = { prompt_tokens: 0, completion_tokens: 0, cached_tokens: 0 }
      #   prompt = "What is the capital of France?"
      #   GPTK.query(client, data, prompt, model: "gpt-4o")
      #   # => "The capital of France is Paris."
      #
      # @note
      #   - This method uses configurations defined in `CONFIG` for parameters such as model, temperature, and max_tokens.
      #   - The `data` hash is updated in-place with token usage statistics, but tracking is currently marked as TODO.
      #   - This method assumes the client is compatible with OpenAI's `messages` API structure.
      #
      # @todo Implement proper token usage tracking.
      #
      # @see AI.query
      #
      def self.query(client, data, prompt, model: nil)
        response = AI.query client, data, {
          model: model || CONFIG[:openai_gpt_model],
          temperature: CONFIG[:openai_temperature],
          max_completion_tokens: CONFIG[:openai_max_tokens],
          messages: [{ role: 'user', content: prompt }]
        }
        @last_output = response
        response
      end

      # Creates a new assistant using the specified client and configuration parameters.
      #
      # This method interacts with an AI client to create a virtual assistant. It accepts various
      # parameters, such as name, instructions, description, tools, tool resources, and metadata,
      # and dynamically builds the necessary configuration for the request. The method sends the
      # request to the client and returns the unique identifier of the newly created assistant.
      #
      # @param client [Object] The AI client instance, such as `OpenAI::Client`.
      # @param name [String] The name of the assistant to be created.
      # @param instructions [String] Specific instructions for the assistant to guide its behavior.
      # @param description [String, nil] A brief description of the assistant's purpose (optional).
      # @param tools [Array, nil] A list of tools available to the assistant (optional).
      # @param tool_resources [Hash, nil] Resources required for the tools (optional).
      # @param metadata [Hash, nil] Additional metadata to configure the assistant (optional).
      # @param model [String, nil] Optional model identifier to override the default model in CONFIG.
      #
      # @return [String] The unique identifier of the created assistant, as returned by the client.
      #
      # @example Creating an assistant with basic parameters:
      #   client = OpenAI::Client.new(api_key: "your_api_key")
      #   name = "ResearchBot"
      #   instructions = "Provide detailed answers for scientific queries."
      #   ChatGPT.create_assistant(client, name, instructions)
      #   # => "assistant_id_12345"
      #
      # @example Creating an assistant with a specific model:
      #   client = OpenAI::Client.new(api_key: "your_api_key")
      #   name = "ResearchBot"
      #   instructions = "Provide detailed answers for scientific queries."
      #   ChatGPT.create_assistant(client, name, instructions, model: "gpt-4o")
      #   # => "assistant_id_12345"
      #
      def self.create_assistant(client, name, instructions, description = nil, tools = nil, tool_resources = nil, metadata = nil, model: nil)
        parameters = {
          model: model || CONFIG[:openai_gpt_model],
          name: name,
          description: description,
          instructions: instructions
        }
        parameters.update( tools: tools ) if tools
        parameters.update( tool_resources: tool_resources ) if tool_resources
        parameters.update( metadata: metadata ) if metadata
        response = client.assistants.create parameters: parameters
        @last_output = response
        response['id']
      end

      # Executes a thread-based assistant interaction using the given prompts.
      #
      # This method manages the interaction with an AI assistant by populating a thread
      # with user messages, initiating a run, and handling the response processing. It
      # supports both single-string and array-based prompts. The method polls the status
      # of the run, retrieves messages, and returns the final assistant response.
      #
      # @param client [Object] The AI client instance, such as `OpenAI::Client`.
      # @param prompts [String, Array<String>] The user prompts to populate the thread. Can be a single string
      #   or an array of strings.
      # @param assistant_id [String, nil] The unique identifier of the assistant to execute the run.
      # @param model [String, nil] Optional model identifier to override the default model in CONFIG.
      #
      # @return [String] The final assistant response text.
      #
      # @example Running an assistant thread with a single prompt:
      #   client = OpenAI::Client.new(api_key: "your_api_key")
      #   prompts = "What are the benefits of regular exercise?"
      #   ChatGPT.run_assistant_thread(client, prompts)
      #   # => "Regular exercise improves physical health, mental well-being, and overall quality of life."
      #
      # @example Running an assistant thread with a specific model:
      #   client = OpenAI::Client.new(api_key: "your_api_key")
      #   prompts = "What are the benefits of regular exercise?"
      #   ChatGPT.run_assistant_thread(client, prompts, model: "gpt-4o")
      #   # => "Regular exercise improves physical health, mental well-being, and overall quality of life."
      #
      def self.run_assistant_thread(client, prompts, assistant_id: nil, model: GPTK::AI::CONFIG[:openai_gpt_model])
        raise 'Error: no prompts given!' if prompts.empty?

        # Create the Assistant if it does not exist already
        unless assistant_id
          assistant_id = if client.assistants.list['data'].empty?
                           response = client.assistants.create(
                             parameters: {
                               model: model,
                               name: 'AI Book generator',
                               description: 'AI Book generator',
                               instructions: @instructions
                             }
                           )
                           response['id']
                         else
                           client.assistants.list['data'].first['id']
                         end
        end

        # Create the Thread
        response = client.threads.create
        thread_id = response['id']

        # Populate the thread with messages using given prompts
        if prompts.instance_of? String
          client.messages.create thread_id: thread_id,
            parameters: { role: 'user', content: prompts }
        else # Array
          prompts.each do |prompt|
            client.messages.create thread_id: thread_id,
              parameters: { role: 'user', content: prompt }
          end
        end

        # Create a run using given thread
        run_params = { assistant_id: assistant_id }
        run_params[:model] = model if model # Add model parameter if specified
        response = client.runs.create thread_id: thread_id, parameters: run_params
        run_id = response['id']

        # Loop while awaiting status of the run
        messages = []
        loop do
          response = client.runs.retrieve id: run_id, thread_id: thread_id
          @last_output = response
          status = response['status']

          case status
          when 'queued', 'in_progress', 'cancelling'
            puts 'Processing...'
            sleep 1
          when 'completed'
            order = 'asc'
            limit = 100
            initial_response = client.messages.list(thread_id: thread_id, parameters: { order: order, limit: limit })
            messages.concat initial_response['data']
            # TODO: FINISH THIS (multi-page paging for messages)
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
          else
            puts "Unknown status response: #{status}"
            break
          end
        end

        # Return the response text received from the Assistant after processing the run
        response = messages.last['content'].first['text']['value']
        bad_response = prompts.instance_of?(String) ? (response == prompts) : (prompts.include? response)
        while bad_response
          puts 'Error: echoed response detected from ChatGPT. Retrying...'
          sleep 10
          response = run_assistant_thread client, 'Avoid repeating the input. Turn over to Claude.'
        end
        return '' if bad_response

        sleep 1 # Important to avoid race conditions and token throttling!
        @last_output = response
        response
      end

      # Queries an OpenAI Assistant using raw HTTP requests to the Assistants API.
      #
      # This method sends a prompt to an assistant via the OpenAI Assistants API, using an existing thread
      # or creating a new one if none is provided. If a new thread is created, it updates CONFIG[:chatgpt_thread].
      #
      # @param api_key [String] The API key for authenticating with OpenAI.
      # @param assistant_id [String] The ID of the assistant to query.
      # @param prompt [String] The user input prompt to send to the assistant.
      # @param thread_id [String, nil] The thread ID to use; defaults to CONFIG[:chatgpt_thread]. If nil, creates a new thread.
      # @param model [String] The model to use, defaults to CONFIG[:openai_gpt_model].
      #
      # @return [String] The assistant's response text.
      #
      # @example Querying with an existing thread:
      #   api_key = "your_openai_api_key"
      #   assistant_id = "asst_Yoc4YPEcDjGryavKVOaxcRKn"
      #   prompt = "What is the capital of France?"
      #   thread_id = "thread_123"
      #   response = GPTK::AI::ChatGPT.query_with_assistant(api_key, assistant_id, prompt, thread_id: thread_id)
      #   # => "The capital of France is Paris."
      #
      # @example Querying with a new thread:
      #   response = GPTK::AI::ChatGPT.query_with_assistant(api_key, assistant_id, prompt)
      #   # Creates new thread and updates CONFIG[:chatgpt_thread]
      #
      # @note
      #   - Uses HTTParty for raw HTTP requests.
      #   - Polls run status with a 2-second delay until completion.
      #   - Updates CONFIG[:chatgpt_thread] if a new thread is created.
      #
      # @raise [RuntimeError] If the API returns an error or the response cannot be parsed.
      def self.query_with_assistant(api_key, assistant_id, prompt, thread_id: GPTK::AI::CONFIG[:chatgpt_thread], model: GPTK::AI::CONFIG[:openai_gpt_model])
        base_url = 'https://api.openai.com/v1'
        headers = {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}",
          'OpenAI-Beta' => 'assistants=v2' # Required for Assistants API v2
        }

        # Step 1: Use existing thread or create a new one
        if thread_id.nil?
          thread_response = HTTParty.post(
            "#{base_url}/threads",
            headers: headers,
            body: {}.to_json
          )
          unless thread_response.success?
            raise "Failed to create thread: #{thread_response.code} - #{thread_response.body}"
          end
          thread_id = JSON.parse(thread_response.body)['id']
          # Update CONFIG[:chatgpt_thread] for continuity
          GPTK::AI::CONFIG[:chatgpt_thread] = thread_id
          puts "Created new thread: #{thread_id}"
        end

        # Step 2: Add the prompt as a message to the thread
        message_response = HTTParty.post(
          "#{base_url}/threads/#{thread_id}/messages",
          headers: headers,
          body: {
            role: 'user',
            content: prompt
          }.to_json
        )
        unless message_response.success?
          raise "Failed to add message: #{message_response.code} - #{message_response.body}"
        end

        # Step 3: Run the assistant on the thread
        run_response = HTTParty.post(
          "#{base_url}/threads/#{thread_id}/runs",
          headers: headers,
          body: {
            assistant_id: assistant_id,
            model: model
          }.to_json
        )
        unless run_response.success?
          raise "Failed to create run: #{run_response.code} - #{run_response.body}"
        end
        run_id = JSON.parse(run_response.body)['id']

        # Step 4: Poll the run status until completed
        loop do
          status_response = HTTParty.get(
            "#{base_url}/threads/#{thread_id}/runs/#{run_id}",
            headers: headers
          )
          unless status_response.success?
            raise "Failed to retrieve run status: #{status_response.code} - #{status_response.body}"
          end
          status = JSON.parse(status_response.body)['status']
          break if status == 'completed'
          if %w[cancelled failed expired].include?(status)
            raise "Run failed with status '#{status}': #{status_response.body}"
          end
          sleep 2 # Wait 2 seconds before polling again
        end

        # Step 5: Retrieve the assistant's response
        messages_response = HTTParty.get(
          "#{base_url}/threads/#{thread_id}/messages",
          headers: headers
        )
        unless messages_response.success?
          raise "Failed to retrieve messages: #{messages_response.code} - #{messages_response.body}"
        end
        messages = JSON.parse(messages_response.body)['data']
        assistant_message = messages.find { |msg| msg['role'] == 'assistant' }
        unless assistant_message
          raise "No assistant response found in thread: #{messages_response.body}"
        end

        assistant_message['content'].first['text']['value']
      end

      def self.run_batch(client, prompts, model: nil)
        # Create the batch file, a temporary file named `batch.jsonl`
        puts 'Generating batch file...'
        generate_batch_file(prompts, model)

        # Upload the batch file, accounting for upload errors and confirming batch file creation
        puts 'Uploading batch file to ChatGPT...'
        batch_file = File.open 'batch.jsonl'
        timeout = 1
        begin
          batch_file.rewind if batch_file.closed? # Rewind or reopen file for upload
          response = client.files.upload parameters: { file: batch_file, purpose: 'batch' }
          batch_file_id = response['id']
          abort 'Error uploading file to ChatGPT.' unless batch_file_id
        rescue StandardError => e
          puts "Error: connection reset. Retrying with a timeout of #{timeout} seconds..."
          ap e.message
          sleep timeout # Exponential backoff could start at 1 second and double each time
          timeout *= 2
          batch_file = File.open 'batch.jsonl', 'r+' if e.instance_of?(IOError)
          retry
        end
        files = client.files.list['data']
        raise 'Error: no files found on ChatGPT!' if files.empty?

        # Submit the batch file for processing
        puts "Submitting Batch File '#{batch_file_id}' to ChatGPT..."
        response = client.batches.create(
          parameters: {
            input_file_id: batch_file_id,
            endpoint: '/v1/chat/completions',
            completion_window: '24h'
          }
        )
        batch_id = response['id']
        if batch_id
          puts "Successfully submitted Batch: '#{batch_id}'\nStatus: '#{response['status']}'"
        else abort 'Error submitting Batch File to ChatGPT.'
        end

        # Monitor the progress and status of the current batch being processed
        batch = {}
        until batch['completed_at'] do
          sleep GPTK::AI::CONFIG[:batch_ping_interval] # Wait a number of seconds before checking on the status of the batch
          batch = client.batches.retrieve id: batch_id
          unless batch['output_file_id']
            request_status = "#{batch['request_counts']['completed']} of #{batch['request_counts']['total']}"
            if batch['status'] == 'failed'
              ap batch
              raise 'Error: batch processing failed!'
            end
            puts "Batch status: '#{batch['status']}': #{request_status} requests processed..."
            next
          end
          next unless batch['error_file_id']

          error_response = client.files.content id: batch['error_file_id']
          raise "Error: #{error_response}" if error_response
          break if batch['output_file_id']
        end

        # Collect response output
        response_objects = client.files.content id: batch['output_file_id']
        raise "Error: no output found" unless response_objects

        puts "Successfully completed batch ID: '#{batch_id}'"

        # Count token usage
        $prompt_tokens = response_objects.reduce(0) do |sum, obj|
          sum + obj.dig('response', 'body', 'usage', 'prompt_tokens')
        end
        $completion_tokens = response_objects.reduce(0) do |sum, obj|
          sum + obj.dig('response', 'body', 'usage', 'completion_tokens')
        end
        $cached_tokens = response_objects.reduce(0) do |sum, obj|
          sum + obj.dig('response', 'body', 'usage', 'prompt_tokens_details', 'cached_tokens')
        end

        @last_output = response_objects
        response_objects.collect {|obj| obj.dig('response', 'body', 'choices').first['message']['content'] }
      end

      def self.initialize_assistant(client, model: nil)
        response = client.assistants.list
        return response['data'].first['id'] unless response['data'].empty?

        creation_response = client.assistants.create(parameters: {
          model: model || GPTK::AI::CONFIG[:openai_gpt_model],
          name: 'Rails Code Generator',
          description: 'An assistant for generating and refining Rails web code.',
          instructions: 'Generate Rails ERB, SASS, and CoffeeScript files based on user input or provided file content.'
        })
        creation_response['id']
      end

      def self.send_prompt_to_thread(client, thread_id, prompt)
        client.messages.create(thread_id: thread_id, parameters: { role: 'user', content: prompt })

        # Poll for the assistant's response
        loop do
          response = client.messages.list(thread_id: thread_id, parameters: { limit: 1, order: 'desc' })
          latest_message = response['data'].first
          return latest_message['content'] if latest_message && latest_message['role'] == 'assistant'

          sleep 1
        end
      end

      def self.query_to_rails_code(client, content_file: nil, assistant_id: nil, prompt: nil, model: nil)
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
        initial_prompt = <<~PROMPT
          Analyze the following base64-encoded JPG image and the current state of the code files provided below.
          Use the design elements from the image along with the existing code structure to generate updated code.
          ONLY output raw code in the specified format.
          Use SASS style without semicolons, reserve JavaScript for the CoffeeScript file, and avoid including it in ERB.

          Here is the base64-encoded image:
          #{base64_content}

          And here is the current state of the code files:
          #{current_code_snapshot}
        PROMPT

        # Use an existing assistant or create a new one
        assistant_id ||= client.assistants.create(
          name: 'Rails Code Generator',
          instructions: 'Generate Rails code based on the provided image, current code state, and user prompts.',
          model: model || GPTK::AI::CONFIG[:openai_gpt_model],
          tools: [{ type: 'code_interpreter' }] # Add necessary tools
        )['id']


        puts "Using assistant with ID: #{assistant_id}"

        # Create a new thread for the conversation
        thread_response = client.threads.create
        thread_id = thread_response['id']

        # Send the initial prompt to the thread
        client.messages.create(
          thread_id: thread_id,
          role: 'user',
          content: initial_prompt
        )


        puts "Thread created successfully with ID: #{thread_id}"

        # Start the user interaction loop
        loop do
          print 'Enter your prompt (type "exit" to quit): '
          user_input = gets.strip
          break if user_input.downcase == 'exit'

          # Process each file type for code generation
          file_types.each do |file_type, label|
            puts "Generating #{label} code..."

            # Add the user prompt for generating code for this file type
            client.messages.create(
              thread_id: thread_id,
              parameters: { role: 'user', content: "#{user_input}. Generate #{label} code." }
            )

            run_params = { assistant_id: assistant_id }
            run_params[:model] = model if model # Add model parameter if specified
            run_response = client.runs.create(thread_id: thread_id, parameters: run_params)
            run_id = run_response['id']

            # Poll the run status until the run is completed
            loop do
              status_response = client.runs.retrieve(id: run_id, thread_id: thread_id)
              status = status_response['status']
              break if status == 'completed'

              puts "Status: #{status}. Waiting..."
              sleep 2
            end

            # Retrieve and save the generated code
            messages = client.messages.list(thread_id: thread_id)
            latest_message = messages.data.last
            generated_code = (latest_message.content.first.text.value if latest_message&.content&.first&.text)

            if generated_code
              # Remove any Markdown formatting and extra whitespace
              generated_code = generated_code.gsub(/```.*\n/, '').strip

              file_path = GPTK::CONFIG[:rails]["#{file_type}_file_path".to_sym]
              File.write(file_path, generated_code)
              puts "Successfully wrote #{label} code to #{file_path}"
            else
              puts "Error: No #{label} code generated."
            end
          end
        end

        puts 'Rails code generation completed!'
      end

      def self.generate_batch_file(prompts, model = nil)
        model_to_use = model || GPTK::AI::CONFIG[:openai_gpt_model]

        File.open 'batch.jsonl', 'w' do |file|
          prompts.each_with_index do |prompt, i|
            json = {
              custom_id: "request-#{i + 1}",
              method: 'POST',
              url: '/v1/chat/completions',
              body: {
                model: model_to_use,
                messages: [{ role: 'user', content: prompt }],
                temperature: GPTK::AI::CONFIG[:openai_temperature],
                max_tokens: GPTK::AI::CONFIG[:max_tokens],
              }
            }.to_json
            if i == prompts.length - 1
              file.write json.chomp
            else
              file.puts json.chomp
            end
          end
          file
        end
      end
    end
  end
end
