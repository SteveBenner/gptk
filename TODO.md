# TODO:
- Track token usage
  - send notifications at specified increments of token usage (count and $ value)
- Role-based AI agent client assignment (accommodating 4 AI platform connections!)
- Document library exhaustively
- Front-end web interface for the library
- Finish modes 2 and 3 (old)

# ROADMAP:
- Game Writer (more to come later)
- Enable API to accept an array of agent objects which may include an API client object, AND/OR an API key, and a role. Example:
  - ```ruby
    {
      client: Anthropic::Client.new,
      api_key: ANTHROPIC_API_KEY,
      role: :content_generation,
      name: 'Claude',
    }
    ```