require 'pragmatic_segmenter'

module GPTK
  module Text
    # Calculates the number of words in a given text.
    #
    # This method counts the words in the provided text by splitting it on whitespace.
    # Words are defined as sequences of characters separated by one or more whitespace characters.
    #
    # @param text [String] The input text whose words are to be counted.
    #
    # @return [Integer] The number of words in the input text.
    #
    # @example Counting words in a string:
    #   input = "Hello, world! This is a test."
    #   Text.word_count(input)
    #   # => 6
    #
    # @note
    #   - The method uses a regular expression (`/\s+/`) to split the text into words.
    #   - Any sequence of whitespace characters (spaces, tabs, newlines) is treated as a delimiter.
    #   - An empty string will return a count of 0.
    #
    # @see String#split
    def self.word_count(text)
      text.split(/\s+/).count
    end

    # Adds sequential numbering to sentences in a text, with special labeling for quoted content.
    #
    # This method processes the input text by splitting it into paragraphs and sentences.
    # Each sentence is numbered sequentially, and quoted content within sentences is further segmented
    # and labeled alphabetically. The resulting text is formatted with numbered sentences and labeled
    # quoted content, maintaining the original paragraph structure.
    #
    # @param text [String] The input text to process and number.
    #
    # @return [String] The text with numbered sentences and labeled quoted content.
    #
    # @example Numbering sentences and quoted content:
    #   input = <<~TEXT
    #     This is the first paragraph. "This is a quoted sentence."
    #
    #     This is the second paragraph. "Another quote with multiple sentences. Here's the second."
    #   TEXT
    #
    #   Text.number_text(input)
    #   # => "**[1]** This is the first paragraph. \"**[2]** **[A]** This is a quoted sentence.\""
    #   #    "\n\n**[3]** This is the second paragraph. \"**[4]** **[A]** Another quote with multiple sentences. **[B]** Here's the second.\""
    #
    # @note
    #   - The method uses PragmaticSegmenter to split paragraphs into sentences.
    #   - Sentences are numbered sequentially across the entire text.
    #   - Quoted content is split into sub-sentences and labeled alphabetically (e.g., A, B, C).
    #   - The method preserves paragraph breaks in the output.
    #
    # @see PragmaticSegmenter::Segmenter
    def self.number_text(text)
      # Split the text into paragraphs by double newlines
      paragraphs = text.split(/\n\n+/)
      sentence_count = 0

      # Process each paragraph separately
      numbered_paragraphs = paragraphs.map do |paragraph|
        # Segment the paragraph into sentences
        ps = PragmaticSegmenter::Segmenter.new(text: paragraph)
        sentences = ps.segment

        # Process each sentence
        numbered_sentences = sentences.map do |sentence|
          # Increment sentence count for numbering
          sentence_count += 1
          sentence_label = "**[#{sentence_count}]**"

          # Find all quoted parts in the sentence
          quoted_parts = sentence.scan(/["“”](.+?)["“”]/).flatten
          if quoted_parts.any?
            # Process each quoted part
            labeled_sub_sentences = quoted_parts.map do |quoted_text|
              # Split quoted content into sub-sentences and label them alphabetically
              sub_sentences = PragmaticSegmenter::Segmenter.new(text: quoted_text).segment
              sub_sentences.each_with_index.map do |sub_sentence, index|
                "**[#{(index + 65).chr}]** #{sub_sentence.strip}" # A, B, C, etc.
              end.join(' ') # Join labeled sub-sentences for this quoted part
            end

            # Replace quoted content with labeled sub-sentences
            quoted_with_labels = quoted_parts.zip(labeled_sub_sentences).map do |original, labeled|
              sentence.gsub(/["“”]#{Regexp.escape(original)}["“”]/, "\"#{labeled}\"")
            end.first # Replace only the first quoted match

            # Return the sentence with main numbering and labeled sub-sentences
            "#{sentence_label} #{quoted_with_labels}"
          else
            # If no quoted content, just label the sentence
            "#{sentence_label} #{sentence.strip}"
          end
        end

        # Join the numbered sentences within the paragraph
        numbered_sentences.join(' ')
      end

      # Join the numbered paragraphs with double newlines
      numbered_paragraphs.join("\n\n")
    end

    # Extracts numbered list items from a given text.
    #
    # This method scans the input text for lines that match the pattern of a numbered list
    # (e.g., "1. Item"). It returns an array of all detected numbered list items. If no
    # matches are found, the method aborts with an error message.
    #
    # @param text [String] The input text to parse for numbered list items.
    #
    # @return [Array<String>] An array of strings representing the detected numbered list items.
    #
    # @example Parsing a numbered list from text:
    #   input = <<~TEXT
    #     1. First item
    #     2. Second item
    #     3. Third item
    #   TEXT
    #
    #   Text.parse_numbered_list(input)
    #   # => ["1. First item", "2. Second item", "3. Third item"]
    #
    # @example Handling text without numbered list items:
    #   input = "This text contains no numbered list."
    #   Text.parse_numbered_list(input)
    #   # => Aborts with message: "Error: failed to detect any enumerated items! Please review input content."
    #
    # @note
    #   - The method uses a regular expression (`/^\d+\.\s+.+$/`) to detect numbered list items.
    #   - If no matches are found, the method aborts execution with an error message.
    #   - The pattern requires each item to start with a number followed by a period and a space.
    #
    # @raise [Abort] If no numbered list items are detected in the input text.
    #
    # @see String#scan
    def self.parse_numbered_list(text)
      results = text.scan(/^\d+\.\s+.+$/)
      abort 'Error: failed to detect any enumerated items! Please review input content.' if results.empty?
      results
    end

    # Parses a formatted string into a hash of categories with titles and descriptions.
    #
    # This method processes a formatted string of categories, extracting each category's number,
    # title, and description. It returns a hash where the keys are category numbers and the values
    # are hashes containing the title and description of each category. If parsing fails, it logs
    # an error message and returns `nil`.
    #
    # @param text [String] The input text containing formatted categories.
    #   - Categories should be prefixed with `**<number>\.` and contain a title and description.
    #
    # @return [Hash{Integer => Hash{title: String, description: String}}]
    #   A hash where keys are category numbers and values are hashes with `:title` and `:description`.
    #   Returns `nil` if parsing fails.
    #
    # @example Parsing categories from a formatted string:
    #   input = <<~TEXT
    #     **1\\.** Category One ** Description of category one.
    #     **2\\.** Category Two ** Description of category two.
    #   TEXT
    #
    #   Text.parse_categories_str(input)
    #   # => {
    #   #      1 => { title: "Category One", description: "Description of category one." },
    #   #      2 => { title: "Category Two", description: "Description of category two." }
    #   #    }
    #
    # @example Handling invalid input:
    #   input = "This text does not follow the category format."
    #   Text.parse_categories_str(input)
    #   # => Logs error: "Error: failed to parse category text! Please review `GPTK::Text.parse_categories_str`."
    #   # => nil
    #
    # @note
    #   - Categories are expected to follow the pattern: `**<number>\.` followed by a title and description.
    #   - If no valid categories are detected, the method logs an error and returns `nil`.
    #   - The method uses regular expressions to extract category details.
    #
    # @raise [RuntimeError] If individual category parsing fails during iteration.
    #
    # @see String#split
    # @see Regexp
    def self.parse_categories_str(text)
      sorted_categories = text.split(/(?=\*\*\d+\\\.)/)
      if sorted_categories.size == 1
        puts 'Error: failed to parse category text! Please review `GPTK::Text.parse_categories_str`.'
        return nil
      end
      sorted_categories.reduce({}) do |output, category|
        if category =~ /\*\*(\d+)\\\.\s*(.*?)\*\*\s*(.*)/m
          number = $1.to_i
          title = $2.strip
          description = $3.strip
          output[number] = { title: title, description: description }
        else
          puts 'Error: parsing categories failed!'
          nil
        end
        output
      end
    end

    # Parses text containing numbered categories and subpoints into a structured hash.
    #
    # This method processes a text input with numbered categories and subpoints, organizing the data
    # into a hash. Each category title is a key, and its associated subpoints are stored as an array
    # of strings. Additional lines following a subpoint are appended to that subpoint.
    #
    # @param text [String] The input text to parse, containing numbered categories and subpoints.
    #
    # @return [Hash{String => Array<String>}]
    #   A hash where the keys are category titles (e.g., "#1: Title") and the values are arrays of
    #   subpoints associated with each category.
    #
    # @example Parsing categories and subpoints:
    #   input = <<~TEXT
    #     #1: Category One
    #     1. First subpoint of category one
    #     2. Second subpoint of category one
    #
    #     #2: Category Two
    #     1. First subpoint of category two
    #     Additional details for the first subpoint.
    #   TEXT
    #
    #   Text.parse_numbered_categories(input)
    #   # => {
    #   #      "#1: Category One" => ["First subpoint of category one", "Second subpoint of category one"],
    #   #      "#2: Category Two" => ["First subpoint of category two Additional details for the first subpoint."]
    #   #    }
    #
    # @example Handling text without categories or subpoints:
    #   input = "This text does not follow the numbered category format."
    #   Text.parse_numbered_categories(input)
    #   # => {}
    #
    # @note
    #   - Titles are identified by the pattern `#<number>: Title`.
    #   - Subpoints are identified by the pattern `<number>. Subpoint text`.
    #   - Additional lines following a subpoint are appended to the last subpoint.
    #   - If no valid categories or subpoints are found, the method returns an empty hash.
    #
    # @see String#each_line
    # @see Regexp
    def self.parse_numbered_categories(text)
      result = {}
      current_title = nil

      # Regex for matching numbered titles (e.g., #1: “Title”)
      title_regex = /^#\d+:\s*.+$/
      # Regex for matching numbered subpoints (e.g., 1. Subpoint text)
      subpoint_regex = /^(\d+)\.\s+(.+)$/

      text.each_line do |line|
        line.strip!
        next if line.empty?

        if line.match?(title_regex)
          # Match a new title
          current_title = line
          result[current_title] = []
        elsif (match = line.match(subpoint_regex))
          # Match a new subpoint
          result[current_title] << match[2].strip if current_title
        elsif current_title && result[current_title].any?
          # Append additional lines to the last subpoint
          result[current_title][-1] += " #{line}" if result[current_title][-1]
        end
      end

      result
    end

    # Formats and prints a list of matches with details such as pattern, sentence, and revisions.
    #
    # This method generates a formatted string containing details of matches, including their
    # pattern, sentence number, matched text, original sentence, and revised sentence. If a pattern
    # is included in the first match, it is added as a header in the output.
    #
    # @param matches [Array<Hash>] A list of match details, where each hash includes:
    #   - `:pattern` [String, nil] (optional) The pattern used to generate the match.
    #   - `:sentence_count` [Integer] The number of the sentence in the text.
    #   - `:match` [String] The matched text.
    #   - `:sentence` [String] The original sentence containing the match.
    #   - `:revised` [String] The revised sentence after applying changes.
    #
    # @return [String] A formatted string containing match details.
    #
    # @example Printing matches:
    #   matches = [
    #     {
    #       pattern: "Example Pattern",
    #       sentence_count: 1,
    #       match: "matched text",
    #       sentence: "This is the original sentence with matched text.",
    #       revised: "This is the revised sentence."
    #     }
    #   ]
    #   puts Text.print_matches(matches)
    #   # =>
    #   # ## Example Pattern (1 matches)
    #   #
    #   # ***MATCH 1***:
    #   #
    #   # - `Sentence number: 1`
    #   # - **Match:** matched text
    #   # - **Original sentence:** This is the original sentence with matched text.
    #   #
    #   # > **Revised sentence:** This is the revised sentence.
    #
    # @example Handling matches without a pattern:
    #   matches = [
    #     {
    #       sentence_count: 2,
    #       match: "another match",
    #       sentence: "Another sentence with a match.",
    #       revised: "Another revised sentence."
    #     }
    #   ]
    #   puts Text.print_matches(matches)
    #   # =>
    #   # ***MATCH 1***:
    #   #
    #   # - `Sentence number: 2`
    #   # - **Match:** another match
    #   # - **Original sentence:** Another sentence with a match.
    #   #
    #   # > **Revised sentence:** Another revised sentence.
    #
    # @note
    #   - The `:pattern` key is optional and only included in the header if present in the first match.
    #   - The method appends details for each match sequentially, including sentence count, match text,
    #     original sentence, and revised sentence.
    #
    # @raise [ArgumentError] If the `matches` array is empty or does not contain valid match details.
    #
    # @see Array#each_with_index
    # @see String#<<
    def self.print_matches(matches)
      str = if matches.first.key? :pattern
              "\n## #{matches.first[:pattern]} (#{matches.count} matches)\n\n"
            else
              ''
            end

      matches.each_with_index do |match, i|
        str << "***MATCH #{i + 1}***:\n\n"
        str << "- `Sentence number: #{match[:sentence_count]}`\n"
        str << "- **Match:** #{match[:match]}\n"
        str << "- **Original sentence:** #{match[:sentence]}\n"
        str << "\n\n> **Revised sentence:** #{match[:revised]}\n"
        str << "\n"
      end
      str
    end
  end
end