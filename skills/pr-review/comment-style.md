# Comment Style

How a comment destined for a GitHub PR reads — review comments and replies
alike. General prose rules (plain register, no tech-marketing words, no
preamble) come from `.claude/rules/general-rules.md`; this covers what is
specific to review comments.

A review comment exists to get a change made. The author reads it once, in a
notification, next to the code. Write for that moment.

## Substance

- Every comment names what is wrong, where, and why it matters. What comes
  after that depends on the fix:
  - **Prescriptive** — only when the fix is simple, obvious, and objectively
    correct. State it in three sentences or less, then the motivation as
    briefly as it can be said.
  - **Problem statement** — everything else. Describe the problem precisely
    and leave the solution to the author; at most one sentence of possible
    high-level approach. Designing a complex fix during review spends the
    author's attention on a plan they did not choose.
- Long reasoning invites the author to reject the whole finding over one wrong
  step. Cut every detail the finding does not rest on.
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
- A code snippet either shows a prescriptive fix in place or points at the
  problem. It is never a sketch of a solution the author has not chosen.
- Link external documentation when it is the evidence for the critique.

Vague and specific, on the same finding:

> Vague: "This query is a bit of a footgun that could really bite us at scale."
>
> Specific: "This query has no LIMIT. On the production `events` table (~40M
> rows) it will scan the whole table on every request."

## Attribution

Posted comments and replies carry the attribution header defined in
[SKILL.md](SKILL.md), which is the single source of truth for its wording.
