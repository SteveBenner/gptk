module GPTK
  class Doc
    attr_reader :last_output, :data
    attr_accessor :client, :output_file, :content

    def initialize(api_client, output_file=nil, content=nil, mode=GPTK.mode)
      abort 'Error: invalid client!' unless api_client
      @client = api_client
      @output_file = output_file || ''
      @content = content
      @mode = mode
      @data = { # Data points to track while utilizing APIs
        prompt_tokens: 0,
        completion_tokens: 0,
        cached_tokens: 0
      }
    end

    # Document output format 1:
    # - Title
    #   - Chapter title
    #     - Chapter content
    # @param [String] title The document title, rendered as an H1 header
    # @param [Hash<Integer => Hash<title: String, description: String>>] chapters List of chapters
    # @param [Hash<Integer => Array<String>>] content Content (categorized by chapter)
    # @return [String] fully composed document
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

    # Save the current document content to file
    # todo: add metadata to filename, such as date
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

    # def submit_batch_file(file_path)
    #   puts "Submitting batch file: #{file_path}"
    #   response = @client.files.upload(parameters: { file: File.open(file_path, 'r'), purpose: 'batch' })
    #   response['id']
    # end

    # def monitor_batch_status(batch_id)
    #   puts "Monitoring batch: #{batch_id}"
    #   loop do
    #     response = @client.batches.retrieve(id: batch_id)
    #     status = response['status']
    #     if status == 'completed'
    #       puts "Batch #{batch_id} completed!"
    #       break
    #     elsif status == 'failed'
    #       puts "Batch #{batch_id} failed."
    #       break
    #     else
    #       puts "Batch #{batch_id} is still processing..."
    #     end
    #     sleep(30) # Check every 30 seconds
    #   end
    # end

    # def fetch_batch_results(batch_id)
    #   response = @client.batches.retrieve(id: batch_id)
    #   response['output_file_id']
    # end
  end
end