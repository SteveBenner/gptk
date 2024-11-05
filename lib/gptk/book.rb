module GPTK
  # todo: handle cases where no 'instructions' file or content is present
  # todo: incorporate `continuity` prompt parameter
  class Book
    attr_reader :chapters, :client, :last_output
    attr_accessor :parsers

    def initialize(api_client,
                   outline,
                   instructions,
                   output_filename='',
                   rec_prompt='',
                   parsers=CONFIG[:parsers],
                   mode=GPTK.mode)
      @client = api_client # Platform-agnostic API connection object (for now just supports OpenAI)
      # Reference document for book generation
      @outline = <<~OUTLINE_STR
OUTLINE

#{::File.exist?(outline) ? ::File.read(outline) : outline}

OUTLINE
      OUTLINE_STR
      @outline = @outline.encode 'UTF-8', invalid: :replace, undef: :replace, replace: '?'
      @instructions = ::File.exist?(instructions) ? ::File.read(instructions) : instructions
      @output_file = ::File.open output_filename, 'w+'
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
      @genre = 'sci-fi'
    end

    # Construct a prompt based on the outline, previous ch~apter summary, and current chapter summary
    def build_prompt(prompt, chapter_number, chapter_summary)
      meta_prompt = "Current chapter: #{chapter_number}.\n"
      # unless prior_chapter_summary.empty?
      #   meta_prompt += "PRIOR CHAPTER SUMMARY: #{prior_chapter_summary}\nEND OF PRIOR CHAPTER SUMMARY\n"
      # end
      unless chapter_summary.empty?
        meta_prompt += "CURRENT CHAPTER SUMMARY: #{chapter_summary}\nEND OF CURRENT CHAPTER SUMMARY\n"
      end
      generation_prompt = (chapter_number == 1 && chapter_summary.empty?) ?
                            CONFIG[:initial_prompt]
                            : CONFIG[:continue_prompt]
      [@outline, meta_prompt, generation_prompt, prompt, CONFIG[:post_prompt], CONFIG[:command_code]].join ' '
    end

    # Generate one complete chapter of the book using the given prompt, for the given CLIENT
    def generate_chapter(general_prompt, chapter_number, parsers=@parsers, recommendations_prompt=@rec_prompt)
      puts "Generating chapter #{chapter_number}...\n"
      chapter, chapter_summary = '', ''

      # Create the chapter chunk by chunk, referencing previous chapter content within the loop
      (1..GPTK::Book::CONFIG[:chapter_fragments]).each do |i|
        puts "Generating fragment #{i}..."
        prompt = build_prompt general_prompt, chapter_number, chapter_summary

        # Send the prompt to ChatGPT using the chat API, and retrieve the response
        response = GPTK::AI.query @client, prompt, @data
        # Parse the received content using specified parsing components
        content = parse_response response, parsers
        abort 'Error: failed to generate a viable chapter fragment!' unless content

        # Compose the chapter fragment by fragment
        chapter << content[:chapter_fragment] + ' '
        # Generate a summary of the current chapter, fragment by fragment
        chapter_summary << content[:chapter_summary] + ' ' if content[:chapter_summary]
      end

      @data[:current_chapter] += 1 # For data tracking purposes

      # Revise chapter if 'recommendations_prompt' text or file are given
      chapter = revise_chapter(chapter, recommendations_prompt) unless recommendations_prompt.empty?

      # Count and tally the total number of words generated for each chapter
      @data[:word_counts] << GPTK::Text.word_count(chapter)

      chapter # Return the generated chapter
    end

    # Revise the chapter based upon a set of specific guidelines, using ChatGPT
    def revise_chapter(chapter, recommendations_prompt)
      puts "Revising chapter..."
      revision_prompt = "Please revise the following chapter content:\n\n" + chapter + "\n\nREVISIONS:\n" +
        recommendations_prompt + "\nDo NOT change the chapter title or number--this must remain the same as the original, and must accurately reflect the outline."
      GPTK::AI.query @client, revision_prompt, @data
    end

    # Parse a ChatGPT response text into the chapter content and the 'command code'
    # Note: due to the tendency of ChatGPT to produce variance in output, significant
    # reformatting of the output is required to ensure consistency
    # todo: remove revision prompt
    def parse_response(text, parsers=nil)
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
          case @parsers[parser[0][1]].class # Pass each case to String#gsub!
          # Search expression, and replacement string
          when String then fragment.gsub! @parsers[parser][1][0], @parsers[parser][0][1]
          # Proc to run against the current fragment
          when Proc   then fragment.gsub! @parsers[parser][1][0], @parsers[parser][0][1]
          # Search expression to delete from output
          when nil    then fragment.gsub! @parsers[parser][1], ''
          else puts "Parser: '#{parser[0][1]}' is invalid. Use a String, a Proc, or nil."
          end
        end
      end

      { chapter_fragment: fragment, chapter_summary: summary }
    end

    # Output useful information (metadata) after a run, (or part of a run) to STDOUT by default, or a file if given
    def output_run_info(file=nil)
      io_stream = file ? ::File.open(file, 'a+') : STDOUT
      io_stream.seek 0, IO::SEEK_END
      io_stream.puts "Successfully generated #{CONFIG[:num_chapters]} chapters, for a total of #{@data[:word_counts].reduce &:+} words."
      io_stream.puts <<~STRING
        Total token usage:
        - Prompt tokens used: #{@data[:prompt_tokens]}
        - Completion tokens used: #{@data[:completion_tokens]}
        - Total tokens used: #{@data[:prompt_tokens] + @data[:completion_tokens]}
        - Cached tokens used: #{@data[:cached_tokens]}
        - Cached token percentage: #{((@data[:cached_tokens].to_f / @data[:prompt_tokens]) * 100).round 2}%
      STRING
      io_stream.puts "Elapsed time: #{((Time.now - START_TIME) / 60).round 1} minutes." # Print script run duration
      io_stream.puts "Words by chapter:\n"
      @data[:word_counts].each_with_index { |chapter_words, i| io_stream.puts "Chapter #{i + 1}: #{chapter_words} words" }
    end

    # Write the finished chapters to the output file
    def save
      abort 'Error: no content to write.' if @chapters.empty?
      @chapters.each_with_index do |chapter, i|
        puts "Writing chapter #{i + 1} to file..."
        @output_file.puts "#{chapter}\n"
      end
      puts "Successfully wrote #{@chapters.count} chapters to file: #{::File.path @output_file}"
    end

    # Generate one or more chapters of the book
    def generate(number_of_chapters=CONFIG[:num_chapters], genre=@genre)
      CONFIG[:num_chapters] = number_of_chapters
      # Run in mode 1 (Automation), 2 (Interactive), or 3 (Batch)
      case @mode
        when 1
          puts "Automation mode enabled: Generating a novel #{number_of_chapters} chapter(s) long.\n"
          puts 'Sending initial prompt, and GPT instructions...'

          # Send ChatGPT the book outline for future reference, and provide it with a specific instruction set
          prompt = "The following text is the outline for a #{genre} novel I am about to generate. Use it as reference when processing future requests, and refer to it explicitly when generating each chapter of the book.\n#{@outline}"
          @client.chat(
            parameters: {
              model: GPTK::AI::CONFIG[:openai_gpt_model],
              messages: [
                { role: 'system', content: @instructions.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?') },
                { role: 'user', content: prompt.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?') }
              ],
              temperature: GPTK::AI::CONFIG[:openai_temperature]
            }
          )

          # Generate the first chapter
          @chapters << generate_chapter(CONFIG[:prompt], 1)

          # Generate the rest of the chapters
          if number_of_chapters.to_i > 1
            (2..number_of_chapters.to_i).each do |chapter_number|
              @chapters << generate_chapter(CONFIG[:prompt], chapter_number)
            end
          end

          # Cache result of last operation
          @last_output = @chapters

          # Output useful metadata
          output_run_info
          output_run_info @output_file

          @chapters
        when 2
        when 3
        else puts 'Please input a valid script run mode.'
      end
    end
  end
end