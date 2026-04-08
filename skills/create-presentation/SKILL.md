---
name: create-presentation
description: >
  Creates a reveal.js HTML presentation from markdown content, a topic
  description, or rough notes. Use when the user asks to "create a
  presentation", "make slides", "build a slide deck", "create a reveal.js
  presentation", or provides content and asks for a presentation. Accepts
  optional theme preference and output path. Do NOT use for PowerPoint,
  Google Slides, Keynote, or W3C Slidy formats.
metadata:
  author: llm-tooling
  version: 1.0.0
---

# Create Presentation

Create a reveal.js HTML presentation guided by the Assertion-Evidence slide design methodology. Most content slides should use assertion headlines backed by visual evidence, but some slides may serve other purposes — introducing concepts, defining terms, framing context, or posing questions. Accepts markdown files, topic descriptions, or rough notes as input.

## Instructions

The user provides content (a markdown file path, topic description, or notes) and optionally an output path and theme. If no output path is given, write the HTML file in the current working directory as `presentation.html`. If the input is a markdown file, use the same directory with a `.html` extension.

### Step 1: Understand and Plan

Read the user's input. If it's a file path, read the file. If it's a topic or notes, work from what's provided.

Identify:
- **Title and author** from front matter, headings, or context
- **Document structure** — headings, sections, hierarchy
- **Key claims** — the main points or arguments
- **Supporting evidence** — data, examples, code, tables
- **Logical flow** — whether there's a clear narrative arc

If the input is unclear, poorly organized, or just a topic, ask these focusing questions (skip any that are already obvious from the input):

1. **"Who is the audience?"** — calibrates technical depth and framing
2. **"What is the ONE thing you want the audience to remember?"** — forces focus
3. **"What should the audience DO after this presentation?"** — ensures action orientation

Ask the user which reveal.js theme they'd like. Present the options:

| Theme | Description |
|-------|-------------|
| `white` | Clean and minimal — good for professional and corporate presentations |
| `black` | Dark background with white text — modern, high contrast |
| `league` | Dark grey with subtle texture — polished and understated |
| `beige` | Warm paper-like background — approachable and academic |
| `sky` | Light blue gradient — friendly and open |
| `night` | Dark blue background — good for technical and evening talks |
| `serif` | Traditional serif fonts — formal and classic |
| `simple` | Plain white, minimal styling — maximum content focus |
| `solarized` | Solarized color scheme — easy on the eyes for code-heavy talks |
| `blood` | Dark with red accents — bold and dramatic |
| `moon` | Dark blue-grey — subtle and calm |

If the user has no preference, default to `black`.

Assess organization quality:
- **Well-organized:** Clear structure, logical flow. Proceed to Step 2.
- **Poorly organized:** Tell the user what issues you found. Ask them to describe the intended narrative arc or key takeaways before proceeding.

### Step 2: Outline with Narrative Arc

Present a slide outline grouped into narrative beats. Each entry includes a slide-type tag and an assertion-style headline. The narrative beats guide the story structure — adapt the beat names to fit the content (e.g., "Context" instead of "Problem" for non-problem-solving presentations).

Example:

> I've structured your presentation into a narrative arc:
>
> **Opening (hook the audience)**
> 1. [title] "Migrating to Event-Driven Architecture" — Author, Date
> 2. [metric] The legacy system hit a wall at 10K requests/second
>
> **Problem (establish stakes)**
> 3. [assertion] Three bottlenecks made the monolith unscalable
> 4. [comparison] Request-driven vs. event-driven: fundamentally different tradeoffs
>
> **Solution (your key insight)**
> 5. [assertion] Event-driven architecture decouples producers from consumers
> 6. [code] The event handler validates and routes in 12 lines
> 7. [image] Three microservices replaced the monolithic request handler
>
> **Evidence (prove it works)**
> 8. [metric] Throughput improved 3.2x with no increase in infrastructure cost
> 9. [comparison] Before/after: latency, throughput, and error rates
>
> **Close (call to action)**
> 10. [quote] "The best architecture is the one your team can evolve"
> 11. [title] Questions & next steps
>
> Would you like to adjust the flow, reorder sections, or change any slide types?

Available slide-type tags:
- `[title]` — title or closing slide (centered, large text)
- `[section]` — section divider (dark background, used between narrative beats)
- `[assertion]` — standard content slide (assertion headline + evidence)
- `[concept]` — introduces a term, definition, framework, or idea without making a claim
- `[metric]` — key number or statistic (assertion headline + large figure)
- `[comparison]` — two-column side-by-side layout
- `[code]` — code-focused slide (assertion headline or descriptive headline + code block)
- `[quote]` — emphasized quotation with attribution
- `[image]` — slide with a diagram, chart, or visual (generates placeholder if no image provided)

Guide the user on flow improvements: suggest reordering, combining related slides, splitting dense ones, or changing slide types. The goal is a presentation that tells a clear story.

CRITICAL: Wait for the user's approval or adjustments before proceeding to Step 3.

### Step 3: Generate HTML

1. Read the template at `assets/template.html` (relative to this skill's directory)
2. Replace `{{TITLE}}`, `{{AUTHOR}}`, `{{DATE}}`, and `{{THEME}}` placeholders
3. Generate a `<section>` element for each approved slide using the appropriate CSS class and HTML pattern (see Slide Type Reference below)
4. Add `class="fragment"` for incremental reveals where appropriate (see Fragment Rules)
5. Add `<aside class="notes">` for speaker notes where the source material has prose worth preserving as talking points
6. Write the complete HTML file to the output path

### Step 4: Summarize

Report to the user:
- Total slide count
- Output file path
- Theme used
- Any visualization placeholders that need replacement (list slide numbers and descriptions)
- Usage tips: open in a browser; press `S` for speaker notes view; press `ESC` for slide overview grid; press `F` for fullscreen

## Slide Type Reference

Map each slide-type tag to its HTML pattern:

### [title]
```html
<section class="slide-title">
  <h1>Presentation Title</h1>
  <p>Author Name</p>
  <p>Date</p>
</section>
```

### [section]
```html
<section class="slide-section">
  <h2>Section Name</h2>
</section>
```

### [assertion]
The `<h2>` is optional — include it when a short topic label helps orient the audience; omit it when the assertion sentence alone is sufficient.
```html
<section class="slide-assertion">
  <h2>Optional short topic label</h2>
  <p class="assertion">A complete sentence stating the slide's key point.</p>
  <div class="evidence">
    <!-- table, key-point, columns, or other evidence here -->
  </div>
</section>
```

### [concept]
```html
<section class="slide-concept">
  <h2>Descriptive headline: a term, phrase, or framing label</h2>
  <div class="evidence">
    <!-- definition, diagram, key attributes, or brief explanation here -->
  </div>
</section>
```

### [metric]
```html
<section class="slide-metric">
  <h2>Assertion about what the metric means</h2>
  <div class="key-point">
    3.2x
    <span class="label">throughput improvement</span>
  </div>
</section>
```

### [comparison]
```html
<section class="slide-comparison">
  <h2>Assertion about the comparison</h2>
  <div class="columns">
    <div class="col">
      <h3>Option A</h3>
      <p>Details...</p>
    </div>
    <div class="col">
      <h3>Option B</h3>
      <p>Details...</p>
    </div>
  </div>
</section>
```

### [quote]
```html
<section class="slide-quote">
  <blockquote>
    The quote text goes here.
    <div class="attribution">— Attribution</div>
  </blockquote>
</section>
```

### [code]
```html
<section class="slide-code">
  <h2>Assertion about what the code demonstrates</h2>
  <pre><code data-trim data-noescape class="language-python">
def example():
    return "hello"
  </code></pre>
</section>
```

### [image] with background
```html
<section class="slide-image" data-background-image="path/to/image.png" data-background-size="contain">
  <h2>Assertion about what the image shows</h2>
</section>
```

### [image] with placeholder
```html
<section class="slide-image">
  <h2>Assertion about what the image shows</h2>
  <div class="placeholder" data-viz-type="diagram" data-viz-description="Description">
    [PLACEHOLDER: Human-readable description]
  </div>
</section>
```

## Headline Rules

Most content slides should follow the Assertion-Evidence format: an assertion headline (a complete sentence stating the slide's key point) backed by visual evidence. This is the default and should be the dominant pattern.

However, not every slide makes a claim. Some slides introduce concepts, define terminology, frame context, or pose questions. These slides may use **descriptive headlines** — short labels or phrases that orient the audience rather than assert a conclusion.

### Assertion Sentences (default)

On `[assertion]` slides, the key claim is expressed as a full sentence in a `<p class="assertion">` element in the slide body — not in the heading. The `<h2>` heading is optional and serves as a short topic label when helpful.

On `[metric]`, `[comparison]`, and `[image]` slides, the `<h2>` heading still carries the assertion as a complete sentence (these slide types don't have a separate assertion element).

| Bad (topic phrase) | Good (assertion sentence) |
|---|---|
| "Performance Results" | "Response times improved 3x after the migration" |
| "System Architecture" | "Three loosely coupled services replaced the monolith" |
| "Cost Analysis" | "Annual infrastructure costs dropped 40% despite higher throughput" |
| "Background" | "The legacy batch system could not meet real-time processing demands" |

### Descriptive Headlines (when appropriate)

Use descriptive headlines on `[concept]` slides and optionally on `[code]` slides where the code is self-explanatory. These may be short phrases, terms, or questions.

| Example descriptive headlines |
|---|
| "What is eventual consistency?" |
| "Key terms: producers, consumers, and brokers" |
| "The CAP theorem" |
| "API surface overview" |

Assertion headlines should NOT appear on `[title]`, `[section]`, or `[quote]` slides.

### Body Must Be Visual Evidence

The area below the headline provides visual evidence supporting the assertion. Prefer these formats in priority order:

1. **Key number or metric** — a single large, bold figure (`.key-point` class)
2. **Table** — for comparisons, before/after data, feature matrices
3. **Code snippet** — for technical presentations (max 15 lines per slide)
4. **Column layout** — two or three items side by side (`.columns` class)
5. **Visualization or placeholder** — only when the outline includes an `[image]` tag

### What to Avoid

- **Bullet lists as slide body.** Prefer tables, column layouts, or splitting across slides. If bullets are the clearest format (e.g., a short list of terms or attributes on a `[concept]` slide), limit to 3–4 items, each under 8 words.
- **Large text blocks.** No slide should have more than 3 short lines of body text. Move detailed prose to speaker notes.
- **Decorative visuals.** Never add clip art, stock photos, or decorative images. Every visual must directly support the slide's point.

## Slide Type Distribution

`[assertion]` should be the dominant slide type — roughly 50–70% of content slides. Use other types for variety and emphasis:
- `[concept]` — for introducing terms, definitions, or frameworks the audience needs before you can make claims about them
- `[metric]` — for the 1–3 most impactful numbers
- `[comparison]` — when contrasting two approaches, before/after, or tradeoffs
- `[code]` — for technical audiences when the code IS the point
- `[quote]` — sparingly, for a memorable closing or framing statement
- `[image]` — only when a visual genuinely communicates better than text
- `[section]` — to separate major narrative beats (don't overuse; 2–4 per presentation)

## Fragment Rules

Use `class="fragment"` for incremental reveal ONLY in these cases:
- **Sequential steps** that build on each other
- **Table rows** revealed one at a time to walk through data
- **Punchline reveals** where the final item is the key insight

Never fragment every element on a slide. If a slide has fragments, at least one element should be visible immediately.

## Content Transformation Rules

### Headings

| Markdown | Slide treatment |
|---|---|
| `# H1` | Title slide or section divider |
| `## H2` | Content slide — rewrite as assertion sentence, or use descriptive headline for concept/definition slides |
| `### H3` and deeper | Fold into parent slide's evidence, or promote to own slide if substantial |

### Bullet Lists

Do not reproduce bullet lists on slides. Transform them:
- **Short list (2–3 items):** Column layout with `.columns` class
- **Comparison list:** Convert to a table
- **Sequential steps:** Split into one slide per step, or use a numbered column layout
- **Long list (4+ items):** Group into categories and spread across multiple slides

### Code Blocks

- Render with `<pre><code data-trim data-noescape class="language-X">` for highlight.js
- Maximum 15 lines per slide
- If longer, split across slides with assertion headlines explaining each segment
- Use syntax context in the headline (e.g., "The handler validates input before queuing the event")

### Tables

- Convert directly to HTML `<table>` elements inside the `.evidence` container
- Tables pair well with assertion headlines
- For very wide tables, consider splitting columns across slides

### Prose Paragraphs

- Distill the key claim into the assertion headline
- Extract data points, comparisons, or metrics for the evidence area
- Place the full paragraph text in `<aside class="notes">` for speaker notes

## Visualization Policy

- **Default to no visualizations.** Most concepts work with text, tables, or numbers.
- **Never use clip art or stock imagery.**
- **Visualizations are signaled in the outline** via `[image]` tags — the user approves them as part of the outline, not in a separate step.
- **Placeholder format:** Use the `.placeholder` class with `data-viz-type` and `data-viz-description` attributes. Valid `data-viz-type` values: `diagram`, `chart`, `graph`, `screenshot`, `photo`.
- **Generate SVG if requested** — complex visualizations should be in separate `.svg` files referenced from the HTML to keep the output clean.

## HTML Output Constraints

- Output must be valid HTML5
- Use CDN-loaded reveal.js 5.x from `https://unpkg.com/reveal.js@5/`
- Load plugins: highlight.js (code syntax) and notes (speaker notes)
- Cap at approximately 20 content slides. If the source material would produce more, suggest splitting into multiple presentations and ask the user which sections to prioritize.
- Every content slide uses a `<section>` element with the appropriate slide-type class

## Available Themes

`white`, `black` (default), `league`, `beige`, `sky`, `night`, `serif`, `simple`, `solarized`, `blood`, `moon`

These map directly to reveal.js theme CSS files. Use the theme name as the `{{THEME}}` placeholder value.

## Examples

### Example 1: Markdown file
User says: "Create a presentation from my architecture doc"

Actions:
1. Read the markdown file
2. Ask about audience and theme preference
3. Propose narrative-arc outline with slide-type tags
4. After approval, generate reveal.js HTML
Result: HTML presentation file with chosen theme

### Example 2: Topic description
User says: "Make a presentation about migrating from monolith to microservices"

Actions:
1. Ask focusing questions (audience, key takeaway, desired action)
2. Ask about theme preference
3. Propose narrative-arc outline based on the topic
4. After approval, generate reveal.js HTML
Result: HTML presentation built from topic description

### Example 3: Rough notes
User says: "Turn these meeting notes into slides" (poorly organized input)

Actions:
1. Read the notes, identify organizational issues
2. Ask: "These notes cover several topics. What are the 3–4 key takeaways?"
3. Ask about theme preference
4. After user guidance, propose a structured outline
5. After approval, generate HTML
Result: Organized presentation distilled from unstructured notes

## Troubleshooting

**Slides render without styling:**
Cause: Browser cannot reach the CDN-hosted CSS/JS files (offline or firewall).
Solution: Download reveal.js dist locally and update the HTML references to use local paths.

**Code highlighting not working:**
Cause: Missing language class or plugin not loaded.
Solution: Ensure `<code>` has a `class="language-X"` attribute and `RevealHighlight` is in the plugins array.

**Too many slides generated:**
Cause: Source material is very long.
Solution: The skill caps at ~20 content slides. Ask the user which sections to prioritize or suggest splitting into multiple presentations.

**Speaker notes not showing:**
Cause: Speaker view requires HTTP serving in some browsers.
Solution: Press `S` to open speaker view. If it doesn't work from `file://`, serve with `python -m http.server` or similar.

**Fragments not animating:**
Cause: Missing `class="fragment"` or incorrect element nesting.
Solution: Ensure `class="fragment"` is on the correct child elements, not on the `<section>`.
