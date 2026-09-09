# Comment Style

How a comment destined for a GitHub PR reads — review comments and replies
alike. General prose rules (plain register, no tech-marketing words, no
preamble) come from `.claude/rules/general-rules.md`; this covers what is
specific to review comments.

A review comment exists to get a change made. The author reads it once, in a
notification, next to the code. Write for that moment.

## Substance

- Answer three things: what is wrong, why it matters, and what to do instead. A
  comment that stops after the first is a complaint, not a review.
- Anchor to the code you mean — file, line, identifier, branch. Never "error
  handling could be improved".
- Do not restate what the diff already shows. Tell the author something they do
  not already know.
- When you suspect a problem but cannot confirm it, ask a real question ("what
  happens here if `token` is expired?") instead of asserting a finding.
- Critique the code, not the author: "this drops the error", not "you forgot to
  handle the error". Never speculate about intent or skill.
- Blocking concerns come before stylistic ones. An aside that cannot survive
  being last gets dropped.

## Form

- Use a bulleted or numbered list when a comment makes several related or
  sequential points; prose for a single point.
- Include a concrete code snippet when requesting a specific change to a small,
  unambiguous section of code.
- Use short pseudocode when the request spans many lines — enough to convey the
  shape, not an implementation.
- Link external documentation when it is the evidence for the critique.

Vague and specific, on the same finding:

> Vague: "This query is a bit of a footgun that could really bite us at scale."
>
> Specific: "This query has no LIMIT. On the production `events` table (~40M
> rows) it will scan the whole table on every request."

## Attribution

Posted comments and replies carry the attribution header defined in
[SKILL.md](SKILL.md), which is the single source of truth for its wording.
