# TODO:
- 'mad libs' parsing code
  - two interfaces (two buttons on the navbar)
    - content generation
    - review phase
  - functions
    - character
    - plot
    - interactions
- update revision method with a new sub-option 'prompted revision' where user inputs a prompt informing the AI how to revise the content
- 'post-op' filters (#43 operation); becomes a function within the 'Edit' tab
- **Front-end web interface for the library**
- Track token usage
  - send notifications at specified increments of token usage (count and $ value)

### Refactoring

### Git hooks
- on file added: fix file name formatting

### Research:
- Revision text analysis code: look for flipping of original/revised in the AI response
- Gemini bad API call results
- Gemini cache usage (currently not working at all)
- Look into Grok overloading with output

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