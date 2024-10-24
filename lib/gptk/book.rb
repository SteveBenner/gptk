module GPTK
  # todo: load recommendations from external file
  # todo: load GPT instructions from external file
  class Book
    attr_reader :chapters, :client, :data

    def initialize(api_client, outline, mode)
      @client = api_client # Platform-agnostic API connection object (for now just supports OpenAI)
      @outline = outline # Reference document for book generation
      @chapters = [] # Book content
      @mode = mode
      @data = { # Data points to track while generating a book chapter by chapter
        prompt_tokens: 0,
        completion_tokens: 0,
        cached_tokens: 0,
        word_counts: [],
        current_chapter: 1
      }
    end

    # # Generate chapters using the OpenAI API
    # def generate_chapter(chapter_number, parsers)
    #   puts "Generating chapter #{chapter_number}..."
    #
    #   chapter_content, chapter_summary = '', ''
    #
    #   (1..GPTK::CHAPTER_FRAGMENTS).each do |i|
    #     puts "Generating fragment #{i}..."
    #     prompt = build_prompt(chapter_number, chapter_summary)
    #
    #     # Send the prompt to OpenAI's API and get a response
    #     response = @client.chat(
    #       parameters: {
    #         model: GPTK::OPENAI_GPT_MODEL,
    #         messages: [{ role: 'user', content: prompt }],
    #         temperature: GPTK::OPENAI_TEMPERATURE
    #       }
    #     )
    #
    #     # Parse the response content
    #     content = parse_response(response.dig('choices', 0, 'message', 'content'), parsers)
    #     chapter_content << content[:chapter_fragment] + ' '
    #     chapter_summary << content[:chapter_summary] + ' '
    #
    #     # Log token usage
    #     log_token_usage(response)
    #   end
    #
    #   # After all fragments, revise the chapter
    #   chapter_content = revise_chapter(chapter_content)
    #
    #   # Store the generated chapter
    #   @chapters << chapter_content
    #
    #   # Return the chapter content
    #   chapter_content
    # end

    # def build_prompt(chapter_number, prior_summary)
    #   # Build the prompt that will be sent to OpenAI
    #   "Chapter #{chapter_number}.\nPRIOR SUMMARY: #{prior_summary}\nOUTLINE: #{@outline}"
    # end

    # def revise_chapter(chapter)
    #   # Revise chapter content using OpenAI
    #   revision_prompt = "Please revise the following chapter: #{chapter}"
    #   response = @client.chat(
    #     parameters: {
    #       model: GPTK::OPENAI_GPT_MODEL,
    #       messages: [{ role: 'user', content: revision_prompt }],
    #       temperature: GPTK::OPENAI_TEMPERATURE
    #     }
    #   )
    #   response.dig('choices', 0, 'message', 'content')
    # end

    # def parse_response(text, parsers)
    #   # Apply the parsers to modify the text as needed
    #   fragment = text
    #   parsers.each do |parser|
    #     fragment.gsub!(GPTK::PARSERS[parser][0], GPTK::PARSERS[parser][1])
    #   end
    #   { chapter_fragment: fragment, chapter_summary: "Summary" } # Simplified for brevity
    # end

    # def log_token_usage(response)
    #   GPTK::PROMPT_TOKENS += response.dig('usage', 'prompt_tokens')
    #   GPTK::COMPLETION_TOKENS += response.dig('usage', 'completion_tokens')
    # end

    # # Output useful run information after all chapters are generated
    # def output_run_info
    #   puts "Total chapters: #{@chapters.size}"
    #   puts "Time elapsed: #{GPTK::Helpers.elapsed_time} minutes"
    # end
  end
end