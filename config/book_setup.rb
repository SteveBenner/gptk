# Parameters for the generation of a complete novel-length book
NUM_CHAPTERS = 33 # BE EXTREMELY CAREFUL SETTING THIS VALUE!!!
CHAPTER_FRAGMENTS = 3 # This determines how many chapter fragments are in a chapter. Larger values = more words.
CHAPTER_FRAGMENT_WORDS = 1000 # How large each chapter fragment is
CHAPTER_MIN_WORDS = 3000 # Unused
CHAPTER_MAX_WORDS = 5500 # Unused
CHAPTER_LIMIT_TOLERANCE = 500 # Unused; Number of words the chapter can differ from the maximum word limit
# Define initial prompts
GENERATE_MSG = "Generating a novel #{NUM_CHAPTERS} chapters long.\n".freeze
INITIAL_PROMPT = 'Generate the first portion of the current chapter of the story.'.freeze
CONTINUE_PROMPT = 'Continue generating the current chapter of the story, starting from where we left off in the chapter summary. Do NOT repeat any previously generated material.'.freeze
PROMPT = "For the chapter title and content, refer EXPLICITLY to the outline, and if included, the prior chapter summary and current chapter summary. Refer to your context for memory of prior content, as well. Chapter title should be an H1 element SPECIFICALLY (# character in markdown) followed by the chapter name. Chapter titles must match those in the outline EXACTLY. Generate AT LEAST #{CHAPTER_FRAGMENT_WORDS} words.".freeze
PROMPT2 = "For the chapter title and content, refer EXPLICITLY to the outline and the current chapter summary. Refer to your context for memory of prior content, as well. Chapter title should be an H1 element SPECIFICALLY (# character in markdown) followed by the chapter name. Chapter titles must match those in the outline EXACTLY. Generate #{CHAPTER_FRAGMENT_WORDS * CHAPTER_FRAGMENTS} words.".freeze
POST_PROMPT = 'Make SURE to include the chapter number with the chapter title.'
COMMAND_CODE = 'The response should FIRST contain the chapter content, THEN, delineated with 3 dashes (markdown horizontal line), a summary of the current chapter fragment. Delineation of the summary MUST be 3 dashes SPECIFICALLY.'.freeze
