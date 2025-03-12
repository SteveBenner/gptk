# frozen_string_literal: true

module GPTK
  module AI
    CONFIG = {
      bad_api_call_limit: 5, # Maximum number of failed API queries before removing bad API agent
      # Available OpenAI models for use with API:
      # - gpt-4o (high-intelligence flagship model for complex, multi-step tasks.)
      # - gpt-4o-mini (affordable and intelligent small model for fast, lightweight tasks.)
      # - o1-preview (reasoning model designed to solve hard problems across domains.)
      # - o1-mini (faster and cheaper reasoning model particularly good at coding, math, and science.)
      # - gpt-4-turbo (a large multimodal model that can accept text or image inputs and output text,
      #   solving complex problems more accurately than previous models)
      # - gpt-4.5-preview
      openai_gpt_model: 'o3-mini',
      openai_temperature: 1, # Less = more precise, less creative (for some models '1' is required)
      openai_max_tokens: 8192, # GTP-4 max output tokens per request,
      batch_ping_interval: 60, # How long in seconds to wait before checking on the status of a Batch
      # Available Anthropic API models:
      # - claude-3-5-sonnet-latest
      # - claude-3-5-haiku-latest
      # - claude-3-opus-latest
      # - claude-3-sonnet-20240229
      # - claude-3-haiku-20240307
      anthropic_gpt_model: 'claude-3-7-sonnet-latest',
      anthropic_max_tokens: 8192, # Must be larger than 'thinking budget'
      anthropic_thinking_budget: 4096, # Tokens available for 'extended thinking'
      # Grok only has one available model currently
      xai_gpt_model: 'grok-2-latest',
      xai_temperature: 0,
      xai_max_tokens: 4096,
      # Google has 3 AI models available:
      # - gemini-1.5-flash (fast and versatile)
      # - gemini-1.5-flash-8b (high volume and lower intelligence)
      # - gemini-1.5-pro (complex reasoning and more intelligence)
      google_gpt_model: 'gemini-1.5-pro-001', # Specify 001 to indicate caching feature support
      gemini_ttl: '300s', # Amount of time cached tokens are stored
      gemini_min_cache_tokens: 32768 # Number of min tokens required for using caching
    }
  end
end
