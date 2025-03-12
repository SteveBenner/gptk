# frozen_string_literal: true

require 'thread'
require 'httparty'
require 'fileutils'
require 'awesome_print'

module GPTK
  module AI
    class AutoCoder
      attr_reader :clients, :failed_attempts

      def initialize(chat_gpt: nil, claude: nil, grok: nil, gemini: nil)
        @clients = {}
        @clients[:chat_gpt] = chat_gpt if chat_gpt # Store API key directly, no OpenAI::Client
        @clients[:claude] = claude if claude
        @clients[:grok] = grok if grok
        @clients[:gemini] = gemini if gemini
        @failed_attempts = Hash.new(0)
        @active_clients = @clients.keys.dup
        validate_clients
      end

      def query_to_rails_code(model: nil)
        raise 'No AI clients available. Please provide at least one valid API key.' if @clients.empty?

        rails_files_sets = fetch_rails_files_sets

        client_count = @clients.size
        rails_files_count = rails_files_sets.size
        unless client_count == rails_files_count
          error_message = "Mismatch detected: #{client_count} AI clients provided (#{@clients.keys.join(', ')}) but #{rails_files_count} rails_files_x arrays found in CONFIG. " \
            "Each client must correspond to exactly one rails_files_x list. " \
            "Please adjust the number of API keys passed to AutoCoder.new or modify CONFIG to have #{client_count} rails_files_x arrays."
          raise ArgumentError, error_message
        end

        client_assignments = assign_rails_files_to_clients(rails_files_sets)

        type_instructions = {
          erb: 'Generate only pure ERB/HTML code for Rails using Fomantic-UI components. Do not include any markdown, code blocks, or explanatory text.',
          sass: 'Generate only pure SASS code for Rails (be sure to generate SASS syntax, not CSS or SCSS) using Fomantic-UI components. Do not include any markdown, code blocks, or explanatory text.',
          coffeescript: 'Generate only pure CoffeeScript code for Rails using Fomantic-UI components. Do not include any markdown, code blocks, or explanatory text.'
        }

        results = {}
        puts "Starting interactive Rails code generation session..."

        loop do
          print "\nEnter your prompt (or type 'exit' to quit): "
          current_prompt = gets.chomp
          break if current_prompt.downcase == 'exit'
          next if current_prompt.strip.empty? && (puts "No input provided. Please try again.")

          results = {}
          threads = []

          client_assignments.each_with_index do |(client_name, assignment), index|
            next unless @active_clients.include?(client_name)

            threads << Thread.new do
              begin
                delay = index * 5
                puts "[#{client_name}] Waiting #{delay} seconds before querying..."
                sleep delay

                current_codes = read_current_codes(assignment[:rails_files])

                assignment[:rails_files].each do |file_path|
                  type = get_file_type(file_path)
                  next if type == :unknown

                  instruction = type_instructions[type] || "Generate only pure code for #{file_path}. Do not include any markdown, code blocks, or explanatory text."
                  full_prompt = build_full_prompt(instruction, current_codes, current_prompt, file_path)

                  result = with_retry(client_name) do
                    case client_name
                    when :chat_gpt
                      GPTK::AI::ChatGPT.query_with_assistant(
                        assignment[:client], # API key
                        'asst_Yoc4YPEcDjGryavKVOaxcRKn', # Fixed assistant ID
                        full_prompt,
                        model: model
                      )
                    when :claude then run_claude_query(assignment[:client], full_prompt, client_name)
                    when :grok then run_grok_query(assignment[:client], full_prompt, model, client_name)
                    when :gemini then run_gemini_query(assignment[:client], full_prompt, model, client_name)
                    else raise "Unsupported AI client: #{client_name}"
                    end
                  end

                  result = strip_code_blocks(result)
                  write_to_file(file_path, result)
                  display_preview(client_name, file_path, result)
                end

                results[client_name] = 'Success'
              rescue StandardError => e
                puts "[#{client_name}] Unexpected Error: #{e.class}: #{e.message}"
                puts "Stack trace:"
                puts e.backtrace.join("\n")
                if @last_response
                  puts "[#{client_name}] Last API Response Body:"
                  ap @last_response
                end
                results[client_name] = "Error: #{e.message}"
                @failed_attempts[client_name] += 1
                if @failed_attempts[client_name] >= 5
                  @active_clients.delete(client_name)
                  puts "\n[#{client_name}] Disabled due to 5 failed attempts."
                end
              end
            end
          end

          threads.each(&:join)
          display_results(results)
          puts "\nActive clients: #{@active_clients.join(', ')}" if @active_clients.size < @clients.size
          break if @active_clients.empty? && (puts "No active clients remaining. Exiting...")
        end

        puts "Exiting..."
        results
      end

      private

      def validate_clients
        @clients.each do |name, client|
          next unless client.is_a?(String)
          if name == :chat_gpt
            # Basic HTTP test for ChatGPT
            response = HTTParty.get(
              'https://api.openai.com/v1/models',
              headers: { 'Authorization' => "Bearer #{client}" }
            )
            unless response.success?
              raise "Invalid #{name} API key: #{response.code} - #{response.body}"
            end
          end
        end
      end

      def fetch_rails_files_sets
        sets = []
        i = 1
        while GPTK::CONFIG.key?("rails_files_#{i}".to_sym)
          sets << GPTK::CONFIG["rails_files_#{i}".to_sym]
          i += 1
        end
        raise 'No rails_files_x entries found in CONFIG. Please define at least one set of Rails files.' if sets.empty?
        sets
      end

      def assign_rails_files_to_clients(rails_files_sets)
        assignments = {}
        @clients.each_with_index do |(client_name, client), index|
          assignments[client_name] = { client: client, rails_files: rails_files_sets[index] }
        end
        assignments
      end

      def read_current_codes(rails_files)
        current_codes = {}
        rails_files.each do |file_path|
          current_codes[file_path] = File.exist?(file_path) ? File.read(file_path) : 'No current code.'
        end
        current_codes
      end

      def build_full_prompt(instruction, current_codes, current_prompt, file_path)
        current_codes_str = current_codes.map { |fp, code| "#{fp}:\n\n```\n#{code}\n```" }.join("\n\n")
        "#{instruction}\n\nCurrent code state of all files:\n#{current_codes_str}\n\nAdditional requirements: #{current_prompt}\n\nUpdate the code for '#{file_path}'. Output ONLY the raw code without any formatting, explanation, or code delimiters."
      end

      def with_retry(client_name, max_attempts = 3, delay = 5)
        attempts = 0
        begin
          yield
        rescue Net::ReadTimeout, Errno::ECONNRESET => e
          attempts += 1
          puts "[#{client_name}] Network Error: #{e.class}: '#{e.message}'. Retrying (#{attempts}/#{max_attempts})..."
          sleep(delay * attempts)
          retry if attempts < max_attempts
          raise "Failed after #{max_attempts} attempts: #{e.message}"
        rescue StandardError => e
          raise e
        end
      end

      def run_claude_query(api_key, full_prompt, client_name)
        puts "[#{client_name}] Querying Claude..."
        messages = [{ role: 'user', content: full_prompt }]
        response = GPTK::AI::Claude.query_with_memory(api_key, messages) do |retry_count|
          if retry_count > 0
            @failed_attempts[client_name] += 1
            puts "[#{client_name}] Retry attempt ##{retry_count} (Failed attempts: #{@failed_attempts[client_name]}/5)"
            if @failed_attempts[client_name] >= 5
              @active_clients.delete(client_name)
              puts "\n[#{client_name}] Disabled due to 5 failed attempts from bad responses."
              raise "Claude exceeded failure limit"
            end
          end
        end
        @last_response = response
        raise "Claude returned nil response" if response.nil?
        response
      end

      def run_grok_query(api_key, full_prompt, model, client_name)
        puts "[#{client_name}] Querying Grok..."
        response = GPTK::AI::Grok.query(api_key, full_prompt) do |retry_count|
          if retry_count > 0
            @failed_attempts[client_name] += 1
            puts "[#{client_name}] Retry attempt ##{retry_count} (Failed attempts: #{@failed_attempts[client_name]}/5)"
            if @failed_attempts[client_name] >= 5
              @active_clients.delete(client_name)
              puts "\n[#{client_name}] Disabled due to 5 failed attempts from bad responses."
              raise "Grok exceeded failure limit"
            end
          end
        end
        @last_response = response
        response
      end

      def run_gemini_query(api_key, full_prompt, model, client_name)
        puts "[#{client_name}] Querying Gemini..."
        body = {
          contents: [{
            parts: [{ text: full_prompt }]
          }]
        }
        response = GPTK::AI::Gemini.query_with_cache(api_key, body, model || GPTK::AI::CONFIG[:google_gpt_model]) do |retry_count|
          if retry_count > 0
            @failed_attempts[client_name] += 1
            puts "[#{client_name}] Retry attempt ##{retry_count} (Failed attempts: #{@failed_attempts[client_name]}/5)"
            if @failed_attempts[client_name] >= 5
              @active_clients.delete(client_name)
              puts "\n[#{client_name}] Disabled due to 5 failed attempts from bad responses."
              raise "Gemini exceeded failure limit"
            end
          end
        end
        @last_response = response
        raise "Gemini returned nil response" if response.nil?
        response
      end

      def get_file_type(file_path)
        ext = File.extname(file_path).downcase
        case ext
        when '.erb' then :erb
        when '.sass' then :sass
        when '.coffee' then :coffeescript
        else :unknown
        end
      end

      def strip_code_blocks(text)
        lines = text.lines
        return text unless lines.first&.match?(/^```\w*$/) && lines.last&.match?(/^```$/)
        lines[1..-2].join
      end

      def write_to_file(file_path, content)
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, content)
      end

      def display_preview(client_name, file_path, content)
        puts "\n[#{client_name}] Generated code for #{file_path}"
        puts 'Preview of generated content:'
        puts '-' * 40
        puts content.lines.first(5).join
        puts '...' if content.lines.count > 5
        puts '-' * 40
      end

      def display_results(results)
        puts "\nResults for this iteration:"
        results.each { |client_name, result| puts "#{client_name}: #{result}" }
      end
    end
  end
end
