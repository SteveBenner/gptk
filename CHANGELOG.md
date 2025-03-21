# Changelog

Note - Every reference to modules and classes assumes we are operating under the `GPTK` namespace. For example, the `Book` class refers to `GPTK::Book`, and the `AI` module refers to `GPTK::AI`.

## 0.23 / 2025.03.11
- Added generic `AutoCoder` class to the `AI` module. You initialize a new `AutoCoder` object with one or more API keys determining which AI platforms you will use. `AutoCoder#query_to_rails_code` allows you to then generate revisions to multiple existing rails projects per single query, looping for user interaction.
- Various fixes to `AutoCoder`
- ChatGPT client gem `ruby-openai` is broken at this point. Wrote a workaround method `AI::ChatGPT::query_with_assistant` which manually uses HTTP to let you use the assistant API (takes `assistant_id` as required argument and `thread_id` as an optional keyword argument)
- Fixed Gemini queries

## 0.22 / 2025.03.09
- Added `AI:Claude::query_to_rails_code` using Claude Sonnet 3.7 with enhanced thinking capabilities

## 0.21 / 2025.02.22
- Added `AI::Grok::query_to_rails_code` (and several helper methods) for generating/rewriting rails code. It works super well.

## 0.20
- Added `AI::Gemini::query_to_rails_code` for generating/rewriting rails code
- Note: Gemini (model `gemini-1.5-pro`) is *not* great at generating code. I stopped using it.

## 0.19
- Added `Doc#categorize_and_colorize_docx` which modifies a docx in place to categorize and colorize enumerated items within, based on given category data. Still a work in progress.
- Added `AI::ChatGPT::query_to_rails_code` which runs an interactive session with the user in which they pass it an input, it analyzes the current state of your .erb, .sass, and .coffee files (set in `GPTK::CONFIG`) and rewrites them, saving the output back to the original file location, thus automating the process of updating your code!
- Modified `AI::run_assistant_thread` to take a `assistant_id` parameter, which defaults to nil, and if nil, defaults to the first available assistant for given client.

## 0.18 / 2025.01.03
- Added `AI::ChatGPT::run_batch` and `AI::ChatGPT::generate_batch` to re-enable use of batch mode.

## 0.17 / 2025.01.01
- Added `Text::remove_duplicates_from_docx` which modifies a `docx` file in place to remove duplicate sentences.
- Added missing documentation for `Text` and `Doc` module methods.
- Somehow fixed an issue with `Zip` namespace clashing.
- Added `Text::extract_numbered_items` which parses a `docx` file and returns a list of enumerated items.
- Added `Text::extract_document_xml` which is a private helper.
- Fixed bad param calls using `AI` methods.
- Other minor fixes.
- Refactored the `Text` and `Doc` modules so methods are in their proper places. Added `Parse` module in `Text` to encapsulate parsing methods.
- Updated `Doc#new` to take `file_path` and `content` as parameters.
- Finished documenting `Text` and `Doc` modules.

## 0.16 / 2024.12.30
- Toughened up Grok error handling so that it doesn't result in an infinite loop on a JSON parse error. It can now run safely in the background.
- Fixed an error in `Book#generate`
- Updated `Book#generate` and `Book#generate_chapter` to take a optional custom prompt parameter `post_prompt`.
- Revised the ChatGPT assistant thread code to be self-contained within the `AI` module.

## 0.15 / 2024.12.18
- Added [`README.md`](README.md) (finally).
- Added [`CONTRIBUTING.md`](CONTRIBUTING.md).
- Updated license to MIT.
- Minor library code tweaks.
- COMPLETED documentation of ALL library methods!
- REMOVED `File` module and moved its single method (`fname_increment`) to the `Utils` module.

## 0.14 / 2024.12.17
- Finally retired 'mode' as a general feature of the library (we moved on from initial 3-mode system design long ago)
- Plugged in 'training' data (a file included in content generation prompts to further inform the output). Training data can be specified in `Book#new` and defaults to a thorough list of included 'trainers'.
- FINALLY completed thorough documentation of the `Book` class.
- Modified revision code so as to begin text analysis using numbered chapter text
- Improved `Text::number_text` so as to be more robust, numbering sub-sentences (sentences within double quotes) as well 
- Refactored `AI::Claude::query_with_memory` to take either a `String` (single message) or an `Array` of messages

## 0.13 / 2024.12.14
- Added `Text::print_matches` which prints out pattern matches to markdown.
- Fixed revision pattern match merge code (it was problematic)
- Fixed text numbering issue that was causing issues with the revision output
- Updated `Text::number_text` to use the `pragmatic_segmenter` gem which is FAR superior to attempting to manually parse generated text content, and results is no erroneous numbering of sentences. This fixed numerous issues we were having with text numbering.
- Modified `Book#revise_chapter` to take an `agent` named parameter to specify the agent you want to use

## 0.12 / 2024.12.12
- Multiple fixes and improvements to v0.11 code
- Added more robust API call failure handling code for Gemini
- Added helper `Book#to_s` which outputs the entire book content in a readable string format.

## 0.11 / 2024.12.12
- Added `Text::Parse.numbered_categories` which parses text and outputs a Hash of all the numbered categories and their subcategories and text values
- COMPLETELY rewrote the revision code. Revised `Book#revise_chapter` so that it is now a single outer proxy for all revision strategies
- Added `Book#revise_chapter_content` which contains the lower level logic for implementing chapter revisions
- Added `Book#analyze_text` which is a middle-man for processing text and generating pattern matches for processing.
- Removed `Book#revise_chapter1` and `Book#revise_chapter2` as they are now merged into `Book#revise_chapter`.

## 0.10 / 2024.12.08
- Added `Book#revise_chapter2` which is a method for rewriting or removing duplicated content within a chapter
- Various fixes and code updates
- FIXED: `Book#save`
- FIXED: `Book#output_run_info`

## 0.9 / 2024.12.07
- New query method `Gemini.query_with_cache` which allows for use of caching

## 0.8 / 2024.12.06
- Generate a book using either of the 4 ALI clients currently incorporated
- Added API response failure rescue code for Claude

## 0.7 / 2024.12.05
- Integrated Grok via `GPTK::AI::Grok` module
- Integrated Gemini via `GPTK::AI::Gemini` module

## 0.6 / 2024.12.04
- Added `Book::revise_chapter1` which represents a totally new system for interactively revising chapter content, analyzing for bad patterns and then, either altering the text content, removing the match entirely, or simply ignoring the match.
- Includes 3 modes:
  - Mode 1: Apply an operation to ALL instances of bad pattern matches at once.
  - Mode 2: Iterate through each bad pattern and choose an operation to apply to all of the matches.
  - Mode 2A: Interactively go through each bad pattern match and decide which operation to apply.
- Added a `Utils` module for extra goodies

## 0.5 / 2024.11.27
- Revised `Book` to take an Array of clients instead of just one, and updated client code accordingly
- Added the 'zipper' technique to the `Book` class, including the `generate_zipper` and `generate_chapter_zipper` methods which implement a back-and-forth means of generating content utilizing one or more AI's instead of just one.