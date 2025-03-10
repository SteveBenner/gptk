module GPTK
  class Book
    num_chapters = 12 # BE EXTREMELY CAREFUL SETTING THIS VALUE!!!
    chapter_fragments = 7 # This determines how many chapter fragments are in a chapter. Larger values = more words.
    chapter_fragment_words = 3000 # How large each chapter fragment is
    CONFIG = {
      num_chapters: num_chapters,
      chapter_fragments: chapter_fragments,
      chapter_fragment_words: chapter_fragment_words,
      max_total_matches: 64, # Maximum bad pattern matches to collect when analyzing text
      initial_prompt: 'Generate the first portion of the current chapter of the story.',
      continue_prompt: 'Continue generating the current chapter of the story, starting from where we left off. Do NOT repeat any previously generated material.',
      prompt: "For the chapter title and content, refer EXPLICITLY to the outline, and if included, the prior chapter summary and current chapter summary. Refer to your context for memory of prior content, as well. Chapter title should be an H1 element SPECIFICALLY (# character in markdown) followed by the chapter name. Chapter titles must match those in the outline EXACTLY. Generate AT LEAST #{chapter_fragment_words} words.",
      post_prompt: 'Make SURE to include the chapter number with the chapter title.',
      command_code: 'The response should FIRST contain the chapter content, THEN, delineated with 3 dashes (markdown horizontal line), a summary of the current chapter fragment. Delineation of the summary MUST be 3 dashes SPECIFICALLY.',
      meta_prompt: 'Maintain continuity and do NOT repeat any previously generated material. Generate as much content as possible. AVOID commentary to the user; just produce book content. AVOID expose, i.e. "telling" instead of "showing". AVOID explaining what is going on at the end of a fragment/chapter, like "the stage was set" or "the chapter closed". AVOID repeating phrases or elements that have already been used, such as "shivers went down her spine" and "the air was thick with tension". AVOID cliches and trite writing style. AVOID cliches, platitudes, and trite phraseology.',
      # A list of bad authoring patterns and corresponding prompts to use in the chapter review process
      bad_patterns: {
        'Avoid Clichés and Cheesy Tropes': "1. **Excessive Quotations or Overused Sayings**: Identify instances where quotes, idioms, aphorisms, or platitudes are over-relied upon, leading to a lack of originality in expression.
          2. **Clichés**: Highlight phrases or expressions that are overly familiar or predictable, diminishing the impact of the prose.
          3. **Cheesy or Overwrought Descriptions**: Pinpoint descriptions that are overly sentimental, melodramatic, unrefined, or simply using exposé (i.e., “telling” not “showing” the plot advancement).
          4. **Redundancies**: Detect repetitive ideas, words, or phrases that do not add value or nuance to the text.
          5. **Pedantic Writing**: Flag passages that feel condescending or patronizing without advancing the narrative or theme.
          6. **Basic or Unsophisticated Language**: Identify \"basic-bitch\" tendencies, such as dull word choices, shallow insights, obtuse statements, or oversimplified metaphors.
          7. **Overstated or Over-explanatory Passages**: Locate areas where the text feels \"spelled out\" unnecessarily, where the writing style is overly “telling” the story instead of “showing” it with descriptive narrative.
          8. **Forced Idioms or Sayings**: Highlight awkwardly inserted idiomatic expressions that clash with the tone or context of the writing.",
        'Subtlety vs. Over-Obviation': "Examine the text for moments where emotional beats or plot points are overtly told rather than shown. Identify any over-explained ideas or heavy-handed descriptions. Provide suggestions to make these moments more nuanced by showing them through actions, dialogue, or sensory details. Where applicable, introduce symbolism, subtext, or metaphor to convey meaning subtly while maintaining clarity and engagement.",
        'Avoid Premature Plot Giveaways': "Review the text for any plot points or revelations that occur too early or disrupt the natural pacing of the story. Identify where critical twists or surprises are prematurely exposed. Suggest adjustments to delay these moments, ensuring they unfold naturally and with maximum impact. Where necessary, incorporate subtle foreshadowing to hint at upcoming developments without overtly revealing them, maintaining suspense and reader engagement.",
        'Introduce or Refine Micro-Events': "Analyze the text for opportunities to introduce or refine small, significant moments—micro-events—that enrich the plot or reveal character quirks. Look for areas where minor interactions, actions, or details could subtly set up major events or add depth to the narrative. Suggest specific micro-events that align with the story's themes, character arcs, or future developments, ensuring they feel organic and purposeful.",
        'Introduce or Refine Macro-Events': "Evaluate the text for opportunities to introduce or refine major plot developments—macro-events—that significantly drive momentum, alter the stakes, or add complexity to the story. Identify areas where the narrative could benefit from a dramatic turning point, such as a war, a groundbreaking discovery, or an unexpected betrayal. Suggest specific macro-events that align with the story's themes and character arcs, ensuring they escalate tension and deepen reader engagement.",
        'Insert, Change, or Remove Plot Devices': "Examine the text for existing plot devices, such as red herrings, McGuffins, or deus ex machina, and evaluate their effectiveness. Identify any devices that feel out of place, overly contrived, or misaligned with the story's tone and credibility. Suggest improvements by refining or replacing these devices, or propose new ones that enhance the plot's cohesion and intrigue while maintaining narrative consistency.",
        'Tone-Up or -Down Character Traits': {
          text: "Analyze the [1] in the text and evaluate their [2] for balance and consistency. Identify key plot points where [3] can be amplified or minimized to enhance [4]. Gauge the range between the lower end of [5], where the character becomes too believable and risks being boring, and the upper end of [6], where the character becomes too intriguing and risks being unbelievable. Suggest specific adjustments, such as [7] or [8], to create stronger dynamics with [9] and improve the overall story.",
          libs: {
            characters: [
              "Clara Walker",
              "Dan Cassidy",
              "O.B.F.",
              "Candy Sweets",
              "Percy Atkins Whitaker",
              "Anthony (Animal Stalls Manager)",
              "Dave (Lion Tamer)",
              "Miss Sam (Belly Dancer)",
              "Nancy (Stage Musician)",
              "Patrick (Ringmaster’s Assistant)"
            ],
            personality_and_character_traits: [
              "Stubbornness",
              "Arrogance",
              "Bravery",
              "Compassion",
              "Guilt",
              "Manipulation",
              "Ambition",
              "Paranoia",
              "Observant nature",
              "Cryptic behavior"
            ],
            specific_personality_traits_or_behaviors: [
              "Compassion for others",
              "Ruthlessness in leadership",
              "Defensive reactions to criticism",
              "Paranoia about conspiracies",
              "Guilt over past decisions",
              "Obsession with public image",
              "Manipulative charm",
              "Observant and quiet demeanor",
              "Courage in dangerous situations",
              "Overconfidence in abilities"
            ],
            story_aspects: [
              "Conflict",
              "Relationships",
              "Mystery resolution",
              "Depth of character development",
              "Tension between characters",
              "Emotional stakes",
              "Suspense in the investigation",
              "Hidden motives",
              "Unraveling past secrets",
              "Developing trust or mistrust"
            ],
            overly_subdued_or_flat_traits: [
              "Ordinary kindness",
              "Passive nature",
              "Practical plainness",
              "Reluctance to act decisively",
              "Overly rational thinking",
              "Unemotional responses",
              "Over-accommodation of others’ needs",
              "Modest aspirations",
              "Lack of imagination",
              "Excessive self-doubt"
            ],
            exaggerated_or_extreme_traits: [
              "Unrealistic charm",
              "Obsessive behaviors",
              "Extreme paranoia",
              "Over-the-top arrogance",
              "Reckless impulsiveness",
              "Uncontrollable temper",
              "Excessive ambition",
              "Overbearing confidence",
              "Incessant manipulation",
              "Overly cryptic demeanor"
            ],
            intensifying_traits_for_effect: [
              "Intensifying stubbornness for tension",
              "Heightening defensiveness for conflict",
              "Amplifying guilt for vulnerability",
              "Increasing arrogance for dramatic clashes",
              "Magnifying paranoia to create suspense",
              "Strengthening compassion to build emotional stakes",
              "Expanding manipulativeness to create intrigue",
              "Enhancing bravery to drive critical moments",
              "Boosting ruthlessness for power struggles",
              "Heightening ambition to push character goals"
            ],
            softening_traits_for_effect: [
              "Softening arrogance for relatability",
              "Reducing paranoia for balance",
              "Moderating defensiveness for trust-building",
              "Easing ruthlessness for vulnerability",
              "Lessening cryptic behavior for clarity",
              "Calming impulsiveness for steadiness",
              "Softening guilt for redemption arcs",
              "Tempering manipulation to add sincerity",
              "Dimming overconfidence to show self-awareness",
              "Soothing emotional swings for stability"
            ],
            specific_other_characters_or_groups: [
              "Circus troupe",
              "The rival",
              "The family",
              "Esther Cassidy",
              "O.B.F.",
              "Percy Atkins Whitaker",
              "Patrick (Ringmaster’s Assistant)",
              "Candy Sweets",
              "Clara’s investigative subjects",
              "Wilmington townsfolk"
            ]
          }
        },
        'Inject New Characters': "Review the text for opportunities to introduce new characters who can challenge, support, or act as a foil to the protagonist. Suggest potential characters that align with the story’s themes and contribute to plot progression or emotional depth. Provide a brief outline of each new character’s personality, motivations, and role in the narrative, ensuring they have a clear purpose and enhance existing dynamics.",
        'Enhance Dialogue': "Analyze the dialogue in the text to ensure it reflects each character's unique voice, motivations, and relationships. Evaluate opportunities to adjust speech for consistency, tension, humor, or exposition. Use the following 'dials' to refine dialogue:
    • Voice: Highlight or suggest distinct patterns, vocabulary, and quirks that make each character's speech identifiable.
    • Pacing: Adjust rhythm or word choice to heighten emotional impact or tension.
    • Subtext: Infuse conversations with implied meanings or hidden motivations to add depth.
    • Conflict: Introduce or enhance disagreements, misunderstandings, or power dynamics to create engaging tension.
Provide specific revisions or examples to illustrate these improvements.",
        'Add Context to Characters': "Examine the characters in the text and identify areas where additional context—such as backstory, motivations, or inner conflicts—could enhance their depth and relatability. Suggest ways to expand on these elements to create more well-rounded and compelling characters. Ensure their actions, decisions, and dialogue remain consistent with their psychological profiles and contribute meaningfully to the narrative.",
        'Dial Up or Down Existing Themes': "Analyze the text for how existing themes are presented and determine whether they are overly explicit or too subtle. Suggest adjustments to dial up or down these themes for better balance and resonance. Propose ways to subtly integrate thematic elements through dialogue, imagery, symbolism, or character actions, ensuring they enhance the story without overshadowing the narrative.",
        'Introduce New Themes': "Evaluate the text for opportunities to introduce new themes that add layers of meaning and resonate with the central story. Suggest thematic elements, such as interpersonal dynamics, societal critique, or existential exploration, that complement the plot and characters. Propose ways to integrate these themes seamlessly, using dialogue, symbolism, or key events to enhance depth and engagement.",
        'Add Reader Intrigue': "Analyze the text for opportunities to heighten reader engagement by introducing or enhancing elements of intrigue. Suggest ways to incorporate mysteries, unresolved questions, or compelling stakes that keep the reader invested. Propose emotional hooks, such as moments of suspense, character dilemmas, or unexpected twists, that maintain momentum and deepen the reader's connection to the story.",
        'Enrich Environmental and World-Building Descriptions': "Review the text for opportunities to enhance environmental and world-building descriptions. Suggest ways to add sensory details—sight, sound, smell, touch, and taste—to immerse readers fully in the setting. Consider how the environment can reflect the story's themes, evoke specific emotions, or influence character behavior and decisions. Propose refinements or additions to create a vivid and dynamic backdrop that enhances the narrative.",
        'Add Contextual Background': "Analyze the text for opportunities to introduce or expand on cultural, historical, or societal elements that shape the story's context. Suggest additions that provide depth and enhance the narrative's believability, such as a political conflict influencing character motivations or societal norms impacting their decisions. Ensure these elements are woven seamlessly into the story, enriching the world without overwhelming the plot.",
        'Balance Pacing': "Evaluate the text for pacing, identifying areas where the tempo of scenes may need adjustment. Suggest ways to create contrast between high-intensity moments and reflective, slower-paced sections to maintain reader engagement. Ensure transitions between chapters or scenes are smooth and cohesive, avoiding abrupt shifts that disrupt the flow. Provide recommendations for restructuring or rephrasing to achieve a balanced narrative rhythm.",
        'Weave Subplots': "Analyze the text for opportunities to add or adjust subplots that enrich the narrative. Suggest secondary storylines that complement the main plot, deepen character development, or explore additional themes. Ensure these subplots are seamlessly integrated and tied back into the central story, enhancing its complexity and coherence without detracting from the primary focus.",
        'Heighten Emotional Resonance': "Evaluate the text for opportunities to heighten emotional resonance in key moments. Identify scenes of vulnerability, triumph, or loss that could be further developed to evoke reader empathy and connection to characters and context. Suggest the use of internal monologues, vivid physical descriptions, or subtle sensory details to enhance the reader’s emotional engagement. Ensure these elements align with the characters’ journeys and the story’s tone.",
        'Refine Narrative Voice': "Analyze the text for the narrative voice, focusing on consistency and tone throughout the story. Ensure the narrator’s perspective aligns with the intended style and reader experience. Suggest adjustments to the level of formality or intimacy, tailoring the voice to enhance engagement and match the story’s themes and genre. Provide examples where changes could clarify or strengthen the narrative voice.",
        'Ensure Cohesion and Flow': "Review the text to ensure that all elements—plot, characters, and themes—complement and enhance one another. Identify any inconsistencies, disjointed sections, or loose ends. Suggest adjustments to improve the overall flow and coherence of the narrative. If intentional ambiguity is present, verify that it serves a clear purpose and aligns with the story’s tone and goals."
      },
      # Define atomic parsing steps via Ruby procs, so they can be passed individually to parser methods
      # Each element is composed of 1) A regular expression search pattern, and 2) A string replacement pattern
      default_parsers: { # Regex, replacement
        convert_bolded_titles_to_h1_and_add_newline: [/\*\*(chapter \d\d?:.*?)\*\*/i, "\n\n# \\1"],
        convert_h2_and_h3_headings_to_h1: [/\#{1,3}/i, '#'],
        remove_quotes_around_chapter_titles: [/chapter (\d{1,2}): [“"“](.+?)[”"”]/i, 'Chapter \1: \2'],
        remove_extraneous_chapter_titles: [/(\# chapter \d{1,2}: .+?$)/i, Proc.new do |chapter_title|
         # Check if this chapter title has been encountered before
         if encountered_chapter_titles.include? chapter_title # Replace current instance with an empty string
           ''
         else # No text replacement necessary for the first instance, BUT we need to add a newline
           encountered_chapter_titles << chapter_title
           $/ + chapter_title
         end
        end],
        # add_newlines_before_chapter_titles: /(?<!\n)\n#/
        remove_horizontal_bars: [/\n---\n/, nil],
        remove_extra_newlines_from_start_of_file: [/\n\n(.*)/i, '\1'],
        remove_chapter_conclusion: [/---\n\n.*chapter*[^-]*---/, nil],
        # TODO: parse out 'FRAGMENT' instances
        # TODO: parse out sub headings within fragments
      }
    }.freeze
  end
end
