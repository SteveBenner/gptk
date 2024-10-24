module GPTK
  class Doc
    attr_reader :client, :input, :output_file, :content
    attr_accessor :last_output

    def initialize(api_client, output_file=nil, content=nil)
      abort 'Error: invalid client!' unless api_client
      @client = api_client
      @output_file = output_file
      @content = content
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