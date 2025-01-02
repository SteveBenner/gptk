module GPTK
  module Utils
    # Recursively converts all string keys in a hash to symbols.
    #
    # This method processes a hash and replaces all string keys with their symbol equivalents.
    # It also applies the transformation recursively to any nested hashes. Keys that are not
    # strings are left unchanged.
    #
    # @param hash [Hash] The input hash to be processed.
    #
    # @return [Hash] A new hash with all string keys converted to symbols.
    #
    # @example Converting string keys to symbols:
    #   input = { "name" => "Alice", "details" => { "age" => 30, "location" => "Wonderland" } }
    #   Utils.symbolify_keys(input)
    #   # => { :name => "Alice", :details => { :age => 30, :location => "Wonderland" } }
    #
    # @note
    #   - This method does not modify the original hash. It creates and returns a new hash with
    #     the transformed keys.
    #   - The transformation is applied recursively to nested hashes.
    #   - Keys that are not strings remain unchanged.
    #
    # @raise [ArgumentError] If the input is not a hash.
    #
    # @see Hash#each_with_object
    #
    def self.symbolify_keys!(hash)
      raise ArgumentError, 'Input must be a hash' unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), new_hash|
        # Convert string keys to symbols, leave other key types as-is
        new_key = key.is_a?(String) ? key.to_sym : key
        # Recursively apply to nested hashes
        new_value = value.is_a?(Hash) ? symbolify_keys!(value) : value
        new_hash[new_key] = new_value
      end
    end

    # Programmatically increments a filename to avoid overwriting existing files.
    #
    # This method checks whether a given filename already exists. If it does, the method
    # modifies the filename by incrementing a numeric value in the filename or appending
    # "1" to the base name if no numeric value is present. The process is repeated
    # recursively until a non-existing filename is found.
    #
    # @param filename [String] The filename to check and potentially increment.
    #
    # @return [String] A unique filename that does not conflict with existing files.
    #
    # @example Incrementing a filename with an existing number:
    #   # Assuming "file1.txt" already exists:
    #   File.fname_increment("file1.txt")
    #   # => "file2.txt"
    #
    # @example Incrementing a filename without a number:
    #   # Assuming "file.txt" already exists:
    #   File.fname_increment("file.txt")
    #   # => "file1.txt"
    #
    # @example Handling filenames with multiple numeric segments:
    #   # Assuming "file1.2.txt" already exists:
    #   File.fname_increment("file1.2.txt")
    #   # => "file1.3.txt"
    #
    # @note
    #   - The method uses recursion to find a non-conflicting filename.
    #   - If the filename contains a number, it increments that number.
    #   - If the filename does not contain a number, "1" is appended to the base name.
    #
    # @see File.exist?
    # @see String#sub
    # @see Regexp#match
    #
    def self.fname_increment(filename)
      # Ensure the directory exists
      dir = File.dirname filename
      FileUtils.mkdir_p dir unless File.directory dir

      # Increment the filename if it exists
      if !File.exist? filename
        filename
      else
        /([0-9]+)\./.match(filename) ?
          fname_increment(filename.sub(/([0-9]+)/) { |m| (m.to_i + 1).to_s }) :
          fname_increment(filename.sub(/[^\.]*/) { |m| m + '1' })
      end
    end
  end
end