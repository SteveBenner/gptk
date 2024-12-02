module GPTK
  class Book
    $chapters, $outline, $last_output = [], '', nil
    attr_reader :chapters, :chatgpt_client, :claude_client, :last_output
    attr_accessor :parsers, :output_file, :genre, :instructions, :outline

    def initialize(outline,
                   openai_client: '',
                   anthropic_client: '',
                   instructions: '',
                   output_file: '',
                   rec_prompt: '',
                   genre: '',
                   parsers: CONFIG[:parsers],
                   mode: GPTK.mode)
      unless openai_client || anthropic_client
        puts 'Error: You must pass in at least ONE AI agent client object to the `new` method.'
        return
      end
      @chatgpt_client = openai_client
      @claude_client = anthropic_client
      # Reference document for book generation
      outline = ::File.exist?(outline) ? ::File.read(outline) : outline
      @outline = outline.encode 'UTF-8', invalid: :replace, undef: :replace, replace: '?'
      # Instructions for the AI agent
      instructions = ::File.exist?(instructions) ? ::File.read(instructions) : instructions
      @instructions = instructions.encode 'UTF-8', invalid: :replace, undef: :replace, replace: '?'
      @output_file = ::File.expand_path output_file
      @genre = genre
      @parsers = parsers
      @mode = mode
      @rec_prompt = ::File.exist?(rec_prompt) ? ::File.read(rec_prompt) : rec_prompt
      @chapters = [] # Book content
      @data = { # Data points to track while generating a book chapter by chapter
        prompt_tokens: 0,
        completion_tokens: 0,
        cached_tokens: 0,
        word_counts: [],
        current_chapter: 1
      }
    end
    # todo: update non-zipper code to use single client

    # Construct the prompt passed to the AI agent
    def build_prompt(prompt, fragment_number)
      # meta_prompt = "Current chapter: #{chapter_number}.\n"
      generation_prompt = (fragment_number == 1) ? CONFIG[:initial_prompt] : CONFIG[:continue_prompt]
      [generation_prompt, prompt].join ' '
    end

    # Revise the chapter based upon a set of specific guidelines, using ChatGPT
    def revise_chapter(chapter, recommendations_prompt)
      puts "Revising chapter..."
      revision_prompt = "Please revise the following chapter content:\n\n" + chapter + "\n\nREVISIONS:\n" +
        recommendations_prompt + "\nDo NOT change the chapter title or number--this must remain the same as the original, and must accurately reflect the outline."
      GPTK::AI.query @chatgpt_client, revision_prompt, @data
    end

    # Parse an AI model response text into the chapter content and chapter summary
    # Note: due to the tendency of current AI models to produce hallucinations in output, significant
    # reformatting of the output is required to ensure consistency
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
    def output_run_info(file=nil)
      io_stream = case file.class
                    when File then file
                    when IO then ::File.open(file, 'a+')
                    when String then ::File.open(file, 'a+')
                    else STDOUT
                  end
      puts io_stream.class
      io_stream.seek 0, IO::SEEK_END
      io_stream.puts "\nSuccessfully generated #{CONFIG[:num_chapters]} chapters, for a total of #{@data[:word_counts].reduce &:+} words.\n"
      io_stream.puts <<~STRING

        Total token usage:

        - Prompt tokens used: #{@data[:prompt_tokens]}
        - Completion tokens used: #{@data[:completion_tokens]}
        - Total tokens used: #{@data[:prompt_tokens] + @data[:completion_tokens]}
        - Cached tokens used: #{@data[:cached_tokens]}
        - Cached token percentage: #{((@data[:cached_tokens].to_f / @data[:prompt_tokens]) * 100).round 2}%
      STRING
      io_stream.puts "\nElapsed time: #{((Time.now - @@start_time) / 60).round 1} minutes." # Print script run duration
      io_stream.puts "Words by chapter:\n"
      @data[:word_counts].each_with_index { |chapter_words, i| io_stream.puts "\nChapter #{i + 1}: #{chapter_words} words" }
    end

    # Write completed chapters to the output file
    # todo: add metadata to filename, such as date
    def save
      if @chapters.empty? || @chapters.nil?
        puts 'Error: no content to write.'
        return
      end
      output_file = ::File.open @output_file, 'w+'
      @chapters.each_with_index do |chapter, i|
        puts "Writing chapter #{i + 1} to file..."
        output_file.puts "#{chapter}\n"
      end
      puts "Successfully wrote #{@chapters.count} chapters to file: #{::File.path output_file}"
    end

    # Generate one complete chapter of the book using the given prompt
    def generate_chapter(general_prompt, thread, assistant_id = nil, fragments = GPTK::Book::CONFIG[:chapter_fragments], recommendations_prompt = nil)
      messages = []

      (1..fragments).each do |i|
        prompt = build_prompt general_prompt, i
        @clients.first.messages.create(
          thread_id: thread,
          parameters: { role: 'user', content: prompt }
        )

        # Create the run
        response = @clients.first.runs.create(
          thread_id: thread,
          parameters: { assistant_id: assistant_id }
        )
        run_id = response['id']

        # Loop while awaiting status of the run
        while true do
          response = @clients.first.runs.retrieve id: run_id, thread_id: thread
          status = response['status']

          case status
          when 'queued', 'in_progress', 'cancelling'
            puts 'Processing...'
            sleep 1 # Wait one second and poll again
          when 'completed'
            messages = @clients.first.messages.list thread_id: thread, parameters: { order: 'asc' }
            break # Exit loop and report result to user
          when 'requires_action'
            # Handle tool calls (see below)
          when 'cancelled', 'failed', 'expired'
            puts response['last_error'].inspect
            break
          else
            puts "Unknown status response: #{status}"
          end
        end

        puts messages['data'].last['content'].first['text']['value']
      end

      messages
    end

    # Generate one complete chapter of the book using the zipper technique
    def generate_chapter_zipper(parity, chapter_num, thread_id, assistant_id, fragments = GPTK::Book::CONFIG[:chapter_fragments], prev_chapter = [], anthropic_api_key: nil)
      # Initialize claude memory every time we run a chapter generation operation
      # Ensure `claude_memory` is always an Array with ONE element using cache_control type: 'ephemeral'
      claude_memory = { role: 'user', content: [{ type: 'text', text: "FINAL OUTLINE:\n\n#{@outline}\n\nEND OF FINAL OUTLINE", cache_control: { type: 'ephemeral' } }] }

      unless prev_chapter.empty? # Add any previously generated chapter to the memory of the proper AI
        if parity == 0 # ChatGPT
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
        chapter << if parity == 0 # ChatGPT
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
      chapter # Array of Strings representing chapter fragments for one chapter
    end

    # Revise content using one or more AI agents (NOTE: you MUST pass in the Anthropic API key if using Claude)
    # todo: apply user-generated revisions
    #   - pattern by pattern, interact with human!
    #   - options: change, eliminate, and/or ignore for EACH OCCURRENCE
    #   - batch mode: offer an option to batch one of the choices for EACH PATTERN
    def revise_chapter1(chapter, chatgpt_client: @chatgpt_client, claude_client: @claude_client, anthropic_api_key: nil)
      @@start_time = Time.now
      revised_chapter, claude_memory = [], {}
      chapter_text = chapter.join ' '

      # Scan for bad patterns and generate an Array of results to later parse out of the book content
      bad_pattern_prompt = "Scan the following chapter for bad patterns, defined here: (#{CONFIG[:bad_phrases].join('; ')}) and return the results as a Ruby object. ONLY output the object, no other response text or conversation, and do not put it in a Markdown Ruby block. ONLY output JSON. Create the following output: an Array of objects which each include: 'match' (the recognized pattern), 'sentence' (the surrounding sentence the pattern was found in) and 'word' (a count of how many words from the beginning of the chapter the pattern occurred at).\n\nCHAPTER:\n\n#{chapter}"
      chatgpt_matches = JSON.parse(GPTK::AI::ChatGPT.query @chatgpt_client, @data, bad_pattern_prompt)[:matches]
      ap chatgpt_matches
      claude_matches = JSON.parse GPTK::AI::Claude.query_with_memory anthropic_api_key, [{ role: 'user', content: bad_pattern_prompt }]
      ap claude_matches

      # Remove any duplicate matches from Claude's results
      claude_matches.delete_if do |match|
        chatgpt_matches.include? {|i| i['match'] == match['match'] && i['word'] == match['word']}
      end

      bad_patterns = chatgpt_matches.concat claude_matches



      # todo: parse chatgpt results into grouped matches
      # todo: parse claude results into grouped matches
      # todo: interaction 1: batch mode prompt
      # todo: interaction loop

      return

      instructions_prompt = "Revise the following chapter fragment based upon these rules: 1) Scan your memory and check the current fragment for presence of the following phrases or words, and rewrite the fragment ONLY allowing ONE total usage of any of the given phrases or words in the list for the current chapter, amongst all the chapter fragments, AND expand your analysis to include a 'proximal word cloud' for each bad pattern. Here is the list: #{CONFIG[:bad_phrases].join('; ')}. END OF LIST. Refrain from adding conversation to the user in the output; keep it content only."

      begin
        puts 'Revising chapter...'

        if chatgpt_client
          # Grab the latest Assistant
          assistant_id = @chatgpt_client.assistants.list['data'].last['id']
          # Create a new Thread
          thread_id = chatgpt_client.threads.create['id']
          # ChatGPT setup
          chatgpt_client.messages.create thread_id: thread_id, parameters: { role: 'user', content: chapter_text }
        end

        if claude_client
          # Claude setup
          claude_memory = { role: 'user', content: [{ type: 'text', text: instructions_prompt, cache_control: { type: 'ephemeral' } }] }
        end

        # Loop over each chapter fragment, revising each one and returning the results as an array of chapter fragments
        chapter.each_with_index do |fragment, i|
          chatgpt_prompt = "#{instructions_prompt}\n\nFRAGMENT:\n\n#{fragment}"
          revised_fragment = if chatgpt_client # If ChatGPT agent is given OR if additional agents are given as well
                               GPTK::AI::ChatGPT.run_assistant_thread @chatgpt_client, thread_id, assistant_id, chatgpt_prompt
                             else # Claude
                               claude_memory[:content].first[:text] << "\n\nFRAGMENT:\n\n#{fragment}"
                               claude_revision = GPTK::AI::Claude.query @claude_client, prompt: claude_memory[:content].first[:text]
                               claude_memory[:content].first[:text] << "\n\nFRAGMENT #{i + 1}:\n\n#{claude_revision}"
                               chatgpt_client.messages.create thread_id: thread_id, parameters: { role: 'user', content: "\n\nFRAGMENT #{i + 1}:\n\n#{claude_revision}"}
                               claude_revision
                             end
          if chatgpt_client && claude_client # If using Claude with ChatGPT, have it respond to ChatGPT's analysis
            claude_memory[:content].first[:text] << "\n\nFRAGMENT:\n\n#{revised_fragment}"
            revised_fragment = GPTK::AI::Claude.query_with_memory anthropic_api_key, [claude_memory]
          end
          revised_chapter << revised_fragment
        end
      ensure
        @chatgpt_client.threads.delete id: thread_id # Garbage collection
        $last_output = revised_chapter
        puts "Elapsed time: #{((Time.now - @@start_time) / 60).round(2)} minutes"
        puts "Claude memory word count: #{GPTK::Text.word_count claude_memory[:content].first[:text]}" if claude_client
      end
      revised_chapter
    end

    # Generate one or more chapters of the book
    # todo: update for multiple clients
    def generate(number_of_chapters = CONFIG[:num_chapters])
      CONFIG[:num_chapters] = number_of_chapters
      # Run in mode 1 (Automation), 2 (Interactive), or 3 (Batch)
      case @mode
        when 1
          puts "Automation mode enabled: Generating a novel #{number_of_chapters} chapter(s) long.\n"
          puts 'Sending initial prompt, and GPT instructions...'

          # Create the Assistant if it does not exist already
          assistant_id = if @clients.first.assistants.list['data'].empty?
            response = @clients.first.assistants.create(
              parameters: {
                model: GPTK::AI::CONFIG[:openai_gpt_model],
                name: 'AI Book generator',
                description: nil,
                instructions: @instructions
              }
            )
            response['id']
                         else
                           @clients.first.assistants.list['data'].first['id']
                         end

          # Create the Thread
          response = @clients.first.threads.create
          thread_id = response['id']

          # Send the AI the book outline for future reference
          prompt = "The following text is the outline for a #{genre} novel I am about to generate. Use it as reference when processing future requests, and refer to it explicitly when generating each chapter of the book:\n\n#{@outline}"
          @clients.first.messages.create(
            thread_id: thread_id,
            parameters: { role: 'user', content: prompt }
          )

          # Generate as many chapters as are specified
          prompt = "Generate a fragment of chapter 1 of the book, referring to the outline already supplied. Utilize as much output length as possible when returning content."
          messages = generate_chapter prompt, 1, thread_id, assistant_id

          # Cache result of last operation
          @last_output = messages

          # Output useful metadata
          # output_run_info
          # output_run_info @output_file
          @@start_time = Time.now

          response
        when 2
        when 3
        else puts 'Please input a valid script run mode.'
      end
    end

    # Generate one or more chapters of the book
    def generate_zipper(number_of_chapters = CONFIG[:num_chapters], fragments = 1)
      @@start_time = Time.now
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
                               description: nil,
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
          parity = parity == 0 ? 1 : 0
          prev_chapter = chapter
          @last_output = chapter # Cache results of the last operation
          chapters << chapter
        end

        @last_output = chapters # Cache results of the last operation
        chapters # Return the generated story chapters
      ensure
        @chatgpt_client.threads.delete id: thread_id # Garbage collection
        # Output some metadata - useful information about the run, API status, book content, etc.
        $chapters = chapters
        $outline = @outline
        $last_output = @last_output
        puts "Elapsed time: #{((Time.now - @@start_time) / 60).round(2)} minutes"
        puts "Claude memory word count: #{GPTK::Text.word_count claude_memory[:content].first[:text]}"
      end
      puts "Congratulations! Successfully generated #{chapters.count} chapters."
      chapters
    end
  end
end