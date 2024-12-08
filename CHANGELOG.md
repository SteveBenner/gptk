# Changelog

## 0.10
- Added `Book#revise_chapter2` which is a method for rewriting or removing duplicated content within a chapter
- Various fixes and code updates
- FIXED: `Book#save`
- FIXED: `Book#output_run_info`

## 0.9 - 2024.12.07
- New query method `Gemini.query_with_cache` which allows for use of caching

## 0.8 - 2024.12.06
- Generate a book using either of the 4 ALI clients currently incorporated
- Added API response failure rescue code for Claude

## 0.7 - 2024.12.05
- Integrated Grok via `GPTK::AI::Grok` module
- Integrated Gemini via `GPTK::AI::Gemini` module

## 0.6 - 2024.12.04
- Added `Book::revise_chapter1` which represents a totally new system for interactively revising chapter content, analyzing for bad patterns and then, either altering the text content, removing the match entirely, or simply ignoring the match.
- Includes 3 modes:
  - Mode 1: Apply an operation to ALL instances of bad pattern matches at once.
  - Mode 2: Iterate through each bad pattern and choose an operation to apply to all of the matches.
  - Mode 2A: Interactively go through each bad pattern match and decide which operation to apply.
- Added a `Utils` module for extra goodies

## 0.5 - 2024.11.27
- Revised `Book` to take an Array of clients instead of just one, and updated client code accordingly
- Added the 'zipper' technique to the `Book` module, including the `::generate_zipper` and `::generate_chapter_zipper` methods which implement a back-and-forth means of generating content utilizing one or more AI's instead of just one.