# GPTK: Generative Prompt Toolkit

# todo:
- add 'generating docs' segment

A powerful and modular library for AI-driven text and book generation, revision, and analysis. With GPTK, you can seamlessly integrate AI tools such as ChatGPT, Claude, Grok, and Gemini for crafting narratives, revising text, and managing content generation workflows.

Using a plug-n-play architecture, it is possible to utilize any number of AI agents at the same time, together or separately. They each have their own strengths and drawbacks, so it is important to know the basics of AI platform API usage before using this library.

The *groundbreaking* aspect of this toolkit is that you can generate **truly quality long-form content** using AI and the builtin tools the library offers, **rapidly** and **automatically** if desired. Contrast this to using a simple one-at-a-time interaction such as the ChatGPT web portal.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Getting Started](#getting-started)
  - [AI Platform Setup](#ai-platform-setup)
  - [Installation](#installation)
  - [Dependencies](#dependencies)
- [Usage](#usage)
  - [Client Initialization](#client-initialization)
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
### AI Platform Setup

Before using GPTK, you'll need to create accounts and obtain API keys from the AI platforms you wish to use. Here's how to set up each one:

#### OpenAI (ChatGPT)
1. Visit [OpenAI's platform](https://platform.openai.com/signup)
2. Create an account or sign in
3. Navigate to Settings → API keys
4. Click "Create new secret key"
5. Copy and secure your API key
6. Current pricing: Pay-as-you-go with usage-based rates

#### Anthropic (Claude)
1. Go to [Anthropic's Console](https://console.anthropic.com/)
2. Sign up for an account
3. Once approved, visit the API Keys section
4. Generate a new API key
5. Copy and secure your key
6. Current pricing: Usage-based billing

#### xAI (Grok)
1. Visit [xAI's platform](https://x.ai/)
2. Create an account
3. Request API access (currently in beta)
4. Once approved, generate your API key
5. Copy and secure your key
6. Current pricing: Contact xAI for pricing details

#### Google (Gemini)
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Create a new project if needed
4. Navigate to the API & Services → Credentials
5. Create API key
6. Copy and secure your key
7. Current pricing: Free tier available, then usage-based

**Note:** Store your API keys securely and never commit them to version control. We recommend using environment variables or a secure credentials manager such as `dotenv`.

Example environment variables setup:
```bash
export OPENAI_API_KEY='your-key-here'
export ANTHROPIC_API_KEY='your-key-here'
export XAI_API_KEY='your-key-here'
export GOOGLE_AI_API_KEY='your-key-here'
```

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
  - `openai`
  - `anthropic`

## Usage

### Client Initialization
Below are examples of how you might initialize basic clients using the `openai` and `anthropic` gems. These initialization steps set you up to make requests to ChatGPT (OpenAI) and Claude (Anthropic).

**ChatGPT (OpenAI) Example:**

```ruby
require 'openai'

OPENAI_API_KEY = ENV['OPENAI_API_KEY']
my_chatgpt_client = OpenAI::Client.new(
  access_token: OPENAI_API_KEY,
  request_timeout: 300,
  log_errors: true, # Remove `log_errors` param for production!
  headers: {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{OPENAI_API_KEY}",
    'OpenAI-Beta' => 'assistants=v2'
  }
)
```

**Claude (Anthropic) Example:**

```ruby
ANTHROPIC_API_KEY = ENV['ANTHROPIC_API_KEY']
my_claude_client = Anthropic::Client.new(
  access_token: ANTHROPIC_API_KEY,
  request_timeout: 120,
  headers: {
    'anthropic-beta': 'prompt-caching-2024-07-31'
  }
)
```

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
