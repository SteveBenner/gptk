# TODO:
- add bundler
- parse chapter using pragmatic segmenter and find patterns of DUPLICATE TEXT, and flag them, create a .docx
- fix Gemini cache usage!!!
- 'mad libs' parsing code
- update revision method with a new sub-option 'prompted revision' where user inputs a prompt informing the AI how to revise the content
- 'post-op' filters (#43 operation); becomes a function within the 'Edit' tab
- fix revision text analysis code
  - look for flipping of original/revised
- colorize revisions output (in the original chapter text) for terminal output
- Front-end web interface for the library
- Role-based AI agent client assignment (accommodating 4 AI platform connections!)
- Track token usage
  - send notifications at specified increments of token usage (count and $ value)

### Research:
- Gemini bad API call results

# ROADMAP:
- Game Writer (more to come later)
- Enable API to accept an array of agent objects which may include an API client object, AND/OR an API key, and a role. Example:

```ruby
{
  client: Anthropic::Client.new,
  api_key: ANTHROPIC_API_KEY,
  role: :content_generation,
  name: 'Claude',
}
```