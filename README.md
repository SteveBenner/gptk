# GPTK: Generative Prompt Toolkit

# todo:
- walk them through setting up an AI platform account
- mention that it's plug-n-play but each have their own requirements
- add client initialization code
- add ROADMAP.md
- emphasize in intro that it's for LONG-form (the groundbreaking part of this)

A powerful and modular library for AI-driven text and book generation, revision, and analysis. With GPTK, you can seamlessly integrate AI tools such as ChatGPT, Claude, Grok, and Gemini for crafting narratives, revising text, and managing content generation workflows.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Dependencies](#dependencies)
- [Usage](#usage)
  - [Generating Books](#generating-books)
  - [Revising Content](#revising-content)
  - [Text Analysis](#text-analysis)
- [Configuration](#configuration)
- [Modules and Structure](#modules-and-structure)
  - [Core Modules](#core-modules)
  - [Utility Modules](#utility-modules)
  - [Other](#other)
- [Changelog](#changelog)
- [Todo](#todo)
- [Contributing](#contributing)
- [License](#license)

---

# Overview

GPTK is designed for authors, developers, and researchers looking to leverage AI for content creation and refinement. It offers robust support for managing book outlines, generating chapter fragments, revising text with pattern recognition, and conducting linguistic analysis. By integrating APIs from various AI providers, GPTK provides a unified interface for intelligent text operations.

# Features

- **Multi-Agent Support:** Seamlessly integrate with ChatGPT, Claude, Grok, and Gemini.
- **Book Generation:** Automate novel creation chapter by chapter, with dynamic fragment handling.
- **Content Revision:** Revise text using pattern matching, manual operations, or AI-driven corrections.
- **Text Analysis:** Identify patterns, repeated content, and structural inconsistencies.
- **Extensible Configuration:** Customize prompts, patterns, and revision workflows.
- **Training Data Management:** Integrate training data from the `/prompts` directory for contextual reference.

## Getting Started

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-username/gptk.git
   cd gptk
   ```

2. Install dependencies using Bundler:

   ```bash
   bundle install
   ```

### Dependencies

- Ruby 3.0 or later
- Gems:
  - `pragmatic_segmenter`
  - `httparty`
  - API clients for AI services (OpenAI, Anthropic, etc.)

## Usage

### Generating Books

Use the `Book` class to generate a novel chapter by chapter. Provide an outline, instructions, and AI API clients.

```ruby
require 'book'

outline = "path/to/outline.txt"
book = GPTK::Book.new outline, openai_client: my_chatgpt_client

# Generate a 5-chapter book with 3 fragments per chapter
book.generate 5, 3
```

### Revising Content

Revise text by identifying and acting on patterns with AI or manual operations.

```ruby
text = "This is a sample text with repeated patterns."
pattern = "repeated patterns"
revised_text, revisions = book.revise_chapter_content text, pattern
```

### Text Analysis

Analyze text to identify repeated patterns or specific issues.

```ruby
matches = GPTK::Text.analyze_text "Analyze this sample text.", "sample"
GPTK::Text.print_matches matches
```

## Configuration

All configurations are managed through the `/config` directory. Key configuration files include:

- **`ai_setup.rb`:** Handles API client initialization.
- **`book_setup.rb`:** Contains book generation parameters.
- **`config.rb`:** Loads and manages overall configuration.

---

# Modules and Structure

### Core Modules:

#### Book
Manages the creation and revision of books, chapters, and fragments.

- [book.rb](lib/gptk/book.rb)

#### AI
Interfaces with various AI tools for text generation and revision.

- [ai.rb](lib/gptk/ai.rb)

#### Config
Loads and manages application-wide settings.

- [config.rb](lib/gptk/config.rb)

### Utility Modules:

#### Text
Handles text processing, including word counting, pattern matching, and list parsing.

- [text.rb](lib/gptk/text.rb)

#### Doc
Generates structured documents based on text and chapter data.

- [doc.rb](lib/gptk/doc.rb)

#### Utils
Provides helper methods like symbolifying hash keys and incrementing filenames.

- [utils.rb](lib/gptk/utils.rb)

### Other:

#### Prompts
  - AI Training data is located in the [`/prompts`](prompts) directory.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.

## Todo

Planned features and enhancements are listed in [TODO.md](TODO.md).

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This library is licensed under the MIT License. See [LICENSE](LICENSE) for details.
