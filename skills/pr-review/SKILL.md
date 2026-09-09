---
name: pr-review
description: >
  End-to-end pull request review: pulls the current state of a PR, runs the
  github-pr-reviewer agent to draft findings, iterates with the user until the
  comment set is right, and posts the finished review to GitHub. Invoked as
  /pr-review, or when the user asks to "review this PR", "review and post
  comments", "submit a PR review", or "publish my review". Uses the GitHub MCP
  server; falls back to the gh CLI only with the user's explicit approval.
metadata:
  author: llm-tooling
  version: 3.0.1
---

# PR Review

Review a pull request and post the result to GitHub. The **github-pr-reviewer** agent drafts the findings, the **user** decides which become comments, and nothing reaches GitHub until they have seen the final text of every one.

## 1. Input

From the user's request: the PR identifier (number, URL, or branch — otherwise detect from the current branch), an existing review document, a focus area, context that should inform severity and tone, and a verdict preference. All optional.

## 2. GitHub Access

Resolve the MCP tools with `ToolSearch` — `select:mcp__github-mcp__pull_request_read,mcp__github-mcp__get_me`, plus a keyword search like `github pull request review comment` for the write side. Names vary by server version: newer ones expose a single `pull_request_review_write` with a `method` parameter (`create`, `submit_pending`, `delete_pending`) plus `add_comment_to_pending_review`; older ones expose separate `create_pending_pull_request_review` / `add_pull_request_review_comment_to_pending_review` / `submit_pending_pull_request_review`. Call `mcp__github-mcp__get_me` to confirm the server answers and to record the user's login for attribution.

Do this **before any other work** — never put a user who cannot post through an iteration loop.

If MCP cannot be resolved or reached, stop. Do not diagnose it, and do not fall back on your own:

> GitHub MCP is unavailable — <the error, verbatim>. This is usually a stale MCP auth token; refreshing it is the fastest fix. If you would rather run this review through the `gh` CLI, say so and I will use it.

Then wait. `gh` is used **only** on explicit approval in this session, and approval does not carry to a later run. If `gh` is missing or unauthenticated, say so in one line, name `gh auth login`, and stop.

If read tools resolve but no write tool does, say so now and continue — the user still gets a review document to paste.

## 3. Resolve the PR

Record owner, repo, number, head and base branch, head SHA, and author. If no PR resolves, stop and ask for a valid identifier.

- **Self-review** — if the author matches the login from step 2, GitHub rejects an approval. Say so now; step 7 is limited to `COMMENT`.
- **Existing comments** — fetch them. Findings that duplicate them are dropped in step 5; tell the user what was dropped so they can override.

## 4. Draft the Findings

**Always invoke the github-pr-reviewer agent.** Never hand-write findings, and never let a review document stand in for running it — the agent reads the PR from GitHub rather than from whatever is on disk.

Pass it the PR identifier, focus area, and context from step 1. It writes `pr-<number>-review.md`: findings organized by concept, each with a severity of `critical`, `warning`, `suggestion`, or `nitpick`. Wait for it, then read its output.

A review document the user supplied is **input, not a substitute**: read it, pass its substance to the agent as context, warn that their file will be regenerated, and merge findings the agent did not independently reach into the working list, marked as theirs.

Parse the result into a working list, preserving each finding's concept, body, severity, and locations.

## 5. Shape Findings Into Comments

Fetch the diff and changed-file list, and build the set of commentable positions first — **inline comments can only anchor to lines inside a diff hunk.**

For each finding:

- **Anchor** — `path`, `line`, `side` (`RIGHT` for added or context lines, `LEFT` for removed); `start_line`/`line` for a contiguous range. A line outside a hunk cannot be inline: mark it top-level and say why.
- **One comment per finding.** A concept spanning several files anchors at the most important location and references the rest as `path:line` in the body.
- **Body** — the issue, why it matters, and what to do instead. Include a ```suggestion block only when the fix is a small, unambiguous, in-place edit on the commented lines. Read `comment-style.md` in this skill directory before drafting the first body.
- **Disposition** — `include` by default; `propose-drop` for nitpicks and duplicates.

Also draft the **review summary body**: two to four sentences of overall assessment plus a severity tally.

## 6. Iterate With the User

Show the working set as a compact table:

```
#   Severity    Location                      Disposition   Summary
1   critical    src/auth/tokens.py:48         include       Expired tokens return None but caller assumes str
2   warning     src/api/routes.py:112-130     include       Unbounded query in the list endpoint
3   suggestion  (top-level)                   include       Test coverage gap for the refresh path
4   nitpick     src/api/routes.py:12          propose-drop  Import ordering
```

Then the summary body. Take free-form direction and act on it: drop and restore comments, rewrite or retone a body, change a severity, re-anchor between locations or to top-level, split a broad finding, merge overlapping ones, add a comment the document did not contain, or explain the reasoning behind one. Read the code at a location before writing a new comment about it.

Show the updated table after each round until the user says they are done. Reach for `AskUserQuestion` only when a decision genuinely blocks.

After every round, write the current state to `pr-<number>-review-submission.md` — every comment's final text, anchor, and disposition, plus the summary body, marked as an unposted draft. This is what makes an interrupted session resumable. Mention the file once, on the first write.

Before leaving the loop, re-validate every included anchor against the diff.

## 7. Attribution and Verdict

Every posted comment — each inline one and the summary — begins with a single attribution line, then a blank line, then the body:

```
🤖 AI-assisted comment, reviewed and approved by @<github-login> before posting.

<comment body>
```

The login is the person submitting, who is accountable for the content. Apply it to every comment, including ones the user wrote themselves, and never stack it twice. They may reword it but may not remove the attribution or the 🤖 — posting AI-assisted comments as if they were unassisted misrepresents their provenance. If asked to drop it, decline briefly and offer to reword.

Then ask for the verdict unless the user already stated one. Recommend based on the final severity mix, but they decide:

- **COMMENT** — feedback without approval or block. The safe default.
- **REQUEST_CHANGES** — recommend when any included comment is `critical`.
- **APPROVE** — recommend only when nothing included is `critical` or `warning`. Unavailable on your own PR.

## 8. Confirm

Show exactly what will be posted: the verdict, the full summary body with its header, every inline comment as `path:line` plus final text, and the count — "N inline comments + 1 summary, submitted as \<VERDICT\> on PR #\<number\> in \<owner\>/\<repo\>."

**Do not post without an unambiguous yes.** Silence, an ambiguous reply, or an unrelated one means do not post. If the user declines, leave the draft file and tell them re-running the skill resumes from it.

## 9. Submit

Post as a **single review**, never a series of standalone comments — one review posts atomically, notifies the author once, and carries the verdict.

Re-read the PR first. If the head SHA moved since step 3, the author pushed mid-iteration and anchors may be stale: say so, re-validate against the new diff, and re-confirm.

Then create the pending review, add each inline comment with its path, line, side, and final body, and submit with the verdict and summary.

- **One comment rejected** — usually a bad anchor. Do not abandon the review: say which one and why, offer to re-anchor it, convert it to top-level, or drop it, and continue with the rest.
- **Pending-review creation fails** — stop and report the error verbatim. Never fall back to standalone comments; that scatters the review across the PR timeline.
- **Submission fails after comments were added** — a populated but unsubmitted pending review now exists. Say so explicitly and offer to retry or delete it.

## 10. Report

Give the review URL, verdict, and comment count. Update `pr-<number>-review-submission.md` to a record of what was posted: timestamp, verdict, URL, final state of each comment, and anything not posted — dropped comments, ones converted to top-level after an anchor failure.

On failure, report which step broke, the exact error, the GitHub-side state (no review, dangling pending review, partially submitted), and what the user can do next. Leave the draft file intact.

## Rules

- **The user is the reviewer of record.** This skill drafts and organizes; they decide what gets posted and are accountable for it.
- **Do not edit source files.** Two files are written: `pr-<number>-review.md` and `pr-<number>-review-submission.md`. Nothing else.
- **Be honest about severity.** Never inflate a nitpick to look thorough or soften a critical finding to keep things pleasant. If the user downgrades a critical finding, do it — their review — but say once, plainly, what the risk is.
- **Inline where it helps.** A comment on the code beats a summary paragraph, but never force an anchor outside the diff just to make one inline.
