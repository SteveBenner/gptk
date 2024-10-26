module GPTK
  class Book
    num_chapters = 33 # BE EXTREMELY CAREFUL SETTING THIS VALUE!!!
    chapter_fragments = 3 # This determines how many chapter fragments are in a chapter. Larger values = more words.
    chapter_fragment_words = 1000 # How large each chapter fragment is
    CONFIG = {
      chapter_min_words: 3000, # Unused,
      chapter_max_words: 5500, # Unused,
      chapter_limit_tolerance: 500, # Unused; Number of words the chapter can differ from the maximum word limit,
      generate_msg: "Generating a novel #{num_chapters} chapters long.\n".freeze,
      initial_prompt: 'Generate the first portion of the current chapter of the story.'.freeze,
      continue_prompt: 'Continue generating the current chapter of the story, starting from where we left off in the chapter summary. Do NOT repeat any previously generated material.'.freeze,
      prompt: "For the chapter title and content, refer EXPLICITLY to the outline, and if included, the prior chapter summary and current chapter summary. Refer to your context for memory of prior content, as well. Chapter title should be an H1 element SPECIFICALLY (# character in markdown) followed by the chapter name. Chapter titles must match those in the outline EXACTLY. Generate AT LEAST #{chapter_fragment_words} words.".freeze,
      prompt2: "For the chapter title and content, refer EXPLICITLY to the outline and the current chapter summary. Refer to your context for memory of prior content, as well. Chapter title should be an H1 element SPECIFICALLY (# character in markdown) followed by the chapter name. Chapter titles must match those in the outline EXACTLY. Generate #{chapter_fragment_words * chapter_fragments} words.".freeze,
      post_prompt: 'Make SURE to include the chapter number with the chapter title.',
      command_code: 'The response should FIRST contain the chapter content, THEN, delineated with 3 dashes (markdown horizontal line), a summary of the current chapter fragment. Delineation of the summary MUST be 3 dashes SPECIFICALLY.'.freeze
    }
  end
end
