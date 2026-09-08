---
paths:
  - "pr-*-review.md"
  - "pr-*-review-submission.md"
---

# Writing PR Review Comments

Applies when drafting comments destined for a GitHub PR review, by hand or
through the pr-review skill. Process and attribution live in that
skill; this covers what a comment must say and how it should read.

A review comment exists to get a change made. The PR author reads it once, in a
notification, next to the code. Write for that moment.

## Substance

- Every comment answers three things: what is wrong, why it matters, and what to
  do instead. A comment that stops after the first is a complaint, not a review.
- Anchor to the specific code. Name the file, line, identifier, or branch you
  mean — never "error handling could be improved".
- Do not restate what the diff already shows. The author knows what they wrote;
  tell them something they don't know.
- Assert only what you have verified. When you suspect a problem but cannot
  confirm it, ask a real question ("what happens here if `token` is expired?")
  rather than dressing a guess up as a finding.
- Critique the code, not the author. Say "this drops the error" — not "you
  forgot to handle the error", and never speculate about intent or skill.
- Say the important thing first. If a comment has a blocking concern and a
  stylistic aside, the aside goes last or gets dropped.

## Form

- Favor concise clarity over stylish prose. No metaphors, no "unlock", "leverage",
  "supercharge", "10x", "footgun" — plain description beats color:

  > Bad: "This query is a bit of a footgun that could really bite us at scale."
  > Good: "This query has no LIMIT. On the production `events` table (~40M rows)
  > it will scan the whole table on every request."

- Use a bulleted or numbered list when a comment makes multiple related or
  sequential points; use prose for a single point.
- Include a concrete code snippet when requesting a specific change to a small,
  unambiguous section of code.
- Use short pseudocode when requesting a refactor or logic change spanning many
  lines — enough to convey the shape, not a full implementation.
- When external documentation informs the critique, link it as evidence.
- No praise padding. "Great work overall!" wrapped around a blocking finding
  buries the finding. Praise a specific thing when it is genuinely worth
  copying, or say nothing.

## Attribution

Comments posted to GitHub carry the AI-assistance attribution header defined in
[pr-review](../skills/pr-review/SKILL.md) — one line,
naming the human who reviewed and approved the comment. That skill is the single
source of truth for the exact wording; do not restate or vary it here.
