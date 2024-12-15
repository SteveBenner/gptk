module GPTK
  # Book interface - responsible for managing and creating content in the form of a book with one or more chapters
  # TODO: add a feature which tracks how many repeated queries are run, and after a time will prompt users to REMOVE
  # a troublesome AI agent entirely from the Book object, so it won't be used, and assign a different agent its role
  class Book
    $chapters, $outline, $last_output = [], '', nil
    attr_reader :chapters, :chatgpt_client, :claude_client, :last_output, :agent
    attr_accessor :parsers, :output_file, :genre, :instructions, :outline, :training

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
                   parsers: CONFIG[:parsers],
                   mode: GPTK.mode)
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
      @mode = mode.to_i
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

    # Construct the prompt passed to the AI agent
    def build_prompt(prompt, fragment_number)
      generation_prompt = (fragment_number == 1) ? CONFIG[:initial_prompt] : CONFIG[:continue_prompt]
      [generation_prompt, prompt].join ' '
    end

    # Parse an AI model response text into the chapter content and chapter summary, as well as applying more parsers
    # Note: due to the tendency of current AI models to produce hallucinations in output, significant
    # reformatting of the output is sometimes required to ensure consistency
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

    # Output useful information (metadata) after a run, (or part of a run) to STDOUT by default, or a file if given
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

    # Generate one complete chapter of the book using the given prompt, and one AI (auto detects)
    # TODO: plug in training data
    def generate_chapter(general_prompt, thread_id: nil, assistant_id: nil, fragments: CONFIG[:chapter_fragments])
      raise "Error: 'fragments' is nil!" unless fragments
      messages = [] if @chatgpt_client
      chapter = []

      # Initialize claude memory every time we run a chapter generation operation
      if @claude_client
        # Ensure `claude_memory` is always an Array with ONE element using cache_control type: 'ephemeral'
        claude_memory = { role: 'user', content: [{ type: 'text', text: "FINAL OUTLINE:\n\n#{@outline}\n\nEND OF FINAL OUTLINE", cache_control: { type: 'ephemeral' } }] }
      end

      # Initialize manual memory for Grok via the input prompt
      if @xai_api_key
        general_prompt = "FINAL OUTLINE:\n\n#{@outline}\n\nEND OF FINAL OUTLINE\n\n#{general_prompt}"
      end

      # Manage Gemini memory
      if @google_api_key
        data = "OUTLINE:\n\n#{@outline}\n\nEND OF OUTLINE\n\nTRAINING DATA:\n\n#{@training}\n\nEND OF TRAINING DATA"
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

      if @google_api_key
        # Remove old cache
        HTTParty.post(
          "https://generativelanguage.googleapis.com/v1beta/#{cache_name}?key=#{@google_api_key}"
        )
      end

      @data[:word_counts] << GPTK::Text.word_count(chapter.join "\n")
      @chapters << chapter
      chapter
    end

    # Generate one complete chapter of the book using the back-and-forth 'zipper' technique
    # TODO: plug in training data
    def generate_chapter_zipper(parity, chapter_num, thread_id, assistant_id, fragments = GPTK::Book::CONFIG[:chapter_fragments], prev_chapter = [], anthropic_api_key: @anthropic_api_key)
      # Initialize claude memory every time we run a chapter generation operation
      # Ensure `claude_memory` is always an Array with ONE element using cache_control type: 'ephemeral'
      claude_memory = { role: 'user', content: [{ type: 'text', text: "FINAL OUTLINE:\n\n#{@outline}\n\nEND OF FINAL OUTLINE", cache_control: { type: 'ephemeral' } }] }

      unless prev_chapter.empty? # Add any previously generated chapter to the memory of the proper AI
        if parity.zero? # ChatGPT
          CHATGPT.messages.create thread_id: thread_id, parameters: { role: 'user', content: "PREVIOUS CHAPTER:\n\n#{prev_chapter.join("\n\n")}" }
        else # Claude
          claude_memory[:content].first[:text] << "\n\nPREVIOUS CHAPTER:\n\n#{prev_chapter.join("\n\n")}"
        end
      end

      # Generate the chapter fragment by fragment
      meta_prompt = GPTK::Book::CONFIG[:meta_prompt]
      chapter = []
      (1..fragments).each do |j|
        # Come up with an initial version of the chapter, based on the outline and prior chapter
        chapter_gen_prompt = case j
                             when 1 then "Referencing the final outline, write the first part of chapter #{chapter_num} of the #{@genre} story. #{meta_prompt}"
                             when fragments then "Referencing the final outline and the current chapter fragments, write the final conclusion of chapter #{chapter_num} of the #{@genre} story. #{meta_prompt}"
                             else "Referencing the final outline and the current chapter fragments, continue writing chapter #{chapter_num} of the #{@genre} story. #{meta_prompt}"
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

    # Generate one or more chapters of the book, using a single AI (auto detects)
    def generate(number_of_chapters = CONFIG[:num_chapters], fragments = CONFIG[:chapter_fragments])
      start_time = Time.now
      CONFIG[:num_chapters] = number_of_chapters
      book = []
      begin
        # Run in mode 1 (Automation), 2 (Interactive), or 3 (Batch)
        case @mode
        when 1
          puts "Automation mode enabled: Generating a novel #{number_of_chapters} chapter(s) long." +
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

          # TODO: complete this
          if agent == 'Claude'
            claude_memory = []
          end

          # TODO: add Grok
          # TODO: add Gemini

          # Generate as many chapters as are specified
          (1..number_of_chapters).each do |i|
            puts "Generating chapter #{i}..."
            prompt = "Generate a fragment of chapter #{i} of the book, referring to the outline already supplied. Utilize as much output length as possible when returning content. Output ONLY raw text, no JSON or HTML."
            book << generate_chapter(prompt, thread_id: thread_id, assistant_id: assistant_id, fragments: fragments)
          end

          # Cache result of last operation
          @last_output = book

          book
        when 2 # TODO
        when 3 # TODO
        else puts 'Please input a valid script run mode.'
        end
      ensure
        # Output some metadata - useful information about the run, API status, book content, etc.
        output_run_info start_time: start_time
        $chapters = book if $chapters
        $outline = @outline if $outline
        $last_output = @last_output if $last_output
        @chatgpt_client.threads.delete id: thread_id if @agent == 'ChatGPT' # Garbage collection
        if @agent == 'Claude'
          puts "Claude memory word count: #{GPTK::Text.word_count claude_memory[:content].first[:text]}"
        end
      end
    end

    # Generate one or more chapters of the book using the back-and-forth 'zipper' technique
    def generate_zipper(number_of_chapters = CONFIG[:num_chapters], fragments = 1)
      start_time = Time.now
      CONFIG[:num_chapters] = number_of_chapters # Update config
      chapters = []
      begin
        puts "Automation mode enabled: Generating a novel #{number_of_chapters} chapter(s) long.\n"
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

    # Scan the chapter for instances of a given pattern
    def analyze_text(text, pattern, chatgpt_client: @chatgpt_client, anthropic_api_key: @anthropic_api_key, xai_api_key: @xai_api_key, google_api_key: @google_api_key)
      matches = { chatgpt: [], claude: [], grok: [], gemini: [] }
      # Scan for repeated content and generate an Array of results to later parse out of the book or rewrite
      repetitions_prompt = <<~STR
        Use the following prompt as a pattern or instructions for analyzing the given text and coming up with matches; output matches as a JSON object. PROMPT: '#{pattern}'.\n\nONLY output the object, no other response text or conversation, and do NOT put it in a Markdown block. ONLY output valid JSON. Create the following output: an Array of objects which each include: 'match' (the recognized repeated content), 'sentence' (the surrounding sentence the pattern was found in), and 'sentence_count' (the number of the sentence where the repeated content begins). ONLY include one instance of integer results in 'sentence_count'. Matches must be AT LEAST two words long.\n\nTEXT:\n\n#{text}
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
          puts " #{matches[:grok].count} matches detected!"
        end
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
        puts " #{matches[:chatgpt].count} matches detected!"
      end

      if anthropic_api_key
        print 'Claude is analyzing the text...'
        begin
          matches[:claude] = JSON.parse GPTK::AI::Claude.query_with_memory(
            anthropic_api_key, [{ role: 'user', content: repetitions_prompt }]
          )
        rescue => e
          puts "Error: #{e.class}. Retrying query..."
          sleep 10
          matches[:claude] = JSON.parse GPTK::AI::Claude.query_with_memory(
            anthropic_api_key, [{ role: 'user', content: repetitions_prompt }]
          )
        end
        unless matches[:claude].instance_of? Array
          matches[:claude] = if matches[:claude].key? 'matches'
                               matches[:claude]['matches']
                             elsif matches[:claude].key? 'patterns'
                               matches[:claude]['patterns']
                             end
        end
        puts " #{matches[:claude].count} matches detected!"
      end
      ap matches

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
      final_matches.delete_if do |d|
        final_matches.any? do |i|
          i != d && (d[:sentence_count] == i[:sentence_count])
        end
      end

      # Sort the matches by the order of when they appear in the chapter
      final_matches.sort_by! { |d| d[:sentence_count] }

      # Print out results of the text analysis
      puts "#{final_matches.count} total pattern matches found:"
      final_matches.each do |i|
        puts "- [#{i[:sentence_count]}]: #{i[:match]}"
      end

      final_matches
    end

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
          revised_chapter_text, revisions = revise_chapter_content(arguments[0], arguments[1], **kw_args)
        else
          kw_args.update ops: [1, 2]
          revised_chapter_text, revisions = revise_chapter_content(arguments[0], arguments[1], **kw_args)
          puts 'Exiting...'
          break
        end

        num_filters_applied += 1
        puts "Revised chapter text:\n\n#{revised_chapter_text}"
      end

      [revised_chapter_text, revisions]
    end

    # TODO: consider making this private
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
                                     GPTK::AI::Claude.query_with_memory anthropic_api_key,
                                                                        [{ role: 'user', content: prompt }]
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
                                       GPTK::AI::Claude.query_with_memory anthropic_api_key,
                                                                          [{ role: 'user', content: prompt }]
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
                                       GPTK::AI::Claude.query_with_memory anthropic_api_key,
                                                                          [{ role: 'user', content: prompt }]
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

      ap revisions
      [revised_chapter_text, revisions]
    end
  end
end
