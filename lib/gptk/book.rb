require 'httparty'
module GPTK
  # The `Book` class provides functionality to generate, analyze, revise, and save a novel
  # using AI tools like ChatGPT, Claude, Grok, and Gemini. It integrates these AI agents to
  # generate story chapters, revise content, and analyze text patterns for coherence and quality.
  #
  # @attr_reader [Array] chapters
  #   An array storing the generated chapters of the book.
  # @attr_reader [Object] chatgpt_client
  #   The client object for interacting with ChatGPT.
  # @attr_reader [Object] claude_client
  #   The client object for interacting with Claude.
  # @attr_reader [String] last_output
  #   Stores the last generated output, typically the most recently generated chapters.
  # @attr_reader [String] agent
  #   The name of the AI agent currently being used.
  # @attr_accessor [Hash] parsers
  #   Stores parser configurations for text processing and analysis.
  # @attr_accessor [String, nil] output_file
  #   The file path to save the generated chapters.
  # @attr_accessor [String] genre
  #   The genre of the novel being generated.
  # @attr_accessor [String, nil] instructions
  #   Instructions or contextual guidance for the AI agent.
  # @attr_accessor [String] outline
  #   The outline for the novel, used as a reference for generating content.
  # @attr_accessor [String] training
  #   Training data or examples used to guide AI-generated content.
  #
  # @note
  #   This class supports dynamic interactions with multiple AI agents and handles retries for failed API requests.
  #
  # === Features
  # - Generate a novel chapter by chapter or in fragments.
  # - Use AI tools to analyze text for patterns or repetitions.
  # - Apply revisions to content using predefined or custom operations.
  # - Save the generated content to a file and output runtime statistics.
  # - Flexible support for multiple AI agents.
  #
  # === Dependencies
  # - Requires external libraries for AI integration (`HTTParty`).
  #
  # === Workflow
  # 1. Initialize the class with the required AI clients, API keys, and configurations.
  # 2. Use `generate`, `generate_zipper`, or `generate_chapter` to produce chapters.
  # 3. Use `analyze_text` or `revise_chapter` to refine or analyze the content.
  # 4. Save the generated content to a file using `save`.
  class Book
    $chapters, $outline, $last_output = [], '', nil
    attr_reader :chapters, :chatgpt_client, :claude_client, :last_output, :agent
    attr_accessor :parsers, :output_file, :genre, :instructions, :outline, :training

    # Initializes a new instance of the `Book` class.
    #
    # @param [String] outline
    #   The outline for the novel. Can be a file path or plain text.
    # @param [Object, nil] openai_client
    #   The client object for ChatGPT. Default: `nil`.
    # @param [Object, nil] anthropic_client
    #   The client object for Claude. Default: `nil`.
    # @param [String, nil] anthropic_api_key
    #   The API key for accessing Claude. Default: `nil`.
    # @param [String, nil] xai_api_key
    #   The API key for accessing Grok. Default: `nil`.
    # @param [String, nil] google_api_key
    #   The API key for accessing Gemini. Default: `nil`.
    # @param [String, nil] instructions
    #   Instructions or guidance for the AI agent. Default: `nil`.
    # @param [String, nil] output_file
    #   The file path to save the generated chapters. Default: `nil`.
    # @param [String, nil] rec_prompt
    #   Optional recommendations for prompts. Default: `nil`.
    # @param [String, nil] genre
    #   The genre of the novel. Default: `nil`.
    # @param [Hash] parsers
    #   Configurations for parsers. Default: `CONFIG[:parsers]`.
    #
    # @note
    #   - At least one AI client or API key is required to initialize the class.
    #   - Handles file encoding for UTF-8 compliance.
    #
    # @example Initializing the `Book` class
    #   book = Book.new(
    #     "path/to/outline.txt",
    #     openai_client: chatgpt_instance,
    #     anthropic_client: claude_instance,
    #     genre: "science fiction"
    #   )
    def initialize(outline,
                   openai_client: nil,
                   anthropic_client: nil,
                   anthropic_api_key: nil,
                   xai_api_key: nil,
                   google_api_key: nil,
                   instructions: nil,
                   output_file: nil,
                   rec_prompt: nil,
                   genre: nil,
                   parsers: CONFIG[:parsers])
      unless openai_client || anthropic_client || xai_api_key || google_api_key
        puts 'Error: You must pass in at least ONE AI agent client or API key to the `new` method.'
        return
      end
      @chatgpt_client = openai_client
      @claude_client = anthropic_client
      @anthropic_api_key = anthropic_api_key
      @xai_api_key = xai_api_key
      @google_api_key = google_api_key
      # Reference document for book generation
      outline = ::File.exist?(outline) ? ::File.read(outline) : outline
      @outline = outline.encode 'UTF-8', invalid: :replace, undef: :replace, replace: '?'
      # Instructions for the AI agent
      instructions = (::File.exist?(instructions) ? ::File.read(instructions) : instructions) if instructions
      @instructions = instructions.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?') if instructions
      @output_file = ::File.expand_path output_file if output_file
      @training = ::File.read ::File.expand_path("#{__FILE__}/../../../prompts/trainer-murder-mystery.txt")
      @genre = genre
      @parsers = parsers
      @rec_prompt = (::File.exist?(rec_prompt) ? ::File.read(rec_prompt) : rec_prompt) if rec_prompt
      @chapters = [] # Book content
      @agent = if @chatgpt_client
                 'ChatGPT'
               elsif @claude_client
                 'Claude'
               elsif @xai_api_key
                 'Grok'
               elsif @google_api_key
                 'Gemini'
               end
      @bad_api_calls = 0
      @data = { # Data points to track while generating a book chapter by chapter
        prompt_tokens: 0,
        completion_tokens: 0,
        cached_tokens: 0,
        word_counts: [],
        current_chapter: 1
      }
    end

    # Builds a generation prompt based on the fragment number and a provided base prompt.
    #
    # This method constructs a complete prompt for generating chapter fragments, selecting a predefined
    # generation template based on whether the fragment is the first one or a continuation.
    #
    # @param [String] prompt
    #   The base prompt to guide content generation. This typically includes context or specific instructions.
    #
    # @param [Integer] fragment_number
    #   The fragment number to determine which generation template to use:
    #   - `1` for the initial fragment.
    #   - Any other value for continuation fragments.
    #
    # @return [String]
    #   Returns the constructed prompt as a single string, combining the generation template and the base prompt.
    #
    # @example Building a prompt for the first fragment
    #   base_prompt = "Write the introduction to the chapter."
    #   generated_prompt = build_prompt(base_prompt, 1)
    #   # => "INITIAL_PROMPT Write the introduction to the chapter."
    #
    # @example Building a prompt for a continuation fragment
    #   base_prompt = "Continue the chapter narrative."
    #   generated_prompt = build_prompt(base_prompt, 2)
    #   # => "CONTINUE_PROMPT Continue the chapter narrative."
    #
    # @note
    #   - The method selects a predefined generation template:
    #     - `CONFIG[:initial_prompt]` for the first fragment.
    #     - `CONFIG[:continue_prompt]` for continuation fragments.
    #   - Combines the selected template with the provided base prompt using a space separator.
    #
    # === Workflow
    # 1. Determines the appropriate generation template based on the fragment number.
    # 2. Combines the selected template with the base prompt.
    # 3. Returns the constructed prompt.
    #
    # @raise [ArgumentError]
    #   Raises an error if the `fragment_number` is invalid (e.g., not an integer).
    def build_prompt(prompt, fragment_number)
      generation_prompt = (fragment_number == 1) ? CONFIG[:initial_prompt] : CONFIG[:continue_prompt]
      [generation_prompt, prompt].join ' '
    end

    # Parses a response text into a chapter fragment and a summary, applying optional parsers.
    #
    # This method processes a given text response to extract the main chapter fragment and its summary.
    # It optionally applies a set of parsers to correct or modify the fragment based on user-defined
    # rules.
    #
    # @param [String] text
    #   The text to parse, typically a response from an AI agent containing a chapter fragment and
    #   an optional summary.
    #
    # @param [Hash, nil] parsers
    #   A hash of parsers to apply to the extracted fragment. Each parser can have:
    #   - A search expression (`String` or `Regexp`) and a replacement (`String` or `Proc`).
    #   - `nil` to delete matches.
    #   Default: `nil`.
    #
    # @return [Hash{Symbol => String}]
    #   Returns a hash containing:
    #   - `:chapter_fragment` (String): The main content of the chapter fragment after parsing.
    #   - `:chapter_summary` (String, nil): The extracted summary, if present; otherwise, `nil`.
    #
    # @example Parsing a response without parsers
    #   response_text = "This is the chapter content.\n---\nThis is the summary."
    #   parsed = parse_response(response_text)
    #   # => { chapter_fragment: "This is the chapter content.", chapter_summary: "This is the summary." }
    #
    # @example Parsing a response with parsers
    #   response_text = "This is the chapter content.\n---\nThis is the summary."
    #   parsers = {
    #     search: [/chapter/i, 'section'],
    #     delete: [/summary/i, nil]
    #   }
    #   parsed = parse_response(response_text, parsers)
    #   # => { chapter_fragment: "This is the section content.", chapter_summary: nil }
    #
    # @note
    #   - The response is split into two parts:
    #     - The main chapter fragment (before the delimiter).
    #     - The chapter summary (after the delimiter).
    #   - Delimiters include dashes (`---`), Unicode dashes (`\p{Pd}`), or asterisks (`***`).
    #   - Parsers can be used to:
    #     - Replace text (`String` or `Proc`).
    #     - Remove unwanted text (`nil` as a replacement).
    #   - Unicode support is required for proper delimiter matching.
    #   - Due to the tendency of current AI models to produce hallucinations in output, significant
    #     reformatting of the output is sometimes required to ensure consistency
    #
    # === Workflow
    # 1. Splits the input text into the chapter fragment and summary using predefined delimiters.
    # 2. Applies user-defined parsers to modify the fragment.
    # 3. Returns the parsed fragment and summary as a hash.
    #
    # @raise [ArgumentError]
    #   Raises an error if the provided `parsers` hash contains invalid types
    def parse_response(text, parsers = nil)
      # Split the response based on the chapter fragment and the summary (requires Unicode support!)
      parts = text.split(/\n{1,2}\p{Pd}{1,3}|\*{1,3}\s?\n{1,2}/u)
      fragment = if parts.size > 1
                   summary = parts[1].strip
                   parts[0].strip
                 else
                   text
                 end

      if parsers
        # Fix all the chapter titles (the default output suffers from multiple issues)
        parsers.each do |parser|
          case parsers[parser[0][1]].class # Pass each case to String#gsub!
          # Search expression, and replacement string
          when String then fragment.gsub! parsers[parser][1][0], parsers[parser][0][1]
          # Proc to run against the current fragment
          when Proc   then fragment.gsub! parsers[parser][1][0], parsers[parser][0][1]
          # Search expression to delete from output
          when nil    then fragment.gsub! parsers[parser][1], ''
          else puts "Parser: '#{parser[0][1]}' is invalid. Use a String, a Proc, or nil."
          end
        end
      end

      { chapter_fragment: fragment, chapter_summary: summary }
    end

    # Outputs run metadata and statistics for the chapter generation process.
    #
    # This method logs key metrics about the chapter generation process, such as the total number
    # of chapters generated, word counts, token usage, and elapsed time. The output can be written
    # to a file, an IO stream, or the console.
    #
    # @param [String, File, IO, nil] file
    #   The destination for the output:
    #   - If a `String`, it is treated as a file path and output is appended to the file.
    #   - If a `File` or `IO`, output is written to the specified stream.
    #   - If `nil`, output is sent to `STDOUT`.
    #   Default: `nil`.
    #
    # @param [Time, nil] start_time
    #   The start time of the run, used to calculate the elapsed time. Default: `nil`.
    #
    # @return [void]
    #
    # @example Outputting run info to the console
    #   output_run_info
    #
    # @example Writing run info to a file
    #   output_run_info("output.log", start_time: Time.now)
    #
    # @note
    #   - Automatically handles appending to files or writing to IO streams.
    #
    # === Metrics Logged
    # - Total chapters generated.
    # - Total word count across all chapters.
    # - Token usage statistics:
    #   - Prompt tokens.
    #   - Completion tokens.
    #   - Cached tokens and percentage of cached tokens.
    # - Elapsed time (in minutes).
    # - Word count for each chapter.
    #
    # === Workflow
    # 1. Determines the appropriate output stream based on the `file` parameter.
    # 2. Logs overall statistics, including word counts and token usage.
    # 3. Outputs detailed word counts for each chapter.
    #
    # @raise [IOError]
    #   Raises an error if the specified file cannot be opened or written to.
    def output_run_info(file = nil, start_time: nil)
      io_stream = case file.class
                  when File then file
                  when String then ::File.open(file, 'a+')
                  when IO then ::File.open(file, 'a+')
                  else STDOUT
                  end
      io_stream.seek 0, IO::SEEK_END
      io_stream.puts "\nSuccessfully generated #{CONFIG[:num_chapters]} chapters, for a total of #{@data[:word_counts].reduce(&:+)} words.\n\n"
      io_stream.puts <<~STRING
        Total token usage:
        - Prompt tokens used: #{@data[:prompt_tokens]}
        - Completion tokens used: #{@data[:completion_tokens]}
        - Total tokens used: #{@data[:prompt_tokens] + @data[:completion_tokens]}
        - Cached tokens used: #{@data[:cached_tokens]}
        - Cached token percentage: #{((@data[:cached_tokens].to_f / @data[:prompt_tokens]) * 100).round 2}%
      STRING
      io_stream.puts "\nElapsed time: #{GPTK.elapsed_time start_time} minutes.\n\n"
      io_stream.puts "Words by chapter:"
      @data[:word_counts].each_with_index { |chapter_words, i| io_stream.puts "\nChapter #{i + 1}: #{chapter_words} words" }
    end

    # Write completed chapters to the output file
    def save
      if @chapters.empty? || @chapters.nil?
        puts 'Error: no content to write.'
        return
      end
      filename = GPTK::File.fname_increment "#{@output_file}-#{@agent}#{@agent == 'Grok' ? '.md' : '.txt'}"
      output_file = ::File.open(filename, 'w+')
      @chapters.each_with_index do |chapter, i|
        puts "Writing chapter #{i + 1} to file..."
        output_file.puts chapter.join("\n\n") + "\n\n"
      end
      puts "Successfully wrote #{@chapters.count} chapters to file: #{::File.path output_file}"
    end

    # Output a compiled String version of the book content
    def to_s
      @chapters.collect { |chapter| chapter.join }.join("\n\n")
    end

    # Generates a single chapter in fragments using multiple AI agents.
    #
    # This method produces a chapter by dividing it into fragments and generating content through
    # AI tools such as ChatGPT, Claude, Grok, and Gemini. It references a general prompt, training data,
    # and outlines to maintain narrative coherence and structure.
    #
    # @param [String] general_prompt
    #   The prompt to guide the generation of the chapter. It includes context and instructions for the AI agents.
    #
    # @param [String, nil] thread_id
    #   The ChatGPT thread ID used for managing conversation history. Default: `nil`.
    #
    # @param [String, nil] assistant_id
    #   The ChatGPT assistant ID for handling the generation session. Default: `nil`.
    #
    # @param [Integer] fragments
    #   The number of fragments to divide the chapter into. Default: `CONFIG[:chapter_fragments]`.
    #
    # @return [Array<String>]
    #   Returns an array of strings, where each string represents a fragment of the generated chapter.
    #
    # @example Generating a chapter with 5 fragments
    #   chapter = generate_chapter("Write the next chapter of the story.", fragments: 5)
    #
    # @example Using ChatGPT with a thread and assistant
    #   chapter = generate_chapter(
    #     "Write the next chapter of the story.",
    #     thread_id: "thread123",
    #     assistant_id: "assistant456",
    #     fragments: 3
    #   )
    #
    # @note
    #   - Supports multiple AI agents (ChatGPT, Claude, Grok, and Gemini) for chapter generation.
    #   - Manages agent-specific memory for context, including training data and previously generated fragments.
    #   - Iteratively generates chapter fragments and appends them to the final chapter array.
    #
    # === Workflow
    # 1. Initializes AI-specific memory with the outline, training data, and prior fragments.
    # 2. Iteratively generates chapter fragments using the specified AI agents:
    #    - ChatGPT manages threads and runs with dynamic prompts.
    #    - Claude utilizes in-memory queries for continuity.
    #    - Grok processes manual memory and context in the prompt.
    #    - Gemini caches memory and fragments for efficient processing.
    # 3. Updates AI-specific memory after generating each fragment.
    # 4. Returns the generated fragments as a complete chapter.
    #
    # === Memory Management
    # - ChatGPT: Uses thread-based memory and training data for context.
    # - Claude: Initializes ephemeral memory for chapter-specific references.
    # - Grok: Combines training data and prior fragments in manual memory.
    # - Gemini: Implements cache-based memory with token management.
    #
    # @raise [RuntimeError]
    #   Raises an error if `fragments` is not provided or AI API interactions fail.
    #
    # @todo
    #   - Add support for fallback mechanisms when one or more agents fail.
    #   - Enhance error handling for Gemini API interactions.
    def generate_chapter(general_prompt, thread_id: nil, assistant_id: nil, fragments: CONFIG[:chapter_fragments])
      raise "Error: 'fragments' is nil!" unless fragments
      messages = [] if @chatgpt_client
      chapter = []

      # Initialize ChatGPT with training data
      CHATGPT.messages.create thread_id: thread_id, parameters: {
        role: 'user',
        content: "TRAINING DATA:\n#{@training}\nEND OF TRAINING DATA"
      }

      # Initialize claude memory every time we run a chapter generation operation
      if @claude_client
        # Ensure `claude_memory` is always an Array with ONE element using cache_control type: 'ephemeral'
        cm = "FINAL OUTLINE:\n#{@outline}\nEND OF FINAL OUTLINE\n\nTRAINING DATA:\n#{@training}\nEND OF TRAINING DATA"
        claude_memory = { role: 'user', content: [{ type: 'text', text: cm, cache_control: { type: 'ephemeral' } }] }
      end

      # Initialize manual memory for Grok via the input prompt
      if @xai_api_key
        gp = "FINAL OUTLINE:\n#{@outline}\nEND OF FINAL OUTLINE\n\nTRAINING DATA:\n#{@training}\nEND OF TRAINING DATA"
        general_prompt = "#{gp}\n\n#{general_prompt}"
      end

      # Manage Gemini memory
      if @google_api_key
        data = "OUTLINE:\n#{@outline}\nEND OF OUTLINE\n\nTRAINING DATA:\n\n#{@training}\n\nEND OF TRAINING DATA"
        cache_data = Base64.strict_encode64 data
        # Ensure min token amount is present in cache object, otherwise it will throw an API error
        chars_to_add = GPTK::AI::CONFIG[:gemini_min_cache_tokens] * 7 - cache_data.size
        if chars_to_add > 0
          cache_data = Base64.strict_encode64 "#{'F' * chars_to_add}\n\n#{cache_data}"
        end
        request_payload = {
          model: 'models/gemini-1.5-flash-001',
          contents: [{
              role: 'user',
              parts: [{ inline_data: { mime_type: 'text/plain', data: cache_data } }]
            }],
          ttl: CONFIG[:gemini_ttl]
        }
        request_payload.update({ systemInstruction: { parts: [{ text: @instructions }] } }) if @instructions

        # Cache the content
        begin
          cache_response = HTTParty.post(
            "https://generativelanguage.googleapis.com/v1beta/cachedContents?key=#{@google_api_key}",
            headers: { 'Content-Type' => 'application/json' },
            body: request_payload.to_json
          )
          cache_response_body = JSON.parse cache_response.body
        rescue => e
          puts "Error: #{e.class}: '#{e.message}'. Retrying query..."
          sleep 10
          cache_response = HTTParty.post(
            "https://generativelanguage.googleapis.com/v1beta/cachedContents?key=#{@google_api_key}",
            headers: { 'Content-Type' => 'application/json' },
            body: request_payload.to_json
          )
          cache_response_body = JSON.parse cache_response.body
        end
        cache_name = cache_response_body['name']

        # Set up the payload
        payload = {
          contents: [{ role: 'user', parts: [{ text: general_prompt }] }],
          cachedContent: cache_name
        }
      end

      (1..fragments).each do |i|
        prompt = build_prompt general_prompt, i
        puts "Generating fragment #{i} using #{@agent}..."

        if @chatgpt_client # Using the Assistant API
          @chatgpt_client.messages.create(
            thread_id: thread_id,
            parameters: { role: 'user', content: prompt }
          )

          # Create the run
          response = @chatgpt_client.runs.create(
            thread_id: thread_id,
            parameters: { assistant_id: assistant_id }
          )
          run_id = response['id']

          # Loop while awaiting status of the run
          while true do
            response = @chatgpt_client.runs.retrieve id: run_id, thread_id: thread_id
            status = response['status']

            case status
            when 'queued', 'in_progress', 'cancelling'
              puts 'Processing...'
              sleep 1 # Wait one second and poll again
            when 'completed'
              messages = @chatgpt_client.messages.list thread_id: thread_id, parameters: { order: 'desc' }
              break # Exit loop and report result to user
            when 'requires_action'
              # Handle tool calls (see below)
            when 'cancelled', 'failed', 'expired'
              puts 'Error!'
              puts response['last_error'].inspect
              break
            else
              puts "Unknown status response: #{status}"
            end
          end
          chapter << "#{messages['data'].first['content'].first['text']['value']}\n\n"
        end

        if @claude_client
          claude_messages = [claude_memory, { role: 'user', content: prompt }]
          claude_fragment = "#{GPTK::AI::Claude.query_with_memory @anthropic_api_key, claude_messages}\n\n"
          claude_memory[:content].first[:text] << "\n\nFRAGMENT #{i}:\n#{claude_fragment}"
          chapter << claude_fragment
        end

        if @xai_api_key
          grok_prompt = "#{prompt}\n\nGenerate as much output as you can!"
          grok_fragment = "#{GPTK::AI::Grok.query(@xai_api_key, grok_prompt)}\n\n"
          chapter << grok_fragment
          general_prompt << "\n\nFRAGMENT #{i}:\n\n#{grok_fragment}"
        end

        if @google_api_key
          gemini_fragment = "#{GPTK::AI::Gemini.query_with_cache(@google_api_key, payload)}\n\n"
          chapter << gemini_fragment
          # Set up the cache with the latest generated chapter fragment added
          cache_data = Base64.strict_encode64 "\n\nFRAGMENT #{i}:\n\n#{gemini_fragment}#{cache_data}"
          request_payload = {
            model: 'models/gemini-1.5-flash-001',
            contents: [{
                         role: 'user',
                         parts: [{ inline_data: { mime_type: 'text/plain', data: cache_data } }]
                       }],
            ttl: CONFIG[:gemini_ttl]
          }

          # Remove old cache
          HTTParty.post(
            "https://generativelanguage.googleapis.com/v1beta/#{cache_name}?key=#{@google_api_key}"
          )

          # Create new, updated cache
          begin
            cache_response = HTTParty.post(
              "https://generativelanguage.googleapis.com/v1beta/cachedContents?key=#{@google_api_key}",
              headers: { 'Content-Type' => 'application/json' },
              body: request_payload.to_json
            )
            cache_response_body = JSON.parse cache_response.body
          rescue => e
            puts "Error: #{e.class}: '#{e.message}' Retrying query..."
            sleep 10
            cache_response = HTTParty.post(
              "https://generativelanguage.googleapis.com/v1beta/cachedContents?key=#{@google_api_key}",
              headers: { 'Content-Type' => 'application/json' },
              body: request_payload.to_json
            )
            cache_response_body = JSON.parse cache_response.body
          end
          cache_name = cache_response_body['name']

          # Set up the payload again
          payload = {
            contents: [{ role: 'user', parts: [{ text: general_prompt }] }],
            cachedContent: cache_name
          }
        end
      end

      if @google_api_key # Remove old cache (garbage collection)
        HTTParty.post(
          "https://generativelanguage.googleapis.com/v1beta/#{cache_name}?key=#{@google_api_key}"
        )
      end

      @data[:word_counts] << GPTK::Text.word_count(chapter.join "\n")
      @chapters << chapter
      chapter
    end

    # Generates a single chapter in fragments by alternating between ChatGPT and Claude.
    #
    # This method produces a chapter by dividing it into fragments, referencing the story outline,
    # training data, and previous chapters. It alternates between ChatGPT and Claude for generating
    # content to ensure diversity and coherence.
    #
    # @param [Integer] parity
    #   Determines which AI agent generates the current fragment:
    #   - `0` for ChatGPT.
    #   - `1` for Claude.
    #
    # @param [Integer] chapter_num
    #   The chapter number being generated.
    #
    # @param [String] thread_id
    #   The ChatGPT thread ID for maintaining context during fragment generation.
    #
    # @param [String] assistant_id
    #   The ChatGPT assistant ID for managing the current generation session.
    #
    # @param [Integer] fragments
    #   The number of fragments to divide the chapter into. Default: `GPTK::Book::CONFIG[:chapter_fragments]`.
    #
    # @param [Array<String>] prev_chapter
    #   The content of the previously generated chapter as an array of fragments.
    #   Used to maintain narrative continuity. Default: `[]`.
    #
    # @param [String] anthropic_api_key
    #   The API key for accessing Claude. Default: `@anthropic_api_key`.
    #
    # @return [Array<String>]
    #   Returns an array of strings, where each string is a fragment of the generated chapter.
    #
    # @example Generating a chapter with 5 fragments using alternating AI agents
    #   chapter = generate_chapter_zipper(0, 3, "thread123", "assistant456", 5)
    #
    # @example Generating a chapter while referencing a previous chapter
    #   prev_chapter = ["Fragment 1 of previous chapter.", "Fragment 2 of previous chapter."]
    #   chapter = generate_chapter_zipper(1, 4, "thread789", "assistant789", 4, prev_chapter)
    #
    # @note
    #   - Alternates between ChatGPT and Claude based on the `parity` parameter.
    #   - References the final outline, training data, and previously generated chapter fragments
    #     for narrative consistency.
    #   - Appends generated fragments to the AI-specific memory for context continuity.
    #
    # === Workflow
    # 1. Initializes memory for Claude with the outline and training data.
    # 2. Adds previously generated chapter fragments to the relevant AI memory:
    #    - ChatGPT uses thread-based memory.
    #    - Claude uses ephemeral memory updated with training and chapter context.
    # 3. Iteratively generates fragments using AI-specific prompts:
    #    - Fragment 1: Initializes the chapter.
    #    - Fragment `n`: Writes the conclusion of the chapter.
    #    - Intermediate fragments continue the narrative.
    # 4. Updates AI-specific memory with each generated fragment.
    # 5. Returns the complete chapter as an array of fragments.
    #
    # @raise [RuntimeError]
    #   Raises an error if AI API interactions fail or invalid configurations are detected.
    #
    # @todo
    #   - Add fallback mechanisms for agent-specific failures.
    def generate_chapter_zipper(parity, chapter_num, thread_id, assistant_id, fragments = GPTK::Book::CONFIG[:chapter_fragments], prev_chapter = [], anthropic_api_key: @anthropic_api_key)
      # Initialize claude memory every time we run a chapter generation operation
      # Ensure `claude_memory` is always an Array with ONE element using cache_control type: 'ephemeral'
      cm = "FINAL OUTLINE:\n#{@outline}\nEND OF FINAL OUTLINE\n\nTRAINING DATA:\n#{@training}\nEND OF TRAINING DATA"
      claude_memory = { role: 'user', content: [{ type: 'text', text: cm, cache_control: { type: 'ephemeral' } }] }

      # Add any previously generated chapter to the memory of the proper AI, and training data
      unless prev_chapter.empty?
        if parity.zero? # ChatGPT
          CHATGPT.messages.create thread_id: thread_id, parameters: {
            role: 'user',
            content: "TRAINING DATA:\n#{@training}\nEND OF TRAINING DATA"
          }
          CHATGPT.messages.create thread_id: thread_id, parameters: {
            role: 'user',
            content: "PREVIOUS CHAPTER:\n#{prev_chapter.join("\n\n")}"
          }
        else # Claude
          claude_memory[:content].first[:text] << "\n\nPREVIOUS CHAPTER:\n#{prev_chapter.join("\n\n")}"
        end
      end

      # Generate the chapter fragment by fragment
      meta_prompt = GPTK::Book::CONFIG[:meta_prompt]
      chapter = []
      (1..fragments).each do |j|
        # Come up with an initial version of the chapter, based on the outline and prior chapter
        chapter_gen_prompt = case j
                             when 1 then "Referencing the final outline, as well as training data, write the first part of chapter #{chapter_num} of the #{@genre} story. #{meta_prompt}"
                             when fragments then "Referencing the final outline, as well as training data, and the current chapter fragments, write the final conclusion of chapter #{chapter_num} of the #{@genre} story. #{meta_prompt}"
                             else "Referencing the final outline, as well as training data, and the current chapter fragments, continue writing chapter #{chapter_num} of the #{@genre} story. #{meta_prompt}"
                             end
        chapter << if parity.zero? # ChatGPT
                     parity = 1
                     fragment_text = GPTK::AI::ChatGPT.run_assistant_thread @chatgpt_client, thread_id, assistant_id, chapter_gen_prompt
                     claude_memory[:content].first[:text] << "\n\nCHAPTER #{chapter_num}, FRAGMENT #{j}:\n\n#{fragment_text}"
                     fragment_text
                   else # Claude
                     parity = 0
                     prompt_messages = [claude_memory, { role: 'user', content: chapter_gen_prompt }]
                     fragment_text = GPTK::AI::Claude.query_with_memory anthropic_api_key, prompt_messages
                     claude_memory[:content].first[:text] << "\n\nCHAPTER #{chapter_num}, FRAGMENT #{j}:\n\n#{fragment_text}"
                     CHATGPT.messages.create thread_id: thread_id, parameters: { role: 'user', content: fragment_text }
                     fragment_text
                   end
      end
      @chapters << chapter
      chapter # Array of Strings representing chapter fragments for one chapter
    end

    # Generates a novel with a specified number of chapters and optional fragments per chapter.
    #
    # This method automates the process of generating a novel by leveraging AI tools like ChatGPT.
    # It uses a pre-defined outline and instructions to produce chapters, optionally divided into fragments.
    #
    # @param [Integer] number_of_chapters
    #   The number of chapters to generate. Default: `CONFIG[:num_chapters]`.
    #
    # @param [Integer, nil] fragments
    #   The number of fragments to divide each chapter into. If `nil`, no fragmentation is applied.
    #   Default: `CONFIG[:chapter_fragments]`.
    #
    # @return [Array<String>]
    #   Returns an array containing the generated chapters, where each chapter is represented as a string.
    #
    # @example Generating a 5-chapter novel
    #   book = generate(5)
    #
    # @example Generating a novel with 10 chapters and 3 fragments per chapter
    #   book = generate(10, 3)
    #
    # @note
    #   - This method interacts with ChatGPT to create assistant sessions and threads for consistent multi-chapter generation.
    #   - The `fragments` parameter allows finer control over chapter content granularity.
    #   - The generated book and related metadata are cached for debugging and reuse.
    #
    # === Workflow
    # 1. Sets the number of chapters and fragments in the configuration.
    # 2. Initializes a ChatGPT assistant and thread if ChatGPT is the selected agent.
    # 3. Sends the novel outline to the AI for contextual reference.
    # 4. Iteratively generates chapters using AI prompts.
    # 5. Caches the final book and outputs metadata for analysis.
    #
    # @raise [RuntimeError]
    #   Raises an error if AI interactions fail or unexpected conditions occur during chapter generation.
    #
    # === Metadata Outputs
    # - Outputs run metadata, such as elapsed time and cached results, for debugging and analysis.
    # - Stores the book, outline, and last output in global and instance variables.
    #
    # === Internal Caching
    # - Caches the last operation’s result in `@last_output`.
    # - Caches the generated chapters globally in `$chapters` for further reference.
    def generate(number_of_chapters = CONFIG[:num_chapters], fragments = CONFIG[:chapter_fragments])
      start_time = Time.now
      CONFIG[:num_chapters] = number_of_chapters
      book = []
      begin
        puts "Generating a novel #{number_of_chapters} chapter(s) long." +
               (fragments ? " #{fragments} fragments per chapter." : '')
        puts 'Sending initial prompt, and GPT instructions...'

        if agent == 'ChatGPT'
          # Create the Assistant if it does not exist already
          assistant_id = if @chatgpt_client.assistants.list['data'].empty?
                          response = @chatgpt_client.assistants.create(
                             parameters: {
                               model: GPTK::AI::CONFIG[:openai_gpt_model],
                               name: 'AI Book generator',
                               description: 'AI Book generator',
                               instructions: @instructions
                             }
                           )
                           response['id']
                         else
                           @chatgpt_client.assistants.list['data'].first['id']
                         end

          # Create the Thread
          response = @chatgpt_client.threads.create
          thread_id = response['id']

          # Send the AI the book outline for future reference
          prompt = "The following text is the outline for a #{genre} novel I am about to generate. Use it as reference when processing future requests, and refer to it explicitly when generating each chapter of the book:\n\n#{@outline}"
          @chatgpt_client.messages.create(
            thread_id: thread_id,
            parameters: { role: 'user', content: prompt }
          )
        end

        # Generate as many chapters as are specified
        (1..number_of_chapters).each do |i|
          puts "Generating chapter #{i}..."
          prompt = "Generate a fragment of chapter #{i} of the book, referring to the outline already supplied. Utilize as much output length as possible when returning content. Output ONLY raw text, no JSON or HTML."
          book << generate_chapter(prompt, thread_id: thread_id, assistant_id: assistant_id, fragments: fragments)
        end

        # Cache result of last operation
        @last_output = book

        book
      ensure
        # Output some metadata - useful information about the run, API status, book content, etc.
        output_run_info start_time: start_time
        $chapters = book if $chapters
        $outline = @outline if $outline
        $last_output = @last_output if $last_output
        @chatgpt_client.threads.delete id: thread_id if @agent == 'ChatGPT' # Garbage collection
      end
    end

    # Generates a specified number of chapters for a novel using AI agents.
    #
    # This method automates the process of generating a novel with the specified number of chapters.
    # It integrates with AI tools like ChatGPT and Claude, leveraging a pre-defined outline and instructions
    # to produce coherent and consistent story chapters.
    #
    # @param [Integer] number_of_chapters
    #   The number of chapters to generate. Default: `CONFIG[:num_chapters]`.
    #
    # @param [Integer] fragments
    #   The number of fragments to divide each chapter into. Default: `1`.
    #
    # @return [Array<String>]
    #   Returns an array of generated chapters, where each chapter is a string.
    #
    # @example Generating a 10-chapter novel
    #   chapters = generate_zipper(10)
    #
    # @example Generating chapters with multiple fragments
    #   chapters = generate_zipper(5, 3)
    #
    # @note
    #   - The method initializes or updates ChatGPT and Claude sessions for chapter generation.
    #   - Uses a parity system to alternate between agents or approaches for chapter creation.
    #   - Caches the last output for reuse or debugging.
    #
    # @todo
    #   - Add support for additional AI agents in future implementations.
    #
    # === Workflow
    # 1. Sets the number of chapters in the configuration.
    # 2. Prepares the AI prompt using the provided outline and instructions.
    # 3. Interacts with ChatGPT to create and manage assistant sessions and threads.
    # 4. Initializes Claude memory for coherent multi-chapter generation.
    # 5. Iteratively generates chapters while alternating parity for variety.
    # 6. Cleans up AI threads and outputs metadata for analysis.
    #
    # @raise [RuntimeError]
    #   Raises an error if AI interactions fail or unexpected conditions occur during chapter generation.
    #
    # === Metadata Outputs
    # - Outputs run metadata, such as elapsed time and Claude memory word count, for debugging and analysis.
    # - Caches generated chapters and outline in global variables for reference.
    #
    # === Internal Caching
    # - The last generated chapter and the full set of chapters are cached in `@last_output` and `@book`, respectively.
    def generate_zipper(number_of_chapters = CONFIG[:num_chapters], fragments = 1)
      start_time = Time.now
      CONFIG[:num_chapters] = number_of_chapters # Update config
      chapters = []
      begin
        puts "Generating a novel #{number_of_chapters} chapter(s) long.\n"
        puts 'Sending initial prompt, and GPT instructions...'

        prompt = "The following text is the outline for a #{@genre} novel I am about to generate. Use it as reference when processing future requests, and refer to it explicitly when generating each chapter of the book:\n\nFINAL OUTLINE:\n\n#{@outline}\n\nEND OF FINAL OUTLINE"

        if @chatgpt_client
          # Create the Assistant if it does not exist already
          assistant_id = if @chatgpt_client.assistants.list['data'].empty?
                           response = @chatgpt_client.assistants.create(
                             parameters: {
                               model: GPTK::AI::CONFIG[:openai_gpt_model],
                               name: 'AI Book generator',
                               description: 'AI Book generator',
                               instructions: @instructions
                             }
                           )
                           response['id']
                         else
                           @chatgpt_client.assistants.list['data'].last['id']
                         end

          # Create the Thread
          thread_id = @chatgpt_client.threads.create['id']

          # Send ChatGPT the book outline for future reference
          @chatgpt_client.messages.create(
            thread_id: thread_id,
            parameters: { role: 'user', content: prompt }
          )
        end

        claude_memory = {}
        if @claude_client
          # Instantiate Claude memory for chapter production conversation
          # Ensure `claude_messages` is always an Array with ONE element using cache_control type: 'ephemeral'
          initial_memory = "#{prompt}\n\nINSTRUCTIONS FOR CLAUDE:\n\n#{@instructions}END OF INSTRUCTIONS"
          claude_memory = { role: 'user', content: [{ type: 'text', text: initial_memory, cache_control: { type: 'ephemeral' } }] }
        end

        # Generate as many chapters as are specified
        parity = 0
        prev_chapter = []
        (1..number_of_chapters).each do |chapter_number| # CAREFUL WITH THIS VALUE!
          chapter = generate_chapter_zipper(parity, chapter_number, thread_id, assistant_id, fragments, prev_chapter)
          parity = parity.zero? ? 1 : 0
          prev_chapter = chapter
          @last_output = chapter # Cache results of the last operation
          chapters << chapter
        end

        @last_output = chapters # Cache results of the last operation
        chapters # Return the generated story chapters
      ensure
        @chatgpt_client.threads.delete id: thread_id # Garbage collection
        # Output some metadata - useful information about the run, API status, book content, etc.
        output_run_info start_time: start_time
        $chapters = chapters if $chapters
        $outline = @outline if $outline
        $last_output = @last_output if $last_output
        puts "Claude memory word count: #{GPTK::Text.word_count claude_memory[:content].first[:text]}" if claude_memory
      end
      puts "Congratulations! Successfully generated #{chapters.count} chapters."
      @book = chapters
      chapters
    end

    # TODO: write 'revise_book' that can take an entire book file and break it down chapter by chapter

    # Analyzes the given text for pattern matches using multiple AI agents.
    #
    # This method processes the provided text, identifies instances of a specified pattern, and returns
    # a collection of matches generated by the selected AI agents (ChatGPT, Claude, Grok, Gemini).
    # Each match includes details such as the matched content, the surrounding sentence, and its position
    # in the text.
    #
    # @param [String] text
    #   The text to analyze for pattern matches.
    #
    # @param [String | Array | Hash] pattern
    #   The pattern to search for within the text. Matches must be at least two words long.
    #
    # @param [Object] chatgpt_client
    #   The ChatGPT client object for querying AI analysis. Default: `@chatgpt_client`.
    #
    # @param [String] anthropic_api_key
    #   The API key for accessing Claude. Default: `@anthropic_api_key`.
    #
    # @param [String] xai_api_key
    #   The API key for accessing Grok. Default: `@xai_api_key`.
    #
    # @param [String] google_api_key
    #   The API key for accessing Gemini. Default: `@google_api_key`.
    #
    # @return [Hash{Symbol => Array<Hash>}]
    #   Returns a hash where each key corresponds to an AI agent (`:chatgpt`, `:claude`, `:grok`, `:gemini`), and the value is an array of matches.
    #   Each match is represented as a hash containing:
    #   - `:match` (String): The matched content.
    #   - `:sentence` (String): The full sentence surrounding the match.
    #   - `:sentence_count` (Integer): The position of the sentence in the text.
    #
    # @example Analyzing text with a specified pattern using ChatGPT
    #   text = "This is a sample text to analyze for repeated patterns."
    #   pattern = "repeated patterns"
    #   matches = analyze_text(text, pattern, chatgpt_client: chatgpt_instance)
    #
    # @example Analyzing text with multiple AI agents
    #   text = "This is another sample for analysis."
    #   pattern = "sample"
    #   matches = analyze_text(text, pattern, chatgpt_client: chatgpt_instance, xai_api_key: xai_api_key)
    #
    # @note
    #   - The method queries multiple AI agents and handles API errors with retries.
    #   - Google’s Gemini is queried first as it is the most error-prone, followed by Grok, Claude, and ChatGPT.
    #   - Matches are merged and deduplicated across all agents before being returned.
    #
    # @raise [RuntimeError]
    #   Raises an error if all AI agent queries fail or if invalid JSON is returned.
    def analyze_text(text, pattern, chatgpt_client: @chatgpt_client, anthropic_api_key: @anthropic_api_key, xai_api_key: @xai_api_key, google_api_key: @google_api_key)
      matches = { chatgpt: [], claude: [], grok: [], gemini: [] }
      # Scan for repeated content and generate an Array of results to later parse out of the book or rewrite
      repetitions_prompt = <<~STR
        Use the following prompt as instructions for analyzing the given text and coming up with matches; output matches as a JSON object. PROMPT: '#{pattern}'.\n\nONLY output the object, no other response text or conversation, and do NOT put it in a Markdown block. ONLY output valid JSON. Create the following output: an Array of objects which each include: 'match' (the recognized pattern match), 'sentence' (the surrounding sentence the pattern was found in, being THOROUGH to capture the ENTIRE surrounding sentence; do NOT summarize or rewrite it), and 'sentence_count' (the number of the sentence where the repeated content begins). ONLY include one instance of integer results in 'sentence_count'. Matches must be AT LEAST two words long.\n\nTEXT:\n\n#{text}
      STR

      # Google comes first because it is the most error-prone
      if google_api_key
        print 'Gemini is analyzing the text...'
        begin
          matches[:gemini] = JSON.parse GPTK::AI::Gemini.query(google_api_key, repetitions_prompt)
        rescue
          puts 'Error: Gemini API returned a bad response. Retrying query...'
          until matches[:gemini] && (matches[:gemini].instance_of?(Array) ? !matches[:gemini].empty? : matches[:gemini].to_i != 0)
            begin
              @bad_api_calls += 1
              if @bad_api_calls == GPTK::AI::CONFIG[:bad_api_call_limit]
                @bad_api_calls = 0
                puts "Warning. It appears repeated attempts to make AI queries using Gemini have failed."
                puts "Removing Gemini from the list of currently loaded AI agents and continuing..."
                @google_api_key = nil
                break
              end
              matches[:gemini] = JSON.parse GPTK::AI::Gemini.query(
                google_api_key, "#{repetitions_prompt}\n\nONLY output valid JSON!"
              )
            rescue
              matches[:gemini] = JSON.parse GPTK::AI::Gemini.query(
                google_api_key, "#{repetitions_prompt}\n\nONLY output valid JSON!"
              )
            end
          end
        end
        puts " #{matches[:gemini].count} matches detected!" if matches[:gemini]
      end

      # Grok is the second most error-prone AI
      if xai_api_key
        print 'Grok is analyzing the text...'
        begin
          matches[:grok] = GPTK::AI::Grok.query xai_api_key, repetitions_prompt
          matches[:grok] = JSON.parse(matches[:grok].gsub /(```json\n)|(\n```)/, '')
          puts " #{matches[:grok].count} matches detected!"
        rescue => e
          puts "Error: #{e.class}'. Retrying query..."
          matches[:grok] = GPTK::AI::Grok.query xai_api_key, repetitions_prompt
          matches[:grok] = JSON.parse(matches[:grok].gsub /(```json\n)|(\n```)/, '')
          puts " #{matches[:grok].count} matches detected!" if matches[:grok]
        end
      end

      if anthropic_api_key
        print 'Claude is analyzing the text...'
        begin
          matches[:claude] = JSON.parse GPTK::AI::Claude.query_with_memory(
            anthropic_api_key, repetitions_prompt
          )
        rescue => e
          puts "Error: #{e.class}. Retrying query..."
          sleep 10
          matches[:claude] = JSON.parse GPTK::AI::Claude.query_with_memory(
            anthropic_api_key, repetitions_prompt
          )
        end
        unless matches[:claude].instance_of? Array
          matches[:claude] = if matches[:claude].key? 'matches'
                               matches[:claude]['matches']
                             elsif matches[:claude].key? 'patterns'
                               matches[:claude]['patterns']
                             end
        end
        puts " #{matches[:claude].count} matches detected!" if matches[:claude]
      end

      if chatgpt_client
        print 'ChatGPT is analyzing the text...'
        begin # Retry the query if we get a bad JSON response
          matches[:chatgpt] = JSON.parse(GPTK::AI::ChatGPT.query(chatgpt_client, @data, repetitions_prompt))['matches']
        rescue JSON::ParserError => e
          puts "Error: #{e.class}: '#{e.message}'. Retrying query..."
          sleep 10
          matches[:chatgpt] = JSON.parse(GPTK::AI::ChatGPT.query(chatgpt_client, @data, repetitions_prompt))
          ['matches']
        end
        puts " #{matches[:chatgpt].count} matches detected!" if matches[:chatgpt]
      end

      return matches
      # Merge the results of each AI's analysis
      puts 'Merging results...'
      # Keep the original matches hash intact
      final_matches = matches[:chatgpt].uniq # Start with ChatGPT matches

      # Iterate over Claude, Grok, and Gemini matches, merging them into the final_matches array
      [matches[:claude], matches[:grok], matches[:gemini]].each do |match_list|
        next unless match_list.is_a? Array # Ensure match_list is an array
        final_matches.concat match_list.uniq # Add unique elements to final_matches
      end

      final_matches.uniq! # Ensure all matches are unique in the final array

      # Remove any duplicate matches from the merged results
      puts 'Deleting any duplicate matches found...'
      final_matches.delete_if do |d|
        final_matches.any? do |i|
          i != d && (d['match'] == i['match'] && d['sentence_count'] == i['sentence_count'])
        end
      end
      final_matches.uniq!

      # Symbolify the keys
      final_matches.map! { |p| Utils.symbolify_keys p }

      # Remove duplicate matches for the same sentence (we don't need to rewrite the same sentence multiple times)
      # final_matches.delete_if do |d|
      #   final_matches.any? do |i|
      #     i != d && (d[:sentence_count] == i[:sentence_count])
      #   end
      # end

      # Sort the matches by the order of when they appear in the chapter
      final_matches.sort_by! { |d| d[:sentence_count] }

      # Print out results of the text analysis
      puts "#{final_matches.count} total pattern matches found:"
      final_matches.each do |i|
        puts "- [#{i[:sentence_count]}]: #{i[:match]}"
      end

      final_matches
    end

    # Revises the content of a chapter based on specified filters or patterns.
    #
    # This method applies a series of revision operations to a given chapter, using a specified
    # agent (e.g., ChatGPT, Claude, Grok, Gemini) or dynamically determining one if none is provided.
    # It allows users to iteratively select filters for content revision and returns the revised
    # text along with a summary of the applied revisions.
    #
    # @param [String, Array<String>] chapter
    #   The chapter to revise. Can be a String or an Array of fragments.
    #
    # @param [Integer, nil] op
    #   The operation to apply during the revision process. If `nil`, the user is prompted
    #   to select operations interactively. Default: `nil`.
    #
    # @param [String, nil] agent
    #   The agent to use for revision. Options include `'ChatGPT'`, `'Claude'`, `'Grok'`,
    #   and `'Gemini'`. If `nil`, the method selects an agent based on available API keys.
    #   Default: `nil`.
    #
    # @param [Object] chatgpt_client
    #   The ChatGPT client object for processing revisions. Defaults to the instance variable
    #   `@chatgpt_client`.
    #
    # @param [String] anthropic_api_key
    #   The API key for accessing Claude. Defaults to the instance variable
    #   `@anthropic_api_key`.
    #
    # @param [String] xai_api_key
    #   The API key for accessing Grok. Defaults to the instance variable
    #   `@xai_api_key`.
    #
    # @param [String] google_api_key
    #   The API key for accessing Gemini. Defaults to the instance variable
    #   `@google_api_key`.
    #
    # @return [Array<String, Array>]
    #   Returns an Array containing:
    #   - The revised chapter text (`String`).
    #   - A summary of the applied revisions (`Array`).
    #
    # @example Revising a chapter with ChatGPT and a specific operation
    #   revised_text, revisions = revise_chapter("Some content to revise", op: 1, agent: 'ChatGPT')
    #
    # @example Revising interactively
    #   revised_text, revisions = revise_chapter(["Fragment 1", "Fragment 2"])
    #
    # @note
    #   - This method supports dynamic selection of revision filters based on bad patterns
    #     and user-defined trainers.
    #   - If `op` is specified, the method will apply the corresponding operation directly.
    #   - The interactive mode lists available operations and lets users select filters one at a time.
    #   - To revert revisions, additional functionality should be implemented as noted in the TODO.
    #
    # @todo Add functionality to revert revisions by operation.
    def revise_chapter(chapter, op: nil, agent: nil, chatgpt_client: @chatgpt_client, anthropic_api_key: @anthropic_api_key, xai_api_key: @xai_api_key, google_api_key: @google_api_key)
      # TODO: add method to revert revisions (BY OPERATION)
      chapter_text = chapter.instance_of?(String) ? chapter : chapter.join # Array of fragments
      revised_chapter_text = ''
      arguments = [chapter_text]
      revisions = []
      start_time = Time.now
      agent ||= if chatgpt_client
                  'ChatGPT'
                elsif anthropic_api_key
                  'Claude'
                elsif xai_api_key
                  'Grok'
                elsif google_api_key
                  'Gemini'
                end
      kw_args = { agent: agent, chatgpt_client: chatgpt_client, anthropic_api_key: anthropic_api_key, xai_api_key: xai_api_key, google_api_key: google_api_key }

      # Compile list of filters
      num_filters_applied = 0
      operations = { 'Remove instances of repeated content': ['Repeated or duplicated content'] }

      # Parse bad patterns into operations
      operations.update CONFIG[:bad_patterns]

      # Parse the filters in the trainers file into operations
      trainers = GPTK::Text.parse_numbered_categories @training
      operations.update trainers

      # Loop until the user is finished with revision process
      response = 1 # CANNOT BE ZERO
      iterations_with_op = 0
      until response.zero?
        if op
          response = op
          iterations_with_op = 1
        else
          puts "#{operations.count} operations available for text revision. Select one. Input 0 when you are done!"
          operations.each_with_index do |(filter_name, op_patterns), i|
            if op_patterns.instance_of?(String) || op_patterns.count == 1
              puts "#{i + 1}) '#{filter_name}'"
            else # Array of patterns
              puts "#{i + 1}) '#{filter_name}' (#{op_patterns.count} patterns)"
            end
          end
          response = gets.to_i
        end

        pattern = if response.zero?
                    puts "Successfully applied #{num_filters_applied} operations!"
                    puts "\nElapsed time: #{GPTK.elapsed_time start_time} minutes"
                    puts 'Exiting...'
                    return [revised_chapter_text, revisions]
                  elsif response == 1 # Repeated content
                    'Repeated or duplicated content'
                  elsif response > 1 && response <= (CONFIG[:bad_patterns].count + 1) # Bad patterns
                    operations.to_a[response - 1].last
                  else # Trainer
                    operations.to_a[response - 1].last
                  end
        arguments << "OPR ##{op}: '#{pattern}'"

        if iterations_with_op.zero?
          kw_args.update ops: [1, 2]
          revised_chapter_text, revisions = revise_chapter_content(
            arguments[0].join, arguments[1], **kw_args
          )
        else
          kw_args.update ops: [1, 2]
          revised_chapter_text, revisions = revise_chapter_content(
            arguments[0].join, arguments[1], **kw_args
          )
          puts 'Exiting...'
          break
        end

        num_filters_applied += 1
        puts "Revised chapter text:\n\n#{revised_chapter_text}"
      end

      [revised_chapter_text, revisions]
    end

    # Revises the content of a chapter based on a specified pattern and operation.
    #
    # This method processes the chapter text, identifies matches for a given pattern, and applies
    # user-specified or automatic operations to revise the content. It supports multiple agents
    # (ChatGPT, Claude, Grok, Gemini) for AI-driven revisions and allows both batch and
    # interactive modes for applying operations.
    #
    # @param [String] chapter_text
    #   The text of the chapter to revise.
    #
    # @param [String, Array, Hash] pattern
    #   The pattern(s) to search for in the chapter. Can be:
    #   - A `String` for a single pattern.
    #   - An `Array` of patterns for batch processing.
    #   - A `Hash` for advanced operations (e.g., mad-libs).
    #
    # @param [Array, nil] ops
    #   An optional array specifying operation mode and actions
    #   Default: `nil` (prompts user for input).
    #
    # @param [String, nil] agent
    #   The agent to use for AI-driven revisions. Options include `'ChatGPT'`, `'Claude'`,
    #   `'Grok'`, and `'Gemini'`. Default: the instance variable `@agent`.
    #
    # @param [Object] chatgpt_client
    #   The ChatGPT client object for processing revisions. Default: `@chatgpt_client`.
    #
    # @param [String] anthropic_api_key
    #   The API key for accessing Claude. Default: `@anthropic_api_key`.
    #
    # @param [String] xai_api_key
    #   The API key for accessing Grok. Default: `@xai_api_key`.
    #
    # @param [String] google_api_key
    #   The API key for accessing Gemini. Default: `@google_api_key`.
    #
    # @return [Array<String, Array<Hash>>]
    #   Returns an array containing:
    #   - The revised chapter text (`String`).
    #   - A summary of applied revisions (`Array<Hash>`), where each hash includes:
    #     - `:pattern`: The pattern used for the revision.
    #     - `:match`: The specific matched text.
    #     - `:sentence_count`: The sentence number in the chapter.
    #     - `:original`: The original sentence.
    #     - `:revised`: The revised sentence (or `'DELETED'` for deleted content).
    #
    # @example Revising chapter text with a single pattern in batch mode
    #   chapter_text = "This is the text to revise. There are repeated issues here."
    #   pattern = "repeated issues"
    #   revised_text, revisions = revise_chapter_content(chapter_text, pattern, ops: [1, 2], agent: 'ChatGPT')
    #
    # @example Revising interactively with user input
    #   chapter_text = "This is another example. Let's revise it interactively."
    #   pattern = "revise it"
    #   revised_text, revisions = revise_chapter_content(chapter_text, pattern)
    #
    # @note
    #   - This method integrates AI agents for content revisions based on specified patterns.
    #   - It supports multiple modes:
    #     - Batch mode applies an operation to all pattern matches simultaneously.
    #     - Interactive mode allows the user to handle each match individually.
    #   - For patterns provided as `Array` or `Hash`, additional logic processes multiple revisions in sequence.
    #
    # @raise [RuntimeError]
    #   Raises an error if no AI agent is detected or if invalid operation options are provided.
    #
    # @todo Add support for mad-libs style operations when pattern is a `Hash`.
    # TODO: tweak to be called directly, without data parsing issues
    def revise_chapter_content(chapter_text, pattern, ops: nil, agent: @agent, chatgpt_client: @chatgpt_client, anthropic_api_key: @anthropic_api_key, xai_api_key: @xai_api_key, google_api_key: @google_api_key)
      kw_args = { agent: agent, chatgpt_client: chatgpt_client, anthropic_api_key: anthropic_api_key, xai_api_key: xai_api_key, google_api_key: google_api_key }
      start_time = Time.now
      revisions = []
      revised_chapter_text = chapter_text
      numbered_chapter_text = GPTK::Text.number_text revised_chapter_text

      begin
        # Scan the chapter for instances of given pattern and offer the user choice in how to address matches
        case pattern
        when String # Level 1 operation
          kw_args.delete :agent
          matches = analyze_text numbered_chapter_text, pattern, **kw_args

          unless ops
            # Prompt user for the mode
            puts 'How would you like to proceed with the revision process for the pattern matches?'
            puts 'Enter an option number: 1, or 2'
            puts 'Mode 1: Apply an operation to ALL matches at once.'
            puts 'Mode 2: Iterate through each match and choose an operation to apply to it.'
          end
          mode = ops ? ops[0] : gets.to_i

          case mode
          when 1 # Apply operation to ALL matches
            unless ops
              puts "Which operation do you wish to apply to all #{matches.count}? 1) Keep as is, 2) Change, 3) Delete"
            end
            operation = ops ? ops[1] : gets.to_i

            case operation
            when 1 then puts 'Content accepted as-is.'
            when 2 # Have the first detected AI revise each pattern match
              matches.each do |match|
                prompt = <<~STR
                  Rewrite the following sentence: SENTENCE: '#{match[:sentence]}', specifically the pattern: '#{match[:match]}'. ONLY output the revised sentence, no other commentary or discussion. Revise the entire portion of the pattern.
                STR

                # Revise the chapter text based on AI feedback
                puts "Revising sentence #{match[:sentence_count]} using #{agent}..."
                puts "Original: #{match[:sentence]}"
                revised_sentence = case agent
                                   when 'ChatGPT'
                                     GPTK::AI::ChatGPT.query chatgpt_client, @data, prompt
                                   when 'Claude'
                                     GPTK::AI::Claude.query_with_memory anthropic_api_key, prompt
                                   when 'Grok'
                                     GPTK::AI::Grok.query xai_api_key, prompt
                                   when 'Gemini'
                                     GPTK::AI::Gemini.query google_api_key, prompt
                                   else raise 'Error: No AI agent detected!'
                                   end

                puts "Revision: #{revised_sentence}"
                sleep 1
                revised_chapter_text.gsub! match[:sentence], revised_sentence
                revisions << {
                  pattern: pattern,
                  match: match[:match],
                  sentence_count: match[:sentence_count],
                  original: match[:sentence],
                  revised: revised_sentence
                }
              end

              puts "Successfully enacted #{matches.count} revisions!"
            when 3 # Delete all examples of sentences where a pattern match was found
              matches.each do |match|
                puts 'Revising chapter...'
                puts "Sentence [#{match[:sentence_count]}] deleted: #{match[:sentence]}"
                sleep 1
                revised_chapter_text.gsub! match[:sentence], ''
                revisions << {
                  pattern: pattern,
                  match: match[:match],
                  sentence_count: match[:sentence_count],
                  original: match[:sentence],
                  revised: '[DELETED]'
                }
              end
            else raise 'Invalid operation. Must be 1, 2, or 3'
            end
          when 2 # Iterate through pattern matches and prompt the user for action on each one
            matches.each do |match|
              puts "\nSentence number: #{match[:sentence_count]}"
              puts "Pattern match: #{match[:match]}"
              puts "Sentence: #{match[:sentence]}"
              puts "Which operation do you wish to apply to the pattern match?"
              puts '1) Keep as is, 2) Change, or 3) Delete'
              operation = gets.to_i

              case operation
              when 1
                puts "Ignoring match: '#{match[:match]}'..."
              when 2
                puts "Would you like to 1) have #{agent} perform a rewrite of the content using its own judgement,"
                puts "or 2) would you like to provide a general prompt #{agent} will use to revise it?"
                choice = gets.to_i
                case choice
                when 1 # Have the AI auto-revise content
                  prompt = <<~STR
                    Rewrite the following sentence: SENTENCE: '#{match[:sentence]}'. ONLY output the revised sentence, no other commentary or discussion.
                  STR
                  puts "Revising sentence #{match[:sentence_count]}..."
                  revised_sentence = case agent
                                     when 'ChatGPT'
                                       GPTK::AI::ChatGPT.query chatgpt_client, @data, prompt
                                     when 'Claude'
                                       GPTK::AI::Claude.query_with_memory anthropic_api_key, prompt
                                     when 'Grok'
                                       GPTK::AI::Grok.query xai_api_key, prompt
                                     when 'Gemini'
                                       GPTK::AI::Gemini.query google_api_key, prompt
                                     else raise 'Error: No AI agent detected!'
                                     end
                  puts "#{agent} revision: '#{revised_sentence}'"
                  revised_chapter_text.gsub! match[:sentence], revised_sentence
                  puts "Successfully revised the repeated content using #{agent}!"
                  revisions << {
                    pattern: pattern,
                    match: match[:match],
                    sentence_count: match[:sentence_count],
                    original: match[:sentence],
                    revised: revised_sentence
                  }
                when 2 # Prompt user to specify prompt for the AI to use when rewriting the content
                  puts "Please enter a prompt to instruct #{agent} regarding the revision of the pattern match."
                  user_prompt = gets
                  prompt = <<~STR
                    Rewrite the following sentence: SENTENCE: '#{match[:sentence]}'. ONLY output the revised sentence, no other commentary or discussion. #{user_prompt}
                  STR
                  puts "Revising sentence #{match[:sentence_count]}..."
                  revised_sentence = case agent
                                     when 'ChatGPT'
                                       GPTK::AI::ChatGPT.query chatgpt_client, @data, prompt
                                     when 'Claude'
                                       GPTK::AI::Claude.query_with_memory anthropic_api_key, prompt
                                     when 'Grok'
                                       GPTK::AI::Grok.query xai_api_key, prompt
                                     when 'Gemini'
                                       GPTK::AI::Gemini.query google_api_key, prompt
                                     else raise 'Error: No AI agent detected!'
                                     end
                  puts "#{agent} revision: '#{revised_sentence}'"
                  revised_chapter_text.gsub! match[:sentence], revised_sentence
                  puts "Successfully revised the the match using your prompt and #{agent}!"
                  revisions << {
                    pattern: pattern,
                    match: match[:match],
                    sentence_count: match[:sentence_count],
                    original: match[:sentence],
                    revised: revised_sentence
                  }
                else raise 'Invalid option. Must be 1 or 2'
                end
              when 3 # Delete all instances of the bad pattern
                puts "Deleting sentence #{match[:sentence_count]}..."
                revised_chapter_text.gsub! match[:sentence], ''
                puts "Deleted: '#{match[:sentence]}'"
                revisions << {
                  pattern: pattern,
                  match: match[:match],
                  sentence_count: match[:sentence_count],
                  original: match[:sentence],
                  revised: 'DELETED'
                }
              else raise 'Invalid operation. Must be 1, 2, or 3'
              end
            end
          else raise 'Invalid mode. Must be 1, or 2'
          end
        when Array # Level 2 operation
          kw_args.update ops: [1, 2]
          revisions = pattern.collect { |p| revise_chapter_content(chapter_text, p, **kw_args).last }
          return [revised_chapter_text, revisions]
        when Hash # Level 2 operation (mad-libs)

        else raise 'Error: invalid pattern object type.'
        end
      rescue => e
        puts "Error: #{e.class}: '#{e.message}'. Retrying query..."
        sleep 10
        kw_args.update ops: [1, 2]
        revised_chapter_text, revisions = revise_chapter_content chapter_text, pattern, **kw_args
        ap revisions
      ensure puts "\nElapsed time: #{GPTK.elapsed_time start_time} minutes"
      end

      [revised_chapter_text, revisions]
    end
  end
end
