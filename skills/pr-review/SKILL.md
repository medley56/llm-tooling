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
  version: 3.0.0
---

# PR Review

Review a pull request and post the result to GitHub. The **github-pr-reviewer** agent drafts the findings, the **user** decides which of them become comments, and nothing reaches GitHub until they have seen the final text of every one.

The workflow: check access → resolve the PR → draft findings → shape them into comments → iterate with the user → confirm → submit.

## 1. Input

From the user's request, take the PR identifier (number, URL, or branch — otherwise detect from the current branch), an existing review document path if they have one, a focus area, background context that should inform severity and tone, and a verdict preference if they already stated one. All optional.

## 2. GitHub Access

Resolve the GitHub MCP tools with `ToolSearch` — `select:mcp__github__pull_request_read,mcp__github__get_me`, plus a keyword search like `github pull request review comment` for the write side. Names vary by server version; resolve them rather than assuming. Newer servers expose a single `pull_request_review_write` with a `method` parameter (`create`, `submit_pending`, `delete_pending`) plus `add_comment_to_pending_review`; older ones expose separate `create_pending_pull_request_review` / `add_pull_request_review_comment_to_pending_review` / `submit_pending_pull_request_review` tools. Call `mcp__github__get_me` to confirm the server answers and to record the user's login for the attribution header.

Do this **before any other work** — a user who cannot post the review should not first sit through an iteration loop.

If MCP cannot be resolved or reached, stop and hand the decision to the user. Do not diagnose it, and do not fall back on your own:

> GitHub MCP is unavailable — <the error, verbatim>. This is usually a stale MCP auth token; refreshing it is the fastest fix. If you would rather run this review through the `gh` CLI, say so and I will use it.

Then wait. The `gh` CLI is used **only** on explicit approval in this session; approval does not carry to a later run. If `gh` then turns out to be missing or unauthenticated, say so in one line, name `gh auth login`, and stop. Do not troubleshoot it or try alternative auth paths.

If read tools resolve but no write tool does, say so up front, then continue — the user still gets a finished review document to paste.

## 3. Resolve the PR

Record owner, repo, number, head and base branch, head SHA, and author. If no PR can be resolved, stop and ask for a valid identifier.

Two checks that change what happens later:

- **Self-review** — if the PR author matches the login from step 2, GitHub will reject an approval. Say so now; the verdict in step 7 is limited to `COMMENT`.
- **Existing comments** — fetch them. Findings that duplicate feedback already on the PR are dropped by default in step 5, but tell the user what was dropped so they can override.

## 4. Draft the Findings

**Always invoke the github-pr-reviewer agent.** It encodes the review criteria, convention-reading, and severity calibration this workflow depends on, and it reads the PR from GitHub rather than from whatever is on disk. Never hand-write findings, and never substitute a review document for running it.

Pass it the PR identifier, the focus area, and the context from step 1. It produces `pr-<number>-review.md` — findings organized by concept, each with a severity of `critical`, `warning`, `suggestion`, or `nitpick`. Wait for it to finish, then read its output.

If the user supplied a review document, or one already exists at the repo root, it is **input, not a substitute**: read it, pass its substance to the agent as additional context, and tell the user their file will be regenerated so nothing they hand-wrote is lost silently. Merge any of their findings the agent did not independently reach into the working list, marked as theirs.

Parse the result into a working list, preserving each finding's concept, body, severity, and referenced locations.

## 5. Shape Findings Into Comments

Fetch the PR diff and changed-file list, and build the set of commentable positions first — **GitHub inline comments can only anchor to lines inside a diff hunk.**

For each finding:

- **Anchor** — `path`, `line`, `side` (`RIGHT` for added or context lines, `LEFT` for removed). Use `start_line`/`line` for a contiguous range. Confirm the line is inside a hunk; if it is not, the comment cannot be inline — mark it top-level and say why.
- **One comment per finding.** A concept spanning several files anchors at the most important location and references the rest as `path:line` in the body. Do not fan one finding out across every file it touches.
- **Body** — state the issue, why it matters, and what to do instead. Include a ```suggestion block only when the fix is a small, unambiguous, in-place edit on the commented lines. Comment prose follows `comment-style.md` in this skill directory — read it before drafting the first body.
- **Disposition** — `include` by default; `propose-drop` for nitpicks and anything duplicating an existing comment.

Also draft the **review summary body**: two to four sentences of overall assessment plus a severity tally.

## 6. Iterate With the User

This is where the review actually gets made. Show the working set as a compact table:

```
#   Severity    Location                      Disposition   Summary
1   critical    src/auth/tokens.py:48         include       Expired tokens return None but caller assumes str
2   warning     src/api/routes.py:112-130     include       Unbounded query in the list endpoint
3   suggestion  (top-level)                   include       Test coverage gap for the refresh path
4   nitpick     src/api/routes.py:12          propose-drop  Import ordering
```

Then the summary body. Take free-form direction and act on it: drop and restore comments, rewrite or retone a body, change a severity, re-anchor between locations or to top-level, split a broad finding, merge overlapping ones, add a comment the document did not contain, or explain the reasoning behind one so the user can judge it. When the user asks for a new comment, read the code at that location first — never write a comment about code you have not looked at.

Show the updated table after each round and keep going until the user says they are done. Reach for `AskUserQuestion` only when a decision genuinely blocks and they have no stated preference; walking findings one at a time is slower than the table.

After every round, write the current state to `pr-<number>-review-submission.md` — every comment's final text, anchor, and disposition, plus the summary body, marked as an unposted draft. This is what makes an interrupted session resumable. Mention the file once, on the first write.

Before leaving the loop, re-validate every included anchor against the diff; the user may have moved comments during iteration.

## 7. Attribution and Verdict

Every posted comment — each inline one and the summary — begins with a single attribution line, then a blank line, then the body:

```
🤖 AI-assisted comment, reviewed and approved by @<github-login> before posting.

<comment body>
```

The login is the person submitting, who is accountable for the content. Apply it to every comment without exception, including ones the user wrote themselves — the header describes how the review was produced. Never stack it twice. The user may reword it, but may not remove the attribution or the 🤖 emoji; posting AI-assisted comments as if they were unassisted misrepresents their provenance to the author. If asked to drop it, decline briefly and offer to reword.

Then ask for the verdict unless the user already stated one. Recommend based on the final severity mix, but they decide:

- **COMMENT** — feedback without approval or block. The safe default.
- **REQUEST_CHANGES** — recommend when any included comment is `critical`.
- **APPROVE** — recommend only when nothing included is `critical` or `warning`. Unavailable on your own PR.

## 8. Confirm

Show exactly what will be posted: the verdict, the full summary body with its header, and every inline comment as `path:line` plus final text. Close with the count — "N inline comments + 1 summary, submitted as \<VERDICT\> on PR #\<number\> in \<owner\>/\<repo\>."

**Do not post without an unambiguous yes.** Silence, an ambiguous reply, or an unrelated one means do not post. If the user declines, leave the draft file and tell them re-running the skill resumes from it.

## 9. Submit

Post as a **single review**, never a series of standalone comments — one review posts atomically, notifies the author once, and carries the verdict.

Re-read the PR first. If the head SHA moved since step 3, the author pushed mid-iteration and anchors may be stale: say so, re-validate against the new diff, and re-confirm.

Then create the pending review, add each inline comment with its path, line, side, and final body, and submit with the verdict and summary.

When something fails:

- **One comment rejected** — usually a bad anchor. Do not abandon the review. Say which one and why, offer to re-anchor it, convert it to top-level in the summary, or drop it, and continue with the rest.
- **Pending-review creation fails** — stop and report the error verbatim. Never fall back to posting standalone comments; that scatters the review across the PR timeline.
- **Submission fails after comments were added** — a pending review now exists, populated but unsubmitted. Say so explicitly and offer to retry or delete it. Never leave the user unaware of a dangling pending review.

## 10. Report

Give the review URL, verdict, and comment count. Update `pr-<number>-review-submission.md` to a record of what was posted: timestamp, verdict, URL, final state of each comment, and anything not posted — dropped comments, ones converted to top-level after an anchor failure — so the record is complete.

On failure, report which step broke, the exact error, the GitHub-side state (no review, dangling pending review, partially submitted), and what the user can do next. Leave the draft file intact.

## Rules

- **The user is the reviewer of record.** This skill drafts and organizes; they decide what gets posted and are accountable for it.
- **Explicit approval gates every write to GitHub.** Approval to draft is not approval to post, and approval for one submission does not carry to a later one.
- **Attribution is non-negotiable.** The wording is adjustable; the disclosure is not.
- **MCP first.** Never call the GitHub API by other means, and never reach for `gh` unasked.
- **Never invent findings.** Comments come from the review document or explicit user direction.
- **Do not edit source files.** Two files are written: the reviewer agent's `pr-<number>-review.md` and this skill's `pr-<number>-review-submission.md`. Nothing else.
- **Be honest about severity.** Do not inflate a nitpick to look thorough or soften a critical finding to keep things pleasant. If the user downgrades a critical finding, do it — their review — but say once, plainly, what the risk is.
- **Inline where it helps.** A comment on the code beats a summary paragraph, but never force an anchor outside the diff just to make one inline.
