module GPTK
  module Utils
    def self.symbolify_keys(hash)
      raise ArgumentError, 'Input must be a hash' unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), new_hash|
        # Convert string keys to symbols, leave other key types as-is
        new_key = key.is_a?(String) ? key.to_sym : key
        # Recursively apply to nested hashes
        new_value = value.is_a?(Hash) ? symbolify_keys!(value) : value
        new_hash[new_key] = new_value
      end
    end
  end
end