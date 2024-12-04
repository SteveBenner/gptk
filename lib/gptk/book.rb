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
      chapter # Array of Strings representing chapter fragments for one chapter
    end

    # todo: apply user-generated revisions
    #   - pattern by pattern, interact with human!
    #   - options: change, eliminate, and/or ignore for EACH OCCURRENCE
    #   - batch mode: offer an option to batch one of the choices for EACH PATTERN

    # Revises a chapter fragment-by-fragment, ensuring adherence to specific content rules.
    #
    # This method processes a given chapter, analyzing and revising its content
    # using AI clients such as ChatGPT and Claude. The revisions focus on reducing
    # the frequency of predefined "bad patterns" and adhering to specific content rules.
    # The revised chapter is returned as an array of updated fragments.
    #
    # @param [Array<String>] chapter
    #   An array of chapter fragments to be revised. Each fragment is a string
    #   representing a portion of the chapter.
    #
    # @param [Object] chatgpt_client (optional)
    #   The ChatGPT client instance to use for querying and revisions.
    #   Defaults to `@chatgpt_client` if not explicitly provided.
    #
    # @param [Object] claude_client (optional)
    #   The Claude client instance for querying and memory management.
    #   Defaults to `@claude_client` if not explicitly provided.
    #
    # @param [String, nil] anthropic_api_key (optional)
    #   An API key for authenticating requests to the Claude client.
    #   Defaults to `nil` if not explicitly provided.
    #
    # @return [Array<String>]
    #   The final revised chapter, in two formats: plain text, and numbered (by sentence)
    #
    # @example Revise a chapter with ChatGPT and Claude clients
    #   chapter = [
    #     "The protagonist's heart raced as they entered the eerie cave.",
    #     "The air grew thick with tension, and a lion roared in the distance."
    #   ]
    #   revised = revise_chapter1(chapter, chatgpt_client: my_chatgpt_client, claude_client: my_claude_client)
    #   puts revised
    #
    # @note
    #   - The method ensures only one instance of any "bad pattern" appears across the entire chapter.
    #   - When both clients are provided, the method coordinates their responses, with Claude
    #     adding contextual revisions to ChatGPT's output.
    #   - The method handles API interactions, memory updates, and garbage collection for AI threads.
    #   - Currently it is NOT thorough, and this is a limitation of the AIs themselves unfortunately.
    #
    # TODO: write 'revise_book' that can take an entire book file and break it down chapter by chapter
    def revise_chapter1(chapter, chatgpt_client: @chatgpt_client, claude_client: @claude_client, anthropic_api_key: nil)
      start_time = Time.now
      claude_memory = nil
      chapter_text = chapter.instance_of?(String) ? chapter : chapter.join(' ')

      begin
        # Give every sentence of the chapter a number, for parsing out bad patterns
        sentences = chapter_text.split /(?<!\.\.\.)(?<!O\.B\.F\.)(?<=\.|!|\?)/ # TODO: fix regex
        numbered_chapter_text = sentences.map.with_index { |sentence, i| "**[#{i + 1}]** #{sentence.strip}" }.join(' ')

        # Scan for bad patterns and generate an Array of results to later parse out of the book content
        bad_pattern_prompt = <<~STR
          Analyze the given chapter text exhaustively for the following writing patterns, and output all found matches as a JSON object. Scan for MULTIPLE matches for each pattern. Patterns:
          1. **Excessive Quotations or Overused Sayings**: Identify instances where quotes, idioms, aphorisms, or platitudes are over-relied upon, leading to a lack of originality in expression.
          2. **Clichés**: Highlight phrases or expressions that are overly familiar or predictable, diminishing the impact of the prose.
          3. **Cheesy or Overwrought Descriptions**: Pinpoint descriptions that are overly sentimental, melodramatic, unrefined, or simply using exposé (i.e., “telling” not “showing” the plot advancement).
          4. **Redundancies**: Detect repetitive ideas, words, or phrases that do not add value or nuance to the text.
          5. **Pedantic Writing**: Flag passages that feel condescending or patronizing without advancing the narrative or theme.
          6. **Basic or Unsophisticated Language**: Identify "basic-bitch" tendencies, such as dull word choices, shallow insights, obtuse statements, or oversimplified metaphors.
          7. **Overstated or Over-explanatory Passages**: Locate areas where the text feels "spelled out" unnecessarily, where the writing style is overly “telling” the story instead of “showing” it with descriptive narrative.
          8. **Forced Idioms or Sayings**: Highlight awkwardly inserted idiomatic expressions that clash with the tone or context of the writing.

          ONLY output the object, no other response text or conversation, and do NOT put it in a Markdown block. ONLY output proper JSON. Create the following output: an Array of objects which each include: 'match' (the recognized pattern), 'sentence' (the surrounding sentence the pattern was found in) and 'sentence_count' (the number of the sentence the bad pattern was found in). BE EXHAUSTIVE--once you find ONE pattern, do a search for all other matching cases and add those to the output.\n\nCHAPTER:\n\n#{numbered_chapter_text}
        STR
        chatgpt_matches = JSON.parse(GPTK::AI::ChatGPT.query(@chatgpt_client, @data, bad_pattern_prompt))['matches']
        ap chatgpt_matches
        claude_matches = JSON.parse GPTK::AI::Claude.query_with_memory(
          anthropic_api_key, [{ role: 'user', content: bad_pattern_prompt }]
        )
        ap claude_matches
        unless claude_matches.instance_of? Array
          claude_matches = if claude_matches.key? 'matches'
                             claude_matches['matches']
                           elsif claude_matches.key? 'patterns'
                             claude_matches['patterns']
                           end
        end

        # Remove any duplicate matches from Claude's results (matches already picked up by ChatGPT)
        claude_matches.delete_if do |match|
          chatgpt_matches.any? { |i| i['match'] == match['match'] && i['sentence_count'] == match['sentence_count'] }
        end
        claude_matches.delete_if do |match|
          chatgpt_matches.any? do |i|
            i['sentence'] == match['sentence'] && i['sentence_count'] == match['sentence_count']
          end
        end

        bad_patterns = chatgpt_matches.uniq.concat claude_matches.uniq
        # Group the results by match
        bad_patterns = bad_patterns.map { |p| Utils.symbolify_keys p }.group_by { |i| i[:match] }
        # Sort the matches by the order of when they appear in the chapter
        bad_patterns.each do |pattern, matches|
          bad_patterns[pattern] = matches.sort_by { |m| m[:word] }
        end

        # Create a new ChatGPT Thread
        thread_id = chatgpt_client.threads.create['id']

        match_count = bad_patterns.values.flatten.count
        puts "#{bad_patterns.count} bad patterns detected (#{match_count} total matches):"
        bad_patterns.each do |pattern, matches|
          puts "- '#{pattern}' (#{matches.count} counts)"
        end

        # Prompt user for the mode
        puts 'How would you like to proceed with the revision process for the detected bad patterns?'
        puts 'Enter an option number: 1, or 2:'
        puts 'Mode 1: Apply an operation to ALL instances of bad pattern matches at once.'
        puts 'Mode 2: Iterate through each bad pattern and choose an operation to apply to all of the matches.'
        mode = gets.to_i

        revised_chapter = chapter_text
        case mode
        when 1 # Apply operation to ALL matches
          bad_matches = bad_patterns # Flatten the grouped matches into a single list and order them
                        .flatten.flatten.delete_if { |p| p.instance_of? String }.sort_by { |p| p[:sentence_count] }
          puts "Which operation do you wish to apply to all #{bad_matches.count}? 1) Keep as is, 2) Change, 3) Delete"
          operation = gets.to_i

          case operation
          when 1 then puts 'Content accepted as-is.'
          when 2 # Have Claude or ChatGPT revise each sentence containing a bad pattern match
            puts 'Would you like to 1) replace each match occurrence manually, or 2) use Claude to replace it?'
            choice = gets.to_i

            case choice
            when 1
              bad_matches.each do |match|
                puts "Pattern: #{match[:match]}"
                puts "Sentence: #{match[:sentence]}"
                puts "Sentence Number: #{match[:sentence_count]}"
                puts 'Please input your revised sentence.'
                revised_sentence = gets
                revised_chapter.gsub! match[:sentence], revised_sentence
                puts 'Revision complete!'
              end
            when 2
              bad_matches.each do |match|
                prompt = <<~STR
                  Revise the following sentence in order to eliminate the bad pattern, making sure completely rewrite the sentence. PATTERN: '#{match[:match]}'. SENTENCE: '#{match[:sentence]}'. ONLY output the revised sentence, no other commentary or discussion.
                STR
                # chatgpt_revised_sentence = GPTK::AI::ChatGPT.query @chatgpt_client, @data, prompt
                claude_revised_sentence = GPTK::AI::Claude.query_with_memory anthropic_api_key,
                                                                             [{ role: 'user', content: prompt }]
                # Revise the chapter text based on AI feedback
                puts "Revising sentence #{match[:sentence_count]} using Claude..."
                puts "Original: #{match[:sentence]}"
                puts "Revision: #{claude_revised_sentence}"
                sleep 1
                revised_chapter.gsub! match[:sentence], claude_revised_sentence
              end
            else raise 'Error: Input either 1 or 2'
            end

            puts "Successfully enacted #{bad_matches.count} revisions!"
          when 3 # Delete all examples of bad pattern sentences
            bad_matches.each do |match|
              puts 'Revising chapter...'
              puts "Sentence [#{match[:sentence_count]}] deleted: #{match[:sentence]}"
              sleep 1
              revised_chapter.gsub! match[:sentence], ''
            end
          else raise 'Invalid operation. Must be 1, 2, or 3'
          end
        when 2 # Iterate through bad patterns and prompt user for action to perform on all matches per pattern
          bad_patterns.each do |pattern, matches|
            sentence_positions = matches.sort_by { |m| m[:sentence_count] }.collect { |m| m[:sentence_count] }.join ', '
            puts "\nBad pattern detected: '#{pattern}' #{matches.count} matches found (sentences #{sentence_positions})"
            puts "Which operation do you wish to apply to all #{matches.count} matches?"
            puts '1) Keep as is, 2) Change, 3) Delete, or 4) Review'
            operation = gets.to_i

            case operation
            when 1
              puts "Ignoring #{matches.count} matches for pattern '#{pattern}'..."
            when 2
              puts 'Would you like to 1) have ChatGPT perform revisions on all the matches using its own judgement,'
              puts 'or 2) would you like to provide a general prompt ChatGPT will use to revise the matches?'
              choice = gets.to_i
              case choice
              when 1 # Have ChatGPT auto-revise content
                matches.each do |match|
                  prompt = <<~STR
                    Revise the following sentence in order to eliminate the bad pattern, making sure completely rewrite the sentence. PATTERN: '#{pattern}'. SENTENCE: '#{match[:sentence]}'. ONLY output the revised sentence, no other commentary or discussion.
                  STR
                  puts "Revising sentence #{match[:sentence_count]}..."
                  chatgpt_revised_sentence = GPTK::AI::ChatGPT.query @chatgpt_client, @data, prompt
                  puts "ChatGPT revision: '#{chatgpt_revised_sentence}'"
                  revised_chapter.gsub! match[:sentence], chatgpt_revised_sentence
                end
                puts "Successfully revised #{matches.count} bad pattern occurrences using ChatGPT!"
              when 2 # Prompt user to specify prompt for the ChatGPT
                puts 'Please enter a prompt to instruct ChatGPT regarding the revision of these bad pattern matches.'
                user_prompt = gets
                matches.each do |match|
                  prompt = <<~STR
                    Revise the following sentence in order to eliminate the bad pattern, making sure completely rewrite the sentence. PATTERN: '#{pattern}'. SENTENCE: '#{match[:sentence]}'. ONLY output the revised sentence, no other commentary or discussion. #{user_prompt}
                  STR
                  puts "Revising sentence #{match[:sentence_count]}..."
                  chatgpt_revised_sentence = GPTK::AI::ChatGPT.query @chatgpt_client, @data, "#{prompt}"
                  puts "ChatGPT revision: '#{chatgpt_revised_sentence}'"
                  revised_chapter.gsub! match[:sentence], chatgpt_revised_sentence
                end
                puts "Successfully revised #{matches.count} bad pattern occurrences using your prompt and ChatGPT!"
              else raise 'Invalid option. Must be 1 or 2'
              end
            when 3 # Delete all instances of the bad pattern
              matches.each do |match|
                puts "Deleting sentence #{match[:sentence_count]}..."
                revised_chapter.gsub! match[:sentence], ''
                puts "Deleted: '#{match[:sentence]}'"
              end
              puts "Deleted #{matches.count} bad pattern occurrences!"
            when 4 # Interactively or automagically address each bad pattern match one by one
              puts "Reviewing #{matches.count} matches of pattern: '#{pattern}'..."
              matches.each do |match|
                puts "Pattern: #{match[:match]}"
                puts "Sentence: #{match[:sentence]}"
                puts "Sentence Number: #{match[:sentence_count]}"
                puts 'Would you like to 1) Keep as is, 2) Revise, or 3) Delete?'
                choice = gets.to_i
                case choice
                when 1 then puts 'Original content left unaltered.'
                when 2
                  puts 'Would you like to 1) input a revision yourself, or 2) use ChatGPT to generate a revision?'
                  choice2 = gets.to_i
                  if choice2 == 1
                    puts 'Please input your revised sentence:'
                    user_revision = gets
                    revised_chapter.gsub! match[:sentence], user_revision
                  elsif choice2 == 2
                    puts 'Generating a revision using ChatGPT...'
                    prompt = <<~STR
                      Revise the following sentence in order to eliminate the bad pattern, making sure completely rewrite the sentence. PATTERN: '#{match[:match]}'. SENTENCE: '#{match[:sentence]}'. ONLY output the revised sentence, no other commentary or discussion.
                    STR
                    chatgpt_revision = GPTK::AI::ChatGPT.query @chatgpt_client, @data, prompt
                    puts "Original sentence: #{match[:sentence]}"
                    puts "Revised sentence: #{chatgpt_revision}"
                    puts 'Would you like to 1) Accept this revised sentence, 2) Revise it again, or 3) Keep original?'
                    choice = gets.to_i
                    case choice
                    when 1
                      puts 'Updating chapter...'
                      revised_chapter.gsub! match[:sentence], chatgpt_revision
                    when 2
                      puts 'Generating a new revision...'
                      chatgpt_revision = GPTK::AI::ChatGPT.query @chatgpt_client, @data, prompt
                      puts "Revised sentence: #{chatgpt_revision}"
                      puts 'How do you like this revision? Indicate whether you accept or want another rewrite.'
                      puts 'Input Y|y or N|n to indicate yes or no to accepting this revision.'
                      response = gets.chomp
                      until response == 'Y' || response == 'y' do
                        puts 'Generating a new revision...'
                        chatgpt_revision = GPTK::AI::ChatGPT.query @chatgpt_client, @data, prompt
                        puts "New revised sentence: #{chatgpt_revision}"
                        puts 'How do you like this new revision? Indicate whether you accept or want another rewrite.'
                        response = gets.chomp
                      end
                      revised_chapter.gsub! match[:sentence], chatgpt_revision
                    when 3
                      puts "Leaving sentence #{match[:sentence_count]} unaltered: '#{match[:sentence]}'..."
                    else raise 'Invalid choice. Must be 1, 2, or 3'
                    end
                  else
                    raise 'Invalid choice. Must be 1 or 2'
                  end
                when 3
                  print "Removing sentence #{match[:sentence_count]}: '#{match[:sentence]}'..."
                  revised_chapter.gsub! match[:sentence], ''
                  puts ' Done!'
                else raise 'Invalid choice. Must be 1, 2, or 3'
                end
              end
            else raise 'Invalid operation. Must be 1, 2, 3, or 4'
            end
          end
        else raise 'Invalid mode. Must be 1, or 2'
        end

        # Give every sentence of the revised chapter a number, for proofreading and correcting errors later
        revised = revised_chapter.split /(?<=\.)|(?<=\!)|(?<=\?)/
        numbered_chapter_text = revised.map.with_index { |sentence, i| "**[#{i + 1}]** #{sentence.strip}" }.join(' ')
      ensure
        @chatgpt_client.threads.delete id: thread_id # Garbage collection
        @last_output = revised_chapter
        puts "Elapsed time: #{((Time.now - start_time) / 60).round(2)} minutes"
        puts "Claude memory word count: #{GPTK::Text.word_count claude_memory[:content].first[:text]}" if claude_memory
      end

      [revised_chapter, numbered_chapter_text]
    end

    # Generate one or more chapters of the book
    # TODO: update for multiple clients
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
      when 2 # TODO
      when 3 # TODO
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
