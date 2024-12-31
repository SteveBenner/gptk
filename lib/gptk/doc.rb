module GPTK
  class Doc
    attr_reader :last_output, :data
    attr_accessor :client, :output_file, :content

    # Initializes a new instance of the `Doc` class.
    #
    # This constructor sets up the `Doc` object with the provided API client, output file,
    # and content. It validates the API client and initializes tracking data for
    # API usage metrics, including prompt tokens, completion tokens, and cached tokens.
    #
    # @param api_client [Object] The client instance used for interacting with an API. This parameter is mandatory.
    # @param output_file [String, nil] The name of the output file to save generated content. Defaults to an empty string.
    # @param content [String, nil] The content to be processed or utilized by the `Doc` instance. Optional.
    #
    # @return [Doc] A new instance of the `Doc` class.
    #
    # @example Creating a `Doc` instance with an API client:
    #   api_client = OpenAI::Client.new(api_key: "your_api_key")
    #   output_file = "output.txt"
    #   content = "This is a document to process."
    #   doc = Doc.new(api_client, output_file, content)
    #
    # @note
    #   - The method aborts execution if the `api_client` is not provided or invalid.
    #   - The `@data` hash is initialized to track token usage metrics during API interactions.
    #
    # @raise [Abort] If the `api_client` is not provided or invalid.
    #
    # @see OpenAI::Client
    def initialize(api_client, output_file=nil, content=nil)
      abort 'Error: invalid client!' unless api_client
      @client = api_client
      @output_file = output_file || ''
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
    #   chapters = {
    #     1 => { title: "The Beginning", description: "An introduction to the story." },
    #     2 => { title: "The Journey", description: "The challenges and triumphs along the way." }
    #   }
    #   content = {
    #     1 => ["Once upon a time...", "It was a dark and stormy night."],
    #     2 => ["They climbed the highest mountain.", "Victory was in sight."]
    #   }
    #   doc = Doc.new(api_client)
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
      @last_output = str # Cache results of the operation
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
    #   doc = Doc.new(api_client, "output.txt", "This is the document content.")
    #   doc.save
    #   # => "Writing document content to file: output.txt"
    #
    # @example Saving the results of the last operation:
    #   doc = Doc.new(api_client, "output.txt")
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
      filepath = ::File.exist?(@output_file) ? GPTK::File.fname_increment(@output_file) : @output_file
      content = @content || @last_output
      puts "Writing document content to file: #{filepath}"
      ::File.write filepath, content
    end
  end
end