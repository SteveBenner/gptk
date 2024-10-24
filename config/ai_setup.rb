# Available OpenAI models for use with API:
# - gpt-4o (high-intelligence flagship model for complex, multi-step tasks.)
# - gpt-4o-mini (affordable and intelligent small model for fast, lightweight tasks.)
# - o1-preview (reasoning model designed to solve hard problems across domains.)
# - o1-mini (faster and cheaper reasoning model particularly good at coding, math, and science.)
# - gpt-4-turbo (a large multimodal model (accepting text or image inputs and outputting text)
#   that can solve difficult problems with greater accuracy than any of our previous models)
OPENAI_GPT_MODEL = 'gpt-4o-mini'.freeze
OPENAI_TEMPERATURE = 0.7
OPENAI_MAX_TOKENS = 8192 # GTP-4 max output tokens per request

BATCH_PING_INTERVAL = 60 # How long in seconds to wait before checking on the status of a Batch
