module GPTK
  module AI
    CONFIG = {
      # Available OpenAI models for use with API:
      # - gpt-4o (high-intelligence flagship model for complex, multi-step tasks.)
      # - gpt-4o-mini (affordable and intelligent small model for fast, lightweight tasks.)
      # - o1-preview (reasoning model designed to solve hard problems across domains.)
      # - o1-mini (faster and cheaper reasoning model particularly good at coding, math, and science.)
      # - gpt-4-turbo (a large multimodal model that can accept text or image inputs and output text,
      #   solving complex problems more accurately than previous models)
      openai_gpt_model: 'gpt-4o-mini'.freeze,
      openai_temperature: 0.7, # Less = more precise, less creative; more = more expansive & creative
      openai_max_tokens: 8192, # GTP-4 max output tokens per request,
      batch_ping_interval: 60 # How long in seconds to wait before checking on the status of a Batch
    }
  end
end