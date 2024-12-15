require 'pragmatic_segmenter'

module GPTK
  module Text

    def self.word_count(text)
      text.split(/\s+/).count
    end

    def self.number_text(text)
      # First, split the text into paragraphs by double newlines
      paragraphs = text.split(/\n\n+/)
      sentence_count = 0

      # Process each paragraph separately
      numbered_paragraphs = paragraphs.map do |paragraph|
        # Segment each paragraph
        ps = PragmaticSegmenter::Segmenter.new text: paragraph
        sentences = ps.segment

        # Number the sentences within the paragraph, incrementing the global count
        numbered_sentences = sentences.map do |sentence|
          sentence_count += 1
          "**[#{sentence_count}]** #{sentence}"
        end

        # Join the sentences in the paragraph with single spaces
        numbered_sentences.join(' ')
      end

      # Join the paragraphs with double newlines
      numbered_paragraphs.join("\n\n")
    end

    def self.parse_numbered_list(text)
      results = text.scan(/^\d+\.\s+.+$/)
      abort 'Error: failed to detect any enumerated items! Please review input content.' if results.empty?
      results
    end

    # Parse an enumerated list of categories within a single String into structured data
    # @param text (String)`` category text
    # @return Hash<Integer => Hash<title: String, description: String>>
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

    def self.print_matches(matches)
      str = "\n## #{matches.first[:pattern]} (#{matches.count} matches)\n\n"
      matches.each_with_index do |match, i|
        str << "***MATCH #{i + 1}***:\n\n"
        str << "- `Sentence number: #{match[:sentence_count]}`\n"
        str << "- **Match:** #{match[:match]}\n"
        str << "- **Original sentence:** #{match[:original]}\n"
        str << "\n\n> **Revised sentence:** #{match[:revised]}\n"
        str << "\n"
      end
      str
    end
  end
end