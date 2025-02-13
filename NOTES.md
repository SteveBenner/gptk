# NOTES

## Technical Challenges
Difficulties we encountered while developing the app

### Gemini image upload problem using context caching
- While writing `query_to_rails_code` for the `Gemini` module, I couldn't get image uploads to work using the context caching. It kept returning an insignificant token usage account from the API, suggesting that it wasn't recognizing the payload data at all.
- The payload data is encoded as Base64, but this didn't seem to be the issue since creating a cache using text content (instead of `inline_data`) worked just fine!
- ***Suggested action:*** investigate whether or not the issue is actually in the encoding, or on their end, since the file processing in ruby is explicit and straightforward.