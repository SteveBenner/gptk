module GPTK
  module Text
    EXAMPLE_CATEGORY_TEXT = <<STRING
**1\. Consciousness & Self-Awareness**  
These MetaTations explore the nature of the mind, consciousness, and self-awareness. They challenge the reader to understand the complexity of the self, the mind’s relationship with the universe, and the experience of awareness. Examples include reflections on consciousness as a “Great Hall” and considerations of the internal versus external experiences of the mind.

**2\. Mindfulness & Presence**  
These MetaTations focus on the importance of being present and mindful in each moment. They guide the reader toward a deeper sense of presence, emphasizing the connection between breath, awareness, and the environment.

**3\. Philosophical Inquiry & Existential Reflection**  
A significant portion of MetaTations engage with deep philosophical questions and existential themes. These include reflections on meaning, identity, existence, time, and morality. Examples include questions about what constitutes reality and how we can perceive beyond the limits of human understanding.
STRING

    def self.word_count(text)
      text.split(/\s+/).count
    end

    def self.parse_numbered_list(text)
      results = text.scan(/^\d+\.\s+.+$/)
      abort 'Error: failed to detect any enumerated items! Please review input content.' if results.empty?
      results
    end

    # Parse an enumerated list of categories within a single String into structured data
    # @param text (String) category text
    # @return Hash<Integer => Hash<title: String, description: String>>
    def self.parse_categories(text)
      sorted_categories = text.split(/(?=\*\*\d+\.)/)
      sorted_categories.reduce({}) do |output, category|
        if category =~ /\*\*(\d+)\.\s*(.*?)\*\*\s*(.*)/m
          number = $1.to_i
          title = $2.strip
          description = $3.strip
          output[number] = { title: title, description: description }
        else abort 'Error: parsing categories failed!'
        end
        output
      end
    end
  end
end