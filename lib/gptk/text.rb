Bundler.require :text
require 'rubygems'
require 'zip'

module GPTK
  module Text
    module Parse
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
      #   Text::Parse.categories_str(input)
      #   # => {
      #   #      1 => { title: "Category One", description: "Description of category one." },
      #   #      2 => { title: "Category Two", description: "Description of category two." }
      #   #    }
      #
      # @example Handling invalid input:
      #   input = "This text does not follow the category format."
      #   Text::Parse.categories_str(input)
      #   # => Logs error: "Error: failed to parse category text! Please review `GPTK::Text::Parse.categories_str`."
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
      def self.categories_str(text)
        sorted_categories = text.split(/(?=\*\*\d+\\\.)/)
        if sorted_categories.size == 1
          puts 'Error: failed to parse category text! Please review `GPTK::Text::Parse.categories_str`.'
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
      #   Text::Parse.numbered_categories(input)
      #   # => {
      #   #      "#1: Category One" => ["First subpoint of category one", "Second subpoint of category one"],
      #   #      "#2: Category Two" => ["First subpoint of category two Additional details for the first subpoint."]
      #   #    }
      #
      # @example Handling text without categories or subpoints:
      #   input = "This text does not follow the numbered category format."
      #   Text::Parse.numbered_categories(input)
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
      def self.numbered_categories(text)
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

      # Extracts paragraphs from a `.docx` file.
      #
      # This method reads a `.docx` file (treated as a ZIP archive), extracts the main document XML (`word/document.xml`),
      # and parses the paragraphs enclosed within `<w:p>` tags. Text within these paragraphs is extracted from `<w:t>` tags.
      #
      # @param [String] file_path The path to the `.docx` file.
      # @return [Array<String>] An array of paragraphs, with each paragraph as a string. Empty paragraphs are excluded.
      # @raise [Zip::Error] If the file is not a valid ZIP archive.
      # @raise [Errno::ENOENT] If the specified file does not exist.
      # @raise [Nokogiri::XML::SyntaxError] If the XML structure is malformed.
      #
      # @example Extract paragraphs from a `.docx` file
      #   paragraphs = self.paragraphs_from_docx("example.docx")
      #   paragraphs.each { |para| puts para }
      #
      def self.paragraphs_from_docx(file_path)
        paragraphs = []

        # Open the .docx file as a zip archive
        Zip::File.open(file_path) do |zip_file|
          entry = zip_file.find_entry('word/document.xml')
          if entry
            xml_content = entry.get_input_stream.read

            # Extract paragraphs based on XML structure
            # Paragraphs are enclosed within `<w:p>` tags
            xml_content.scan(/<w:p.*?>(.*?)<\/w:p>/m).each do |match|
              paragraph_content = match[0].scan(/<w:t.*?>(.*?)<\/w:t>/).flatten.join(' ')
              paragraphs << paragraph_content.strip unless paragraph_content.empty?
            end
          end
        end

        paragraphs
      end

      # Extracts paragraphs with formatting information from a `.docx` file.
      #
      # This method reads a `.docx` file (treated as a ZIP archive), extracts the main document XML (`word/document.xml`),
      # and parses paragraphs enclosed within `<w:p>` tags. For each paragraph, it extracts text along with formatting
      # attributes such as bold and color from `<w:r>` (run) tags.
      #
      # @param [String] file_path The path to the `.docx` file.
      # @return [Array<Array<Hash>>] An array of paragraphs, where each paragraph is an array of hashes.
      #   Each hash contains the text and its formatting attributes:
      #   - `:text` [String] The text content.
      #   - `:bold` [Boolean] Whether the text is bold.
      #   - `:color` [String, nil] The color of the text (hexadecimal or OpenXML color name), or `nil` if not specified.
      # @raise [Zip::Error] If the file is not a valid ZIP archive.
      # @raise [Errno::ENOENT] If the specified file does not exist.
      # @raise [Nokogiri::XML::SyntaxError] If the XML structure is malformed.
      #
      # @example Extract paragraphs with formatting from a `.docx` file
      #   paragraphs = self.paragraphs_with_formatting_from_docx("example.docx")
      #   paragraphs.each do |paragraph|
      #     paragraph.each do |text|
      #       puts "Text: #{text[:text]}, Bold: #{text[:bold]}, Color: #{text[:color]}"
      #     end
      #   end
      #
      def self.paragraphs_with_formatting_from_docx(file_path)
        paragraphs = []

        # Open the .docx file as a zip archive
        Zip::File.open(file_path) do |zip_file|
          entry = zip_file.find_entry('word/document.xml')
          if entry
            xml_content = entry.get_input_stream.read
            doc = Nokogiri::XML(xml_content)

            # Extract paragraphs with formatting
            doc.xpath('//w:p').each do |paragraph|
              formatted_texts = paragraph.xpath('.//w:r').map do |run|
                text = run.at_xpath('.//w:t')&.text
                next unless text

                bold = run.at_xpath('.//w:b') ? true : false
                color = run.at_xpath('.//w:color')&.[]('w:val')
                { text: text.strip, bold: bold, color: color } # Normalize text
              end

              # Combine all the formatted text in the paragraph
              formatted_texts.compact!
              paragraphs << formatted_texts unless formatted_texts.empty?
            end
          end
        end

        paragraphs
      end
    end

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

    # Normalizes a paragraph by combining its parts into a single, lowercased string with extra spaces removed.
    #
    # This method processes a paragraph, which is represented as an array of hashes where each hash contains
    # text and potentially other formatting attributes. It extracts the text from each part, removes extra spaces,
    # joins the parts into a single string, and converts it to lowercase.
    #
    # @param [Array<Hash>] paragraph An array of hashes representing parts of a paragraph. Each hash must include:
    #   - `:text` [String] The text content of the part.
    # @return [String] A single, normalized string representing the entire paragraph.
    #
    # @example Normalize a paragraph
    #   paragraph = [
    #     { text: " This is the first part " },
    #     { text: "of the paragraph." }
    #   ]
    #   normalized = self.normalize_paragraph(paragraph)
    #   puts normalized
    #   # Output: "this is the first part of the paragraph."
    #
    def self.normalize_paragraph(paragraph)
      paragraph.map { |part| part[:text].gsub(/\s+/, ' ').strip }.join(' ').downcase
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
    #   Text.numberize_sentences(input)
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
    #
    def self.numberize_sentences(text)
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