module GPTK
  class Book
    num_chapters = 13 # BE EXTREMELY CAREFUL SETTING THIS VALUE!!!
    chapter_fragments = 5 # This determines how many chapter fragments are in a chapter. Larger values = more words.
    chapter_fragment_words = 3000 # How large each chapter fragment is
    CONFIG = {
      num_chapters: num_chapters,
      chapter_fragments: chapter_fragments,
      chapter_fragment_words: chapter_fragment_words,
      initial_prompt: 'Generate the first portion of the current chapter of the story.'.freeze,
      continue_prompt: 'Continue generating the current chapter of the story, starting from where we left off. Do NOT repeat any previously generated material.'.freeze,
      prompt: "For the chapter title and content, refer EXPLICITLY to the outline, and if included, the prior chapter summary and current chapter summary. Refer to your context for memory of prior content, as well. Chapter title should be an H1 element SPECIFICALLY (# character in markdown) followed by the chapter name. Chapter titles must match those in the outline EXACTLY. Generate AT LEAST #{chapter_fragment_words} words.".freeze,
      post_prompt: 'Make SURE to include the chapter number with the chapter title.',
      command_code: 'The response should FIRST contain the chapter content, THEN, delineated with 3 dashes (markdown horizontal line), a summary of the current chapter fragment. Delineation of the summary MUST be 3 dashes SPECIFICALLY.'.freeze,
      # Define atomic parsing steps via Ruby procs, so they can be passed individually to parser methods
      # Each element is composed of 1) A regular expression search pattern, and 2) A string replacement pattern
      default_parsers: { # Regex, replacement
        convert_bolded_titles_to_h1_and_add_newline: [/\*\*(chapter \d\d?:.*?)\*\*/i, "\n\n# \\1"],
        convert_h2_and_h3_headings_to_h1: [/\#{1,3}/i, '#'],
        remove_quotes_around_chapter_titles: [/chapter (\d{1,2}): [“"“](.+?)[”"”]/i, 'Chapter \1: \2'],
        remove_extraneous_chapter_titles: [/(\# chapter \d{1,2}: .+?$)/i, Proc.new do |chapter_title|
         # Check if this chapter title has been encountered before
         if encountered_chapter_titles.include? chapter_title # Replace current instance with an empty string
           ''
         else # No text replacement necessary for the first instance, BUT we need to add a newline
           encountered_chapter_titles << chapter_title
           $/ + chapter_title
         end
        end],
        # add_newlines_before_chapter_titles: /(?<!\n)\n#/
        remove_horizontal_bars: [/\n---\n/, nil],
        remove_extra_newlines_from_start_of_file: [/\n\n(.*)/i, '\1'],
        remove_chapter_conclusion: [/---\n\n.*chapter*[^-]*---/, nil]
      }
    }
  end
end
