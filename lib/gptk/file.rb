module GPTK
  module File
    # Increment a filename programmatically
    def self.fname_increment(filename)
      if !File.exist? filename
        filename
      else
        /([0-9]+)\./.match(filename) ?
          fname_increment(filename.sub(/([0-9]+)/) { |m| (m.to_i + 1).to_s }) :
          fname_increment(filename.sub(/[^\.]*/) { |m| m + '1' })
      end
    end

    def self.load_file_content(file_path)
      File.read File.expand_path(file_path, __dir__)
    end
  end
end
