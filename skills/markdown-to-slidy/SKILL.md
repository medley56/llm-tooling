# Markdown to Slidy Presentation

Convert a markdown document into a W3C Slidy2 HTML presentation following the Assertion-Evidence slide design methodology.

## Invocation

The user provides a path to a markdown file and optionally an output path. If no output path is given, write the HTML file in the same directory as the input with a `.html` extension.

## Workflow

### Step 1: Read and Analyze

Read the user's markdown file using the Read tool. Identify:

- **Title and author** from front matter, H1, or first lines
- **Document structure** — headings, sections, and their hierarchy
- **Key claims** — the main points or arguments made in each section
- **Supporting evidence** — data, examples, code, tables that back up claims
- **Logical flow** — whether the document has a clear narrative arc

Assess the document's organization quality:
- **Well-organized:** Clear heading hierarchy, logical section order, distinct topics per section. Proceed to Step 2.
- **Poorly organized:** Missing headings, rambling text, mixed topics, unclear structure. Before proceeding, tell the user what organizational issues you found and ask them to describe the intended narrative arc or key takeaways they want the presentation to convey.

### Step 2: Propose Slide Outline

Present a numbered slide outline to the user for approval. Each entry must be a complete assertion sentence — the headline that will appear on that slide. For example:

> I've analyzed your document and propose the following slide deck:
>
> 1. **Title:** "Migrating to Event-Driven Architecture" — Author, Date
> 2. The legacy system handled 10K requests/second but could not scale further
> 3. Event-driven architecture decouples producers from consumers
> 4. Three microservices replaced the monolithic request handler
> 5. Throughput improved 3.2x with no increase in infrastructure cost
> ...
>
> Would you like to adjust any slides, reorder them, or add/remove content?

Wait for the user's approval or adjustments before proceeding to Step 3.

### Step 3: Handle Visualizations

Review the approved outline and identify any slides where a visual (diagram, chart, process flow) would genuinely help explain the concept better than text alone. Collect all such candidates and ask the user in a single batch:

> The following slides may benefit from visualizations:
>
> - **Slide 4:** A diagram showing the three microservices and their message queue connections
> - **Slide 7:** A chart comparing latency before and after migration
>
> For each, I can add a clearly marked placeholder that you can replace with an actual image later. Which (if any) would you like me to include?

If no slides need visualizations, skip this step entirely. Do not suggest visualizations unless they are genuinely necessary.

### Step 4: Generate HTML

1. Read the template at `skills/markdown-to-slidy/assets/template.html` (relative to the project root)
2. Replace the `{{TITLE}}`, `{{AUTHOR}}`, `{{DATE}}`, and `{{YEAR}}` placeholders with actual values
3. Generate a `<div class="slide">` block for each approved slide
4. Write the complete HTML file to the output path using the Write tool

### Step 5: Summarize

Report to the user:
- Total slide count
- Output file path
- Any visualization placeholders that need replacement (list slide numbers and descriptions)
- Suggest opening the file in a browser to preview (Live Server or direct file open)

## Assertion-Evidence Rules

Every content slide must follow the Assertion-Evidence format. This is non-negotiable.

### Headlines Must Be Assertions

The `<h1>` on each slide must be a complete sentence that states the slide's key point — an assertion, not a topic label.

| Bad (topic phrase) | Good (assertion sentence) |
|---|---|
| "Performance Results" | "Response times improved 3x after the migration" |
| "System Architecture" | "Three loosely coupled services replaced the monolith" |
| "Cost Analysis" | "Annual infrastructure costs dropped 40% despite higher throughput" |
| "Background" | "The legacy batch system could not meet real-time processing demands" |

### Body Must Be Visual Evidence

The area below the headline provides visual evidence supporting the assertion. Prefer these formats in this order:

1. **Key number or metric** — a single large, bold figure (use `.key-point` class)
2. **Table** — for comparisons, before/after data, feature matrices
3. **Code snippet** — for technical presentations (max 15 lines per slide)
4. **Column layout** — two or three short items side by side (use `.columns` class)
5. **Visualization placeholder** — only when approved by the user in Step 3

### What to Avoid

- **Bullet lists as slide body.** If you find yourself generating a `<ul>` or `<ol>` as the main slide content, stop and restructure. Convert to a table, split across slides, or use a column layout instead.
- **If bullets are truly unavoidable**, limit to 3 items maximum, each under 8 words. This should be rare.
- **Large text blocks.** No slide should have more than 3 short lines of body text. Move detailed prose to `<div class="handout">` blocks.
- **Decorative visuals.** Never add clip art, stock photos, or decorative images. Every visual must directly support the assertion.

## Visualization Policy

- **Default to no visualizations.** Most concepts can be communicated with text, tables, or key numbers.
- **Never use clip art or stock imagery.** No decorative graphics.
- **Suggest placeholders only when necessary** — architecture diagrams, data charts, process flows, or similar visuals that genuinely cannot be replaced by text.
- **Always ask the user** before adding any placeholder (Step 3).
- **Placeholder format:**

```html
<div class="evidence">
  <div class="placeholder"
       data-viz-type="diagram|chart|graph|screenshot|photo"
       data-viz-description="Detailed description of what the visual should show">
    [PLACEHOLDER: Human-readable description of the needed visual]
  </div>
</div>
```

## Content Transformation Rules

### Headings

| Markdown | Slide treatment |
|---|---|
| `# H1` | Title slide or section divider slide |
| `## H2` | Individual content slide — rewrite heading as assertion sentence |
| `### H3` and deeper | Fold into parent slide's evidence, or promote to own slide if substantial |

### Bullet Lists

Do not reproduce bullet lists on slides. Transform them:
- **Short list (2-3 items):** Column layout with `.columns` class
- **Comparison list:** Convert to a table
- **Sequential steps:** Split into one slide per step, or use a numbered column layout
- **Long list (4+ items):** Group into categories and spread across multiple slides

### Code Blocks

- Render as `<pre>` inside `.evidence`
- Maximum 15 lines per slide
- If longer, split across slides with assertion headlines explaining each segment
- Use syntax context in the headline (e.g., "The handler validates input before queuing the event")

### Tables

- Convert directly to HTML `<table>` elements inside `.evidence`
- Tables count as visual evidence — they pair well with assertion headlines
- For very wide tables, consider splitting columns across slides

### Prose Paragraphs

- Distill the key claim into the assertion headline
- Extract any data points, comparisons, or metrics for the evidence area
- Place the full paragraph text in a `<div class="handout">` block after the slide for handout/notes mode

## HTML Output Constraints

- Output must be valid XHTML 1.0 Strict — self-closing tags (`<br />`, `<img />`), properly quoted attributes, no unclosed elements
- Use the exact CSS and JS references from the template (W3C-hosted Slidy2 + w3c-blue theme)
- Cap at approximately 20 content slides. If the source material would produce more, suggest splitting into multiple presentations and ask the user which sections to prioritize
- Every content slide follows this structure:

```html
<div class="slide">
  <h1>Assertion sentence stating the key point</h1>
  <div class="evidence">
    <!-- Visual evidence: table, key-point, code, columns, or placeholder -->
  </div>
</div>
```

- Handout content (optional, for detailed notes) follows the slide:

```html
<div class="handout">
  <p>Detailed text that supports the assertion, intended for printed handouts or notes view.</p>
</div>
```
