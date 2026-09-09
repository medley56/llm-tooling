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
  version: 1.0.1
---

# Create Presentation

Create a reveal.js HTML presentation using the Assertion-Evidence methodology: most content slides carry an assertion headline backed by visual evidence, while some exist to introduce a concept, define a term, frame context, or pose a question.

Output path: what the user gives, else `presentation.html` in the working directory, else the input markdown's directory with a `.html` extension.

## Step 1: Understand and Plan

Read the user's input — a file if they gave a path, otherwise the topic or notes. Identify the title and author, the structure, the key claims, the supporting evidence, and whether there is a clear narrative arc.

If the input is unclear, poorly organized, or just a topic, ask what is not already obvious:

1. **"Who is the audience?"** — calibrates technical depth and framing
2. **"What is the ONE thing you want the audience to remember?"** — forces focus
3. **"What should the audience DO after this presentation?"** — ensures action orientation

Ask which theme they want, defaulting to `black`:

| Theme | Description |
|-------|-------------|
| `white` | Clean and minimal — professional and corporate |
| `black` | Dark background, white text — modern, high contrast |
| `league` | Dark grey with subtle texture — polished and understated |
| `beige` | Warm paper-like background — approachable and academic |
| `sky` | Light blue gradient — friendly and open |
| `night` | Dark blue — technical and evening talks |
| `serif` | Traditional serif fonts — formal and classic |
| `simple` | Plain white, minimal styling — maximum content focus |
| `solarized` | Solarized — easy on the eyes for code-heavy talks |
| `blood` | Dark with red accents — bold and dramatic |
| `moon` | Dark blue-grey — subtle and calm |

The name goes straight into the `{{THEME}}` placeholder.

If the input is poorly organized, say what is wrong with it and ask for the intended narrative arc or key takeaways before continuing.

## Step 2: Outline with Narrative Arc

Present a slide outline grouped into narrative beats, each entry tagged with a slide type and an assertion-style headline. Adapt the beat names to the content ("Context" rather than "Problem" for non-problem-solving talks).

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

Slide-type tags:

- `[title]` — title or closing slide (centered, large text)
- `[section]` — section divider between narrative beats
- `[assertion]` — standard content slide (assertion headline + evidence)
- `[concept]` — introduces a term, definition, framework, or idea without making a claim
- `[metric]` — key number or statistic
- `[comparison]` — two-column side-by-side
- `[code]` — code-focused slide
- `[quote]` — emphasized quotation with attribution
- `[image]` — diagram, chart, or visual (placeholder if no image provided)

Suggest reordering, combining related slides, splitting dense ones, or changing types.

**CRITICAL: wait for approval or adjustments before Step 3.**

## Step 3: Generate HTML

1. Read the template at `assets/template.html` (relative to this skill's directory).
2. Fill in `{{TITLE}}`, `{{AUTHOR}}`, `{{DATE}}`, `{{THEME}}`.
3. Generate a `<section>` per approved slide using the patterns below.
4. Add `class="fragment"` only where the Fragment Rules allow.
5. Include `<aside class="notes"></aside>` on every slide, populated from the source prose or left empty.
6. Write the file to the output path.

## Step 4: Summarize

Report the slide count, output path, theme, and every visualization placeholder needing replacement (slide number and description). Close with the keys: `S` speaker notes, `ESC` overview grid, `F` fullscreen.

## Slide Type Reference

### [title]
```html
<section class="slide-title">
  <h1>Presentation Title</h1>
  <p>Author Name</p>
  <p>Date</p>
  <aside class="notes"></aside>
</section>
```

### [section]
```html
<section class="slide-section">
  <h2>Section Name</h2>
  <aside class="notes"></aside>
</section>
```

### [assertion]
The `<h2>` is optional — a short topic label when it helps orient the audience, omitted when the assertion alone carries the slide.
```html
<section class="slide-assertion">
  <h2>Optional short topic label</h2>
  <p class="assertion">A complete sentence stating the slide's key point.</p>
  <div class="evidence">
    <!-- table, key-point, columns, or other evidence here -->
  </div>
  <aside class="notes"></aside>
</section>
```

### [concept]
```html
<section class="slide-concept">
  <h2>Descriptive headline: a term, phrase, or framing label</h2>
  <div class="evidence">
    <!-- definition, diagram, key attributes, or brief explanation here -->
  </div>
  <aside class="notes"></aside>
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
  <aside class="notes"></aside>
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
  <aside class="notes"></aside>
</section>
```

### [quote]
```html
<section class="slide-quote">
  <blockquote>
    The quote text goes here.
    <div class="attribution">— Attribution</div>
  </blockquote>
  <aside class="notes"></aside>
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
  <aside class="notes"></aside>
</section>
```

### [image], as a background
```html
<section class="slide-image" data-background-image="path/to/image.png" data-background-size="contain">
  <h2>Assertion about what the image shows</h2>
  <aside class="notes"></aside>
</section>
```

### [image], as a placeholder
```html
<section class="slide-image">
  <h2>Assertion about what the image shows</h2>
  <div class="placeholder" data-viz-type="diagram" data-viz-description="Description">
    [PLACEHOLDER: Human-readable description]
  </div>
  <aside class="notes"></aside>
</section>
```

### [image], inline
`class="r-stretch"` makes reveal.js size the image to the available space, and keeps it correct in print-pdf export.
```html
<section class="slide-image">
  <h2>Assertion about what the image shows</h2>
  <img class="r-stretch" src="path/to/image.svg" alt="Description">
  <aside class="notes"></aside>
</section>
```

## Headline Rules

Assertion-Evidence is the default and dominant pattern. Slides that introduce concepts, define terms, frame context, or pose questions may instead use a **descriptive headline** — a short label that orients rather than asserts.

On `[assertion]` slides the claim is a full sentence in `<p class="assertion">`, not in the heading. On `[metric]`, `[comparison]`, and `[image]` slides the `<h2>` carries the assertion, since they have no separate assertion element.

| Bad (topic phrase) | Good (assertion sentence) |
|---|---|
| "Performance Results" | "Response times improved 3x after the migration" |
| "System Architecture" | "Three loosely coupled services replaced the monolith" |
| "Cost Analysis" | "Annual infrastructure costs dropped 40% despite higher throughput" |
| "Background" | "The legacy batch system could not meet real-time processing demands" |

Descriptive headlines suit `[concept]` slides and `[code]` slides whose code speaks for itself: "What is eventual consistency?", "Key terms: producers, consumers, and brokers", "The CAP theorem".

No assertion headline on `[title]`, `[section]`, or `[quote]` slides.

### Body Must Be Visual Evidence

In priority order: a single large figure (`.key-point`), a table, a code snippet (max 15 lines), a two- or three-item column layout (`.columns`), or a visualization — the last only when the outline tagged the slide `[image]`.

- **No bullet lists as the slide body.** Prefer tables, columns, or a split across slides. Where bullets genuinely are clearest, cap at 3–4 items of under 8 words.
- **No large text blocks.** At most 3 short lines of body text; detailed prose goes to speaker notes.
- **No decorative visuals.** No clip art, no stock photos. Every visual supports the point.

## Slide Type Distribution

`[assertion]` carries 50–70% of content slides. The rest provide variety and emphasis: `[concept]` for terms the audience needs before you can make claims about them, `[metric]` for the 1–3 most impactful numbers, `[comparison]` for tradeoffs and before/after, `[code]` when the code *is* the point, `[quote]` sparingly for a closing or framing line, `[image]` only when a visual beats text, `[section]` 2–4 times to separate beats.

## Fragment Rules

Use `class="fragment"` only for sequential steps that build, table rows walked through one at a time, and a punchline where the final item is the insight. Never fragment every element — at least one must be visible immediately.

## Content Transformation Rules

| Markdown | Slide treatment |
|---|---|
| `# H1` | Title slide or section divider |
| `## H2` | Content slide — rewrite as an assertion sentence, or a descriptive headline for concept slides |
| `### H3` and deeper | Fold into the parent slide's evidence, or promote if substantial |

**Bullet lists** do not survive as lists: 2–3 items become a `.columns` layout, a comparison becomes a table, sequential steps become one slide per step or a numbered column layout, and 4+ items get grouped into categories across several slides.

**Code blocks** render as `<pre><code data-trim data-noescape class="language-X">` for highlight.js, at most 15 lines per slide; split longer ones with a headline explaining each segment.

**Tables** convert directly to HTML inside `.evidence`. Split very wide ones across slides.

**Prose paragraphs** become an assertion headline plus extracted data points, with the full text in `<aside class="notes">`.

## Visualization Policy

- **Default to none.** Most concepts work with text, tables, or numbers.
- Visualizations are approved as part of the outline, via `[image]` tags — never introduced in a separate step.
- Placeholders use `.placeholder` with `data-viz-type` (`diagram`, `chart`, `graph`, `screenshot`, `photo`) and `data-viz-description`.
- Complex visualizations go in separate `.svg` files referenced from the HTML.

## HTML Output Constraints

- Valid HTML5, reveal.js 5.x from `https://unpkg.com/reveal.js@5/`, with the highlight.js and notes plugins loaded.
- Cap at roughly 20 content slides. Beyond that, suggest splitting into multiple presentations and ask which sections to prioritize.
- Every content slide is a `<section>` with its slide-type class.
- Keep the template's `pdfSeparateFragments: false`, `slideNumber: 'c/t'`, and `showSlideNumber: 'all'` — they are what make print-pdf output correct.

## Troubleshooting

- **No styling** — the browser cannot reach the CDN. Download the reveal.js dist and point the HTML at local paths.
- **Speaker notes will not open** — speaker view needs HTTP in some browsers. Serve the file (`python -m http.server`) rather than opening it from `file://`.
- **Code not highlighted** — the `<code>` element needs `class="language-X"` and `RevealHighlight` must be in the plugins array.
