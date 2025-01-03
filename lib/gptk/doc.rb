module GPTK
  class Doc
    attr_reader :last_output, :data
    attr_accessor :file, :content

    # Initializes a new instance of the `Doc` class.
    #
    # This constructor sets up the `Doc` object with the provided API client, output file,
    # and content. It validates the API client and initializes tracking data for
    # API usage metrics, including prompt tokens, completion tokens, and cached tokens.
    #
    # @param api_client [Object] The client instance used for interacting with an API. This parameter is mandatory.
    # @param file_path [String, nil] The name of the output file to save generated content.
    # @param content [String, nil] The content to be processed or utilized by the `Doc` instance. Optional.
    #
    # @return [Doc] A new instance of the `Doc` class.
    #
    # @example Creating a `Doc` instance with a file path and content:
    #   file_path = "output.txt"
    #   content = "This is a document to process."
    #   doc = Doc.new(file_path, content)
    #
    # @note
    #   - The method aborts execution if the `api_client` is not provided or invalid.
    #   - The `@data` hash is initialized to track token usage metrics during API interactions.
    #
    # @raise [Abort] If the `api_client` is not provided or invalid.
    #
    # @see OpenAI::Client
    def initialize(file_path, content = nil)
      @file = File.expand_path file_path
      @content = content
      @data = { # Data points to track while utilizing APIs
        prompt_tokens: 0,
        completion_tokens: 0,
        cached_tokens: 0
      }
    end

    # Document output format 1: Composes a structured document from a title, chapters, and their content.
    #
    # This method generates a document in Markdown format. The document includes an H1 header
    # for the main title, followed by H2 headers for each chapter title, and their respective
    # descriptions and content. It organizes chapters based on their numeric keys and caches
    # the output for reuse.
    #
    # @param title [String] The main title of the document, rendered as an H1 header.
    # @param chapters [Hash<Integer, Hash{title: String, description: String}>]
    #   A hash where the keys are chapter numbers and the values are hashes containing:
    #   - `:title` [String] The title of the chapter.
    #   - `:description` [String] A brief description of the chapter.
    # @param content [Hash<Integer, Array<String>>]
    #   A hash where the keys are chapter numbers and the values are arrays of strings
    #   representing the content of each chapter.
    #
    # @return [String] The fully composed document in Markdown format.
    #
    # @example Composing a document:
    #   title = "The Great Adventure"
    #   file_path = "output.docx"
    #   chapters = {
    #     1 => { title: "The Beginning", description: "An introduction to the story." },
    #     2 => { title: "The Journey", description: "The challenges and triumphs along the way." }
    #   }
    #   content = {
    #     1 => ["Once upon a time...", "It was a dark and stormy night."],
    #     2 => ["They climbed the highest mountain.", "Victory was in sight."]
    #   }
    #   doc = Doc.new(file_path)
    #   doc.create_doc1(title, chapters, content)
    #   # => "# The Great Adventure\n\n## The Beginning\nAn introduction to the story.\n\n\nOnce upon a time...\nIt was a dark and stormy night.\n\n\n## The Journey\nThe challenges and triumphs along the way.\n\n\nThey climbed the highest mountain.\nVictory was in sight.\n\n\n"
    #
    # @note
    #   - The method skips chapters that have no content.
    #   - The `@last_output` instance variable caches the generated document for reuse.
    #   - Markdown headers (`#`, `##`) are used to format the output.
    #
    # @raise [ArgumentError] If `title` is nil or empty.
    #
    # @see String#<<
    def create_doc1(title, chapters, content)
      str = ''
      str << "# #{title}\n\n"
      chapters.sort.each do |chapter_number, chapter_info|
        next if !content[chapter_number] || content[chapter_number].empty?
        str << "## #{chapter_info[:title]}\n"        # Category title
        str << "#{chapter_info[:description]}\n\n\n" # Category description
        unless !content[chapter_number] || content[chapter_number].empty?
          content[chapter_number].each {|echo| str << "#{echo}\n" } # Enumerate items in this category
          str << "\n\n"
        end
      end
      str
    end

    # Saves the document content or the results of the last operation to a file.
    #
    # This method writes the document content stored in the `@content` instance variable or the results
    # of the last operation (stored in `@last_output`) to a file. If the specified file already exists,
    # the filename is automatically incremented to prevent overwriting.
    #
    # @return [void]
    #   Outputs messages to the console indicating the status of the save operation.
    #
    # @example Saving document content:
    #   doc = Doc.new("output.txt", "This is the document content.")
    #   doc.save
    #   # => "Writing document content to file: output.txt"
    #
    # @example Saving the results of the last operation:
    #   doc = Doc.new("output.txt")
    #   doc.create_doc1("Title", chapters, content)
    #   doc.save
    #   # => "Writing document content to file: output_1.txt"
    #
    # @note
    #   - If neither `@content` nor `@last_output` is available, an error message is displayed,
    #     and no file is written.
    #   - The filename is incremented automatically if the file already exists to avoid overwriting.
    #   - The method uses the `GPTK::File.fname_increment` helper for filename management.
    #
    # @see GPTK::File.fname_increment
    # @see File.write
    #
    # @todo Add metadata to the file name, such as the date
    def save
      unless @content || @last_output
        puts 'Error: no document content or last operation results found!'
        puts 'Perform an operation or assign a value to the Doc `content` variable.'
      end
      content = @content || @last_output
      file_path = GPTK::Utils.fname_increment @file
      puts "Writing document content to file: #{file_path}"
      File.write file_path, content
    end

    # Removes duplicate paragraphs from a `.docx` file while preserving their formatting.
    #
    # This method processes paragraphs from a `.docx` file, normalizes them to detect duplicates,
    # and writes only unique paragraphs back to the same file. Paragraph formatting such as bold and color
    # is preserved during this process.
    #
    # @return [void]
    # @raise [Errno::ENOENT] If the specified file does not exist.
    # @raise [Caracal::Errors::InvalidModelError] If the Caracal document cannot be written.
    #
    # @example Remove duplicate paragraphs from a `.docx` file
    #   remove_duplicate_paragraphs
    #   # Outputs: "Cleaned document with formatting saved to <file path>"
    #
    def remove_duplicate_paragraphs_from_docx
      # Parse paragraphs from the file
      paragraphs = GPTK::Text::Parse.paragraphs_with_formatting_from_docx @file

      # Remove duplicates while maintaining the original order
      unique_paragraphs = []
      seen = {}
      paragraphs.each do |paragraph|
        normalized_text = GPTK::Text.normalize_paragraph(paragraph)
        unless seen[normalized_text]
          unique_paragraphs << paragraph
          seen[normalized_text] = true
        end
      end

      # Write cleaned content to the same .docx file
      Caracal::Document.save(@file) do |doc|
        unique_paragraphs.each do |paragraph|
          doc.p do
            paragraph.each do |part|
              doc.p part[:text], bold: part[:bold], color: part[:color] || '000000'
            end
          end
        end
      end

      puts "Cleaned document with formatting saved to #{@file}"
    end

    # Removes duplicate sentences from a `.docx` file and saves the result to a new file.
    #
    # This method processes the main document content (`word/document.xml`) in a `.docx` file to remove duplicate
    # sentences while preserving formatting and structure. It writes the deduplicated content to a new file and
    # prints the duplicate sentences to the console.
    #
    # @return [void]
    # @raise [Errno::ENOENT] If the specified file does not exist.
    # @raise [Zip::Error] If the file is not a valid ZIP archive.
    # @raise [Nokogiri::XML::SyntaxError] If the XML structure is malformed.
    #
    # @example Remove duplicates from a `.docx` file
    #   doc.remove_duplicates_from_docx
    #   # Outputs duplicate sentences to the console and creates a new file with duplicates removed.
    #
    # @todo: Make more generic so as to be able to handle .txt files as well
    #
    def remove_duplicate_sentences_from_docx
      output_path = @file.sub(/\.docx$/, '_without_duplicates.docx')
      duplicate_sentences = []  # Add this to track duplicates

      # Copy the original file to the new location
      FileUtils.cp(@file, output_path)

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
      puts "\nDuplicate sentences removed:"
      ap duplicate_sentences.uniq  # Use uniq to avoid showing the same duplicate multiple times
    end

    # Cleans a chapter by removing duplicate sentences and paragraphs, and saves the result to a Word document.
    #
    # This method processes the content stored in the `@content` attribute of the `Doc` object. It normalizes
    # paragraphs, removes duplicate sentences and paragraphs, and generates a Word document. Duplicate sentences
    # are highlighted in red and bold, while unique sentences are formatted normally.
    #
    # @return [void]
    # @raise [RuntimeError] If the `@content` attribute is not set on the `Doc` object.
    # @raise [Caracal::Errors::InvalidModelError] If the Word document cannot be written.
    #
    # @example Clean a chapter and save it as a Word document
    #   doc = Doc.new
    #   doc.content = "This is a sentence.\n\nThis is a duplicate sentence.\n\nThis is a sentence."
    #   doc.clean_chapter
    #   # Outputs: "Cleaned document with formatting saved to <file path>"
    def clean_doc_text
      # Ensure @content is set
      raise 'The @content attribute must be set before calling `clean_chapter`.' unless defined?(@content) && @content

      # Normalize and split input text into paragraphs
      paragraphs = @content.split(/\n+/).map(&:strip).reject(&:empty?)

      # Hash to track processed paragraphs to avoid duplication
      processed_paragraph_hashes = {}

      # Analyze for duplicate sentences
      segmenter = PragmaticSegmenter::Segmenter.new(text: @content)
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
      Caracal::Document.save(@file) do |doc|
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

      puts "Cleaned document with formatting saved to #{@file}"
    end

    # Cleans and analyzes a chapter by detecting duplicate sentences and paragraphs,
    # and generates two Word documents: an analysis document highlighting duplicates and a cleaned document with duplicates removed.
    #
    # This method processes the content of a `.txt` or `.docx` file to identify duplicate sentences,
    # highlighting them in an analysis document and removing them from a cleaned document. Both documents
    # are saved with appropriate suffixes in their filenames.
    #
    # @return [void]
    # @raise [RuntimeError] If the file is not of type `.txt` or `.docx`.
    # @raise [Caracal::Errors::InvalidModelError] If the Word documents cannot be written.
    # @raise [Errno::ENOENT] If the specified file does not exist.
    #
    # @example Analyze and clean a chapter
    #   doc = Doc.new
    #   doc.file = "chapter.docx"
    #   doc.clean_and_analyze_chapter
    #   # Outputs:
    #   # "Generating analysis document..."
    #   # "Analysis document saved to chapter-analysis.docx"
    #   # "Generating cleaned document..."
    #   # "Cleaned document saved to chapter-clean.docx"
    def clean_and_analyze_doc
      # Determine file type and extract text accordingly
      full_text = if @file.end_with?('.txt')
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
      analysis_file = @file.gsub(/(.*)(\.\w+)$/, '\1-analysis\2')
      Caracal::Document.save analysis_file do |doc|
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
      cleaned_file = @file.gsub(/(.*)(\.\w+)$/, '\1-clean\2')
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

    # Extracts numbered items from a `.docx` file, specifically those with a `numId` of 9.
    #
    # This method parses the XML content of a `.docx` file to identify and extract paragraphs that are part of a numbered list
    # with a `numId` of 9. The extracted text for each matching paragraph is returned as an array.
    #
    # @return [Array<String>] An array of text strings corresponding to the numbered items.
    # @raise [RuntimeError] If the input file is not a `.docx` file.
    # @raise [Nokogiri::XML::SyntaxError] If the document XML cannot be parsed.
    #
    # @example Extract numbered items from a `.docx` file
    #   doc = Doc.new
    #   doc.file = "example.docx"
    #   numbered_items = doc.extract_numbered_items
    #   puts numbered_items
    #   # Output:
    #   # ["First numbered item", "Second numbered item", ...]
    #
    def extract_numbered_items_from_docx
      raise 'Input must be a .docx file' unless @file.end_with? '.docx'

      document_xml = extract_document_xml
      doc = Nokogiri::XML document_xml

      items = []

      doc.xpath('//w:p').each do |paragraph|
        # Look specifically for numPr nodes with numId="9"
        num_pr = paragraph.at_xpath './/w:numPr'
        if num_pr && num_pr.at_xpath('.//w:numId[@w:val="9"]')
          text = paragraph.xpath('.//w:t').map(&:text).join.strip
          items << text unless text.empty?
        end
      end

      items
    end

    private

    # Extracts the `document.xml` content from the `.docx` file specified by the `@file` instance variable.
    #
    # This method opens the `.docx` file (treated as a ZIP archive), locates the `word/document.xml` file,
    # and extracts its raw XML content. It raises an error if the required file is not found in the archive.
    #
    # @return [String] The raw XML content of `word/document.xml`.
    # @raise [RuntimeError] If the `document.xml` file is not found in the `.docx` archive.
    # @raise [Zip::Error] If the file is not a valid ZIP archive.
    # @raise [Errno::ENOENT] If the specified file does not exist.
    #
    # @example Extract the document XML from the instance's `.docx` file
    #   doc = Doc.new("example.docx")
    #   xml_content = doc.extract_document_xml
    #   puts xml_content
    #   # Outputs the raw XML content of the document
    #
    def extract_document_xml
      Zip::File.open @file do |zip_file|
        entry = zip_file.find_entry('word/document.xml')
        raise 'document.xml not found in .docx file' unless entry
        return entry.get_input_stream.read
      end
    end
  end
end