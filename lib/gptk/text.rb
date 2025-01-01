Bundler.require :text
require 'rubygems'
require 'zip'

module GPTK
  module Text
    # todo: refactor lib
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
      def self.categories_str(text)
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

      def self.parse_paragraphs_with_formatting(file_path)
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

    # Utility methods

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

    # Output methods

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

    def self.remove_duplicate_paragraphs(input_file, output_file)
      # Parse paragraphs from the input file
      paragraphs = parse_paragraphs_with_formatting(input_file)

      # Remove duplicates while maintaining the original order
      unique_paragraphs = []
      seen = {}
      paragraphs.each do |paragraph|
        normalized_text = normalize_paragraph(paragraph)
        unless seen[normalized_text]
          unique_paragraphs << paragraph
          seen[normalized_text] = true
        end
      end

      # Write cleaned content to a new .docx file
      Caracal::Document.save(output_file) do |doc|
        unique_paragraphs.each do |paragraph|
          doc.p do
            paragraph.each do |part|
              doc.p part[:text], bold: part[:bold], color: part[:color] || '000000'
            end
          end
        end
      end

      puts "Cleaned document with formatting saved to #{output_file}"
    end

    def self.clean_chapter_text(input_text, output_filename)
      # Normalize and split input text into paragraphs
      paragraphs = input_text.split(/\n+/).map(&:strip).reject(&:empty?)

      # Hash to track processed paragraphs to avoid duplication
      processed_paragraph_hashes = {}

      # Analyze for duplicate sentences
      segmenter = PragmaticSegmenter::Segmenter.new(text: input_text)
      sentences = segmenter.segment

      # Use a hash to detect duplicate sentences
      sentence_hashes = {}
      duplicates = {}

      sentences.each do |sentence|
        normalized_sentence = sentence.strip.downcase
        hash = Digest::SHA256.hexdigest(normalized_sentence)
        if sentence_hashes.key?(hash)
          duplicates[sentence] = true
        else
          sentence_hashes[hash] = true
        end
      end

      # Generate the Word document with formatting
      Caracal::Document.save(output_filename) do |doc|
        paragraphs.each do |paragraph|
          # Compute a hash of the normalized paragraph for deduplication
          paragraph_hash = Digest::SHA256.hexdigest(paragraph.strip.downcase)

          # Skip if paragraph is already processed
          next if processed_paragraph_hashes.key?(paragraph_hash)

          # Mark paragraph as processed
          processed_paragraph_hashes[paragraph_hash] = true

          # Process each paragraph
          segmenter = PragmaticSegmenter::Segmenter.new(text: paragraph)
          paragraph_sentences = segmenter.segment

          # Add the paragraph to the document
          doc.p do
            paragraph_sentences.each do |sentence|
              if duplicates[sentence]
                doc.p "#{sentence} ", color: 'FF0000', bold: true
              else
                doc.p "#{sentence} ", color: '000000'
              end
            end
          end
        end
      end

      puts "Cleaned document with formatting saved to #{::File.expand_path output_filename}"
    end

    def self.clean_and_analyze_chapter(input_file, analysis_file, cleaned_file)
      # Determine file type and extract text accordingly
      full_text = if input_file.end_with?('.txt')
                    File.read(input_file)
                  elsif input_file.end_with?('.docx')
                    doc = Docx::Document.open(input_file)
                    doc.paragraphs.map(&:text).join("\n")
                  else
                    raise "Unsupported file type. Please provide a .txt or .docx file."
                  end

      # Split content into sentences using Pragmatic Segmenter
      segmenter = PragmaticSegmenter::Segmenter.new(text: full_text)
      sentences = segmenter.segment

      # Identify duplicate sentences
      sentence_count = Hash.new(0)
      sentences.each { |sentence| sentence_count[sentence.strip] += 1 }
      duplicates = sentence_count.select { |_sentence, count| count > 1 }.keys

      # Generate analysis file with duplicates highlighted
      puts 'Generating analysis document...'
      Caracal::Document.save(analysis_file) do |doc|
        sentences.each do |sentence|
          if duplicates.include?(sentence.strip)
            doc.p sentence.strip, color: 'FF0000', bold: true, font: 'Times New Roman', underline: false
          else
            doc.p sentence.strip, font: 'Times New Roman', underline: false
          end
        end
      end
      puts "Cleaned document with formatting saved to #{analysis_file}"

      # Generate cleaned file with duplicates removed
      puts 'Generating cleaned document...'
      Caracal::Document.save(cleaned_file) do |doc|
        seen_sentences = {}

        sentences.each do |sentence|
          clean_sentence = sentence.strip
          unless seen_sentences.include?(clean_sentence)
            doc.p clean_sentence, font: 'Times New Roman', underline: false
            seen_sentences[clean_sentence] = true
          end
        end
      end

      puts "Cleaned document saved to #{cleaned_file}"
    end

    def self.remove_duplicates_from_docx(input_path)
      output_path = input_path.sub(/\.docx$/, '_no_duplicates.docx')
      duplicate_sentences = []  # Add this to track duplicates

      # Copy the original file to the new location
      FileUtils.cp(input_path, output_path)

      Zip::File.open(output_path) do |zip_file|
        # Read the main document content
        doc_entry = zip_file.find_entry('word/document.xml')
        doc_content = doc_entry.get_input_stream.read

        # Parse the XML
        doc = Nokogiri::XML(doc_content)

        # Get all paragraphs
        paragraphs = doc.xpath('//w:p')

        # Process paragraphs to remove duplicates
        seen_sentences = Set.new
        paragraphs.each do |para|
          # Extract text from paragraph while preserving formatting nodes
          text_nodes = para.xpath('.//w:t')
          full_text = text_nodes.map(&:text).join

          # Split into sentences
          sentences = full_text.split(/(?<=[.!?])\s+/)

          # Filter out duplicate sentences
          unique_sentences = sentences.reject do |sentence|
            sentence = sentence.strip.downcase
            next if sentence.empty?
            if seen_sentences.include?(sentence)
              duplicate_sentences << sentence  # Add this to track duplicates
              true
            else
              seen_sentences.add(sentence)
              false
            end
          end

          # Skip empty paragraphs
          next if unique_sentences.empty?

          # Update the first text node with all unique content
          if text_nodes.any?
            text_nodes.first.content = unique_sentences.join(' ')
            # Remove any additional text nodes
            text_nodes[1..-1].each(&:remove)
          end
        end

        # Write the modified content back to the zip file
        zip_file.get_output_stream('word/document.xml') do |out|
          out.write(doc.to_xml)
        end
      end

      # Print duplicate sentences
      puts "\nDuplicate sentences found:"
      ap duplicate_sentences.uniq  # Use uniq to avoid showing the same duplicate multiple times

      output_path
    end

    def self.extract_numbered_items(docx_path)
      raise 'Input must be a .docx file' unless docx_path.end_with?('.docx')

      document_xml = GPTK::Doc.extract_document_xml(docx_path)
      doc = Nokogiri::XML(document_xml)

      items = []

      doc.xpath('//w:p').each do |paragraph|
        # Look specifically for numPr nodes with numId="9"
        num_pr = paragraph.at_xpath('.//w:numPr')
        if num_pr && num_pr.at_xpath('.//w:numId[@w:val="9"]')
          text = paragraph.xpath('.//w:t').map(&:text).join.strip
          items << text unless text.empty?
        end
      end

      items
    end

    private

    def self.normalize_paragraph(paragraph)
      paragraph.map { |part| part[:text].gsub(/\s+/, ' ').strip }.join(' ').downcase
    end
  end
end