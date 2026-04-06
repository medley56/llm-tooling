---
name: markdown-to-slidy
description: >
  Converts a markdown document into a W3C Slidy2 HTML presentation using the
  Assertion-Evidence slide design methodology. Use when the user asks to "convert
  markdown to slides", "create a presentation from markdown", "make a Slidy
  presentation", "turn this document into slides", or provides a .md file and asks
  for a slide deck. Do NOT use for PowerPoint, Google Slides, or other non-Slidy
  formats.
metadata:
  author: llm-tooling
  version: 1.0.0
---

# Markdown to Slidy Presentation

Convert a markdown document into a W3C Slidy2 HTML presentation following the Assertion-Evidence slide design methodology.

## Instructions

The user provides a path to a markdown file and optionally an output path. If no output path is given, write the HTML file in the same directory as the input with a `.html` extension.

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

Present a numbered slide outline to the user for approval. Each entry must be a complete assertion sentence — the headline that will appear on that slide.

Example:

> I've analyzed your document and propose the following slide deck:
>
> 1. **Title:** "Migrating to Event-Driven Architecture" — Author, Date
> 2. The legacy system handled 10K requests/second but could not scale further
> 3. Event-driven architecture decouples producers from consumers
> 4. Three microservices replaced the monolithic request handler
> 5. Throughput improved 3.2x with no increase in infrastructure cost
>
> Would you like to adjust any slides, reorder them, or add/remove content?

CRITICAL: Wait for the user's approval or adjustments before proceeding to Step 3.

### Step 3: Handle Visualizations

Review the approved outline and identify any slides where a visual (diagram, chart, process flow) would genuinely help explain the concept better than text alone. Collect all such candidates and ask the user in a single batch:

> The following slides may benefit from visualizations:
>
> - **Slide 4:** A diagram showing the three microservices and their message queue connections
> - **Slide 7:** A chart comparing latency before and after migration
>
> For each, I can add a clearly marked placeholder that you can replace with an actual image later or I can generate an SVG visualization based on your description. Which (if any) would you like me to include? If you want me to generate an SVG, please provide a detailed description of the visual you have in mind for each slide.

If no slides need visualizations, skip this step entirely. Do not suggest visualizations unless they would genuinely improve communication of the content.

### Step 4: Generate HTML

1. Read the template at `assets/template.html` (relative to this skill's directory)
2. Replace the `{{TITLE}}`, `{{AUTHOR}}`, `{{DATE}}`, and `{{YEAR}}` placeholders with actual values
3. Generate a slide div block for each approved slide
4. Write the complete HTML file to the output path using the Write tool

### Step 5: Summarize

Report to the user:
- Total slide count
- Output file path
- Any visualization placeholders that need replacement (list slide numbers and descriptions)
- Suggest opening the file in a browser to preview

## Assertion-Evidence Rules

Every content slide MUST follow the Assertion-Evidence format. This is non-negotiable.

### Headlines Must Be Assertions

The heading on each slide must be a complete sentence that states the slide's key point — an assertion, not a topic label.

| Bad (topic phrase) | Good (assertion sentence) |
|---|---|
| "Performance Results" | "Response times improved 3x after the migration" |
| "System Architecture" | "Three loosely coupled services replaced the monolith" |
| "Cost Analysis" | "Annual infrastructure costs dropped 40% despite higher throughput" |
| "Background" | "The legacy batch system could not meet real-time processing demands" |

### Body Must Be Visual Evidence

The area below the headline provides visual evidence supporting the assertion. Prefer these formats in this order:

1. **Key number or metric** — a single large, bold figure (use the `key-point` class)
2. **Table** — for comparisons, before/after data, feature matrices
3. **Code snippet** — for technical presentations (max 15 lines per slide)
4. **Column layout** — two or three short items side by side (use the `columns` class)
5. **Visualization (or placeholder)** — only when approved by the user in Step 3

### What to Avoid

- **Bullet lists as slide body.** If you find yourself generating a bullet list as the main slide content, stop and restructure. Convert to a table, split across slides, or use a column layout instead.
- **If bullets are truly unavoidable**, limit to 3 items maximum, each under 8 words. This should be rare.
- **Large text blocks.** No slide should have more than 3 short lines of body text. Move detailed prose to handout blocks.
- **Decorative visuals.** Never add clip art, stock photos, or decorative images. Every visual must directly support the assertion.

## Visualization Policy

- **Default to no visualizations.** Most concepts can be communicated with text, tables, or key numbers.
- **Never use clip art or stock imagery.** No decorative graphics.
- **Suggest placeholders only when necessary** — architecture diagrams, data charts, process flows, or similar visuals that genuinely cannot be replaced by text.
- **Always ask the user** before adding any placeholder (Step 3).
- **Placeholder format:** Use the `placeholder` CSS class with `data-viz-type` (diagram, chart, graph, screenshot, or photo) and `data-viz-description` attributes. The visible text inside should read `[PLACEHOLDER: Human-readable description]`. See `assets/template.html` for the exact markup and styling.
- **Generate SVG visualizations if specifically requested** - If the user specifically asks for a diagram or chart, I can generate an SVG directly in the HTML or as a separate SVG file that is included in the HTML. Complex visualization should always be generated in separate SVG files to keep the HTML clean and maintainable. The SVG should be well-structured with appropriate use of groups, classes, and IDs for styling and potential interactivity.

## Content Transformation Rules

### Headings

| Markdown | Slide treatment |
|---|---|
| `# H1` | Title slide or section divider slide |
| `## H2` | Individual content slide — rewrite heading as assertion sentence |
| `### H3` and deeper | Fold into parent slide's evidence, or promote to own slide if substantial |

### Bullet Lists

Do not reproduce bullet lists on slides. Transform them:
- **Short list (2-3 items):** Column layout with the `columns` class
- **Comparison list:** Convert to a table
- **Sequential steps:** Split into one slide per step, or use a numbered column layout
- **Long list (4+ items):** Group into categories and spread across multiple slides

### Code Blocks

- Render as preformatted text inside the `evidence` container
- Maximum 15 lines per slide
- If longer, split across slides with assertion headlines explaining each segment
- Use syntax context in the headline (e.g., "The handler validates input before queuing the event")

### Tables

- Convert directly to HTML table elements inside the `evidence` container
- Tables count as visual evidence — they pair well with assertion headlines
- For very wide tables, consider splitting columns across slides

### Prose Paragraphs

- Distill the key claim into the assertion headline
- Extract any data points, comparisons, or metrics for the evidence area
- Place the full paragraph text in a handout block after the slide for handout/notes mode

## HTML Output Constraints

- Output must be valid XHTML 1.0 Strict — self-closing tags, properly quoted attributes, no unclosed elements
- Use the exact CSS and JS references from the template (W3C-hosted Slidy2 + w3c-blue theme)
- Cap at approximately 20 content slides. If the source material would produce more, suggest splitting into multiple presentations and ask the user which sections to prioritize
- Every content slide follows the structure shown in `assets/template.html`: a slide div containing an assertion heading and an evidence container
- Handout content (optional, for detailed notes) follows each slide in a separate handout div

## Examples

Example 1: Technical document
User says: "Convert my architecture doc to a presentation"

Actions:
1. Read the markdown file
2. Identify sections on current system, proposed changes, and migration plan
3. Propose assertion-style outline (e.g., "The current monolith cannot scale beyond 10K concurrent users")
4. After approval, generate Slidy2 HTML with tables and key metrics as evidence
Result: HTML presentation file with W3C blue theme

Example 2: Poorly organized notes
User says: "Turn these meeting notes into slides"

Actions:
1. Read the markdown file
2. Identify that the document lacks clear structure — mixed topics, no headings
3. Ask the user: "These notes cover several topics without clear organization. What are the 3-4 key takeaways you want to present?"
4. After user guidance, propose an outline and proceed
Result: Organized presentation distilled from unstructured notes

## Troubleshooting

Slides render without styling:
Cause: Browser cannot reach the W3C-hosted CSS/JS files (offline or firewall)
Solution: Download slidy.css, w3c-blue.css, and slidy.js to the assets/ directory and update the HTML references to use local paths

Too many slides generated:
Cause: Source document is very long
Solution: The skill caps at ~20 content slides. Ask the user which sections to prioritize or suggest splitting into multiple presentations.

Assertion headlines feel awkward:
Cause: Source headings are topic phrases, not claims
Solution: Rewrite each heading as a complete sentence that states the section's key finding or argument. If the source doesn't make a clear claim, ask the user what point they want to make.
