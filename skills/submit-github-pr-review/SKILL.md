---
name: submit-github-pr-review
description: >
  Turns a code review document into a posted GitHub pull request review through
  an interactive, user-driven approval process. Use when the user asks to
  "submit a PR review", "post my review comments to GitHub", "review this PR and
  post the comments", "turn this review into GitHub comments", or "publish the
  PR review". Builds on the github-pr-reviewer agent's output (or generates it
  first), iterates with the user finding-by-finding until the comment set is
  approved, then posts the review to GitHub with an AI-assistance attribution
  header on every comment. Requires the GitHub MCP server — never uses the gh CLI.
metadata:
  author: llm-tooling
  version: 1.0.0
---

# Submit GitHub PR Review

Turn a drafted code review into a real GitHub pull request review. The AI drafts and organizes; the **user** decides what gets posted. Every comment carries a one-line header disclosing that it was AI-assisted and human-reviewed.

The deliverable is a submitted GitHub review. Nothing is posted to GitHub until the user has seen the exact final text of every comment and explicitly approved submission.

## Instructions

### Step 1: Parse User Input

Extract from the user's request:

- **PR identifier** (optional) — a PR number (`#42`, `42`), full GitHub PR URL, or branch name. If absent, Step 4 detects it from the current branch.
- **Existing review document** (optional) — a path to a review markdown file the user wants to submit (e.g. `pr-123-review.md`). If absent, Step 3 finds or generates one.
- **Focus area** (optional) — an area of code or class of concern to weight more heavily.
- **Additional context** (optional) — background that should inform severity and tone.
- **Review verdict preference** (optional) — if the user already said "approve it" or "request changes", record it for Step 8; still confirm before submitting.

### Step 2: Verify GitHub MCP Access — Hard Gate

This skill uses the **GitHub MCP server exclusively**. Verify access **before** doing any other work, so the user never invests time in an iteration loop that cannot be submitted.

1. Use `ToolSearch` with `select:mcp__github__pull_request_read,mcp__github__get_me` (and a keyword search such as `github pull request review comment` for the write-side tools) to resolve the available GitHub MCP tools and their schemas.
2. Call `mcp__github__get_me` to confirm the server is reachable and authenticated, and to record the user's GitHub login for the attribution header (Step 7).

If GitHub MCP tools cannot be resolved, or calls fail with unreachable/unauthenticated errors, **STOP immediately**. Do not proceed to any later step. Do not fall back to the `gh` CLI. Do not draft comments the user cannot post. Return exactly:

> **STOP — GitHub MCP server unavailable.** This skill cannot access the GitHub MCP server tools required to read and post PR reviews. Configure and authenticate the GitHub MCP server, then run this skill again. Do not retry, work around, or fall back to the `gh` CLI.

The write-side tool names vary by GitHub MCP server version. Resolve the actual names via `ToolSearch` rather than assuming. Common shapes:

- **Newer servers**: `mcp__github__pull_request_review_write` (a single tool with a `method` parameter such as `create`, `submit_pending`, `delete_pending`) plus `mcp__github__add_comment_to_pending_review`.
- **Older servers**: `mcp__github__create_pending_pull_request_review`, `mcp__github__add_pull_request_review_comment_to_pending_review`, `mcp__github__submit_pending_pull_request_review`, `mcp__github__create_and_submit_pull_request_review`.

Record which write tools exist. If **read** tools are available but no **write** tool can be resolved, continue through the iteration loop but warn the user up front that the final submission step will not be possible, and offer to leave them a copy-pasteable review document instead.

### Step 3: Obtain the Review Document

The review document is the input to this skill, not its product. Get one in this priority order:

1. **User-provided path** — if the user named a file in Step 1, read it.
2. **Existing review file** — look for `pr-<number>-review.md` at the repository root. If found, check whether it is current: compare its modification time against the head commit date (`git log -1 --format=%cI`). If the file predates the newest commit on the branch, tell the user it may be stale and ask whether to regenerate or use as-is.
3. **Generate one** — invoke the **github-pr-reviewer** agent with the PR identifier, focus area, and additional context from Step 1. That agent produces `pr-<number>-review.md` organized by concept with severities. Wait for it to finish and read its output file.

Never hand-write findings from scratch when the reviewer agent is available — that agent encodes the review criteria, convention-reading, and severity calibration this skill depends on.

Parse the review document into a working list of findings, preserving for each: title/concept, body text, severity (`critical` | `warning` | `suggestion` | `nitpick`), and referenced files and line numbers.

### Step 4: Resolve the PR and Verify State

1. Resolve the PR via the GitHub MCP tools: by number/URL if provided, by head branch otherwise, else from `git branch --show-current`. Record owner, repo, PR number, head branch, base branch, head SHA, and PR author.
2. If no PR can be resolved, stop with a clear message asking for a valid PR number, URL, or branch.
3. **Self-review check** — compare the PR author against the login from `mcp__github__get_me`. GitHub does not allow approving your own PR. If they match, tell the user now, and note that the verdict in Step 8 will be limited to `COMMENT`.
4. **Existing comments** — fetch existing review comments via the GitHub MCP tools. Findings that duplicate feedback already on the PR are dropped by default in Step 5; note them so the user can override.

### Step 5: Map Findings to Comment Candidates

GitHub inline comments can only anchor to lines that appear in the PR diff. Fetch the PR diff and changed-file list via the GitHub MCP tools, and build the set of commentable positions before proposing anchors.

For each finding, produce a **comment candidate**:

- **Anchor** — `path`, `line`, and `side` (`RIGHT` for added/context lines in the new file, `LEFT` for removed lines). For a finding covering a contiguous range, set `start_line`/`line` for a multi-line comment.
- **Anchor validity** — confirm the chosen line falls inside a diff hunk for that file. If it does not, the comment **cannot** be inline. Mark the candidate as **top-level** and say why (e.g. "the affected function is outside the diff").
- **Multi-file findings** — a concept-level finding spanning several files becomes one inline comment anchored at the most important location, with the other locations referenced in the body as `path:line`. Do not fan a single finding out into near-duplicate comments on every file it touches.
- **Body** — rewrite the review-document prose into a comment a PR author will actually act on: state the issue, why it matters, and what to do instead. Include a concrete code suggestion (a ```suggestion block) only when the fix is a small, unambiguous, in-place edit on the commented lines.
- **Severity** — carried over from the review document; used for ordering and for the verdict recommendation in Step 8.
- **Default disposition** — `include` for critical and warning findings; `include` for suggestions; `propose-drop` for nitpicks and for anything duplicating an existing comment. The user overrides freely in Step 6.

Also draft the **review summary body**: 2–4 sentences of overall assessment, drawn from the review document's Summary, plus a short severity tally.

### Step 6: Interactive Iteration Loop

This is the core of the skill. The user drives; you draft, revise, and keep the state.

#### 6a: Present the working set

Show a compact numbered table of all candidates so the user can see the whole review at a glance:

```
#   Severity    Location                      Disposition   Summary
1   critical    src/auth/tokens.py:48         include       Expired tokens return None but caller assumes str
2   warning     src/api/routes.py:112-130     include       Unbounded query in the list endpoint
3   suggestion  (top-level)                   include       Test coverage gap for the refresh path
4   nitpick     src/api/routes.py:12          propose-drop  Import ordering
```

Then show the drafted review summary body.

#### 6b: Iterate

Invite free-form direction and act on it directly. Support at least:

- **Drop / restore** a comment (`"drop 4"`, `"put 4 back"`).
- **Edit wording** — rewrite a body, change tone, make it shorter, soften or sharpen it.
- **Change severity** — which affects ordering and the verdict recommendation.
- **Re-anchor** — move a comment to a different file/line, or convert between inline and top-level.
- **Split or merge** — break a broad finding into separate comments, or combine overlapping ones.
- **Add a new comment** the review document did not contain, at a location the user names. Read the code at that location before drafting it; do not write a comment about code you have not looked at.
- **Ask about a finding** — explain the reasoning, show the relevant code, and let the user judge.

Show the updated table after each round of changes. Keep going until the user says they are done.

Use `AskUserQuestion` when a decision is genuinely blocking and the user has not expressed a preference — for example, a finding whose anchor is invalid and could reasonably be top-level or dropped, or a candidate whose severity you cannot calibrate without knowing the team's norms. Do not use it to walk the user through findings one at a time; the table plus free-form direction is faster.

#### 6c: Persist the working draft

After each round, write the current state to `pr-<number>-review-submission.md` at the repository root. This file is the audit trail: it holds the exact final text of every comment, its anchor, its disposition, and the review summary body. If the session is interrupted, this file is what lets the work resume. Note in the file that it is a draft and has not been posted.

Tell the user this file exists after the first write, once — do not re-announce it every round.

#### 6d: Verify before proceeding

Before leaving the loop, re-validate every included inline anchor against the diff (the user may have re-anchored comments during iteration). Report any anchor that is no longer valid and resolve it with the user.

### Step 7: Apply the Attribution Header

Every comment posted by this skill — **each inline comment and the top-level review summary** — starts with a single attribution line as its first line, followed by a blank line, then the comment body:

```
🤖 AI-assisted draft, reviewed and approved by @<github-login> before posting.

<comment body>
```

Rules for the header:

- It is **one line**, it **begins with the 🤖 emoji**, and it is the **first line** of the comment body.
- `<github-login>` is the login returned by `mcp__github__get_me` in Step 2 — the person submitting the review, who is accountable for its content.
- Apply it to every comment, without exception, including comments the user wrote themselves during iteration. The header describes how the review was produced, and the review as a whole was AI-assisted.
- The user may reword the header text, but may not remove the attribution or the 🤖 emoji. If asked to drop it entirely, decline briefly: posting AI-assisted review comments as if they were unassisted misrepresents their provenance to the PR author. Offer to reword instead.
- Do not stack the header more than once on a comment. When re-editing a comment during iteration, keep exactly one header.

### Step 8: Choose the Review Verdict

Ask the user which verdict to submit, using `AskUserQuestion` unless they already stated one in Step 1:

- **COMMENT** — feedback without an explicit approval or block. The safe default.
- **REQUEST_CHANGES** — blocking. Recommend this when any included comment is `critical`.
- **APPROVE** — approving with comments. Recommend only when no included comment is `critical` or `warning`. Not available when the user is the PR author (Step 4.3) — GitHub rejects self-approval.

State a recommendation based on the final severity mix, but the user decides.

### Step 9: Final Confirmation Gate

Show the user exactly what will be posted, in final form:

- The review verdict.
- The full review summary body, with its attribution header, as it will appear.
- Every inline comment: `path:line`, plus the full final body with its attribution header.
- A count: "N inline comments + 1 summary, submitted as <VERDICT> on PR #<number> in <owner>/<repo>."

Then ask for explicit confirmation to post. **Do not post without an unambiguous yes.** Silence, an unrelated reply, or an ambiguous response means do not post. If the user declines, leave the draft file in place and tell them how to resume (re-run the skill; it will pick up `pr-<number>-review-submission.md`).

### Step 10: Submit the Review

Submit as a **single review**, not as a series of standalone comments — a single review posts atomically, notifies the PR author once, and can carry a verdict.

Using the write tools resolved in Step 2:

1. **Create a pending review** on the PR (`pull_request_review_write` with `method: "create"`, or `create_pending_pull_request_review`). Pass the review summary body if the tool accepts it at creation; otherwise supply it at submission.
2. **Add each inline comment** to the pending review (`add_comment_to_pending_review` / `add_pull_request_review_comment_to_pending_review`), passing `path`, `line` (and `start_line` for multi-line), `side`, and the final body including its attribution header.
3. **Submit the pending review** (`method: "submit_pending"` / `submit_pending_pull_request_review`) with the chosen verdict and the summary body.

Failure handling:

- **A single inline comment is rejected** (usually an invalid anchor — line not in the diff, or the head SHA moved): do not abandon the review. Report which comment failed and why, and offer to convert it to a top-level comment appended to the summary body, re-anchor it, or drop it. Continue with the rest.
- **Pending-review creation fails**: stop and report the error verbatim. Do not retry blindly, and do not fall back to posting standalone comments — that would scatter the review across the PR timeline.
- **Submission fails after comments were added**: a pending review now exists with comments attached but is not submitted. Say so explicitly, name the failure, and offer to retry submission or delete the pending review (`method: "delete_pending"` / equivalent). Never leave the user unaware of a dangling pending review.
- **The head SHA changed** since Step 4 (the author pushed mid-iteration): anchors may no longer be valid. Detect this by re-reading the PR before creating the pending review. If the SHA moved, tell the user, re-validate anchors against the new diff, and re-confirm before posting.

### Step 11: Report and Update the Draft File

On success:

- Report the review URL, the verdict, and the comment count.
- Update `pr-<number>-review-submission.md`: mark it **submitted**, record the timestamp, verdict, review URL, and the final posted state of each comment. It stops being a draft and becomes a record of what was posted.
- Note anything not posted (dropped comments, comments converted to top-level after an anchor failure) so the record is complete.

On failure: report which step failed, the exact error, the current GitHub-side state (no review / dangling pending review / partially submitted), and what the user can do next. Leave the draft file intact.

## Important Behavioral Rules

- **The user is the reviewer of record.** This skill drafts and organizes; the user decides what gets posted and is accountable for it. Never post a comment the user has not seen in final form.
- **Explicit approval gates every write to GitHub.** No pending review is created, no comment is added, and no review is submitted before the Step 9 confirmation. Approval to draft is not approval to post, and approval for one submission does not carry to a later one.
- **Attribution is non-negotiable.** Every posted comment starts with the one-line 🤖 header naming the human who reviewed and approved it. The wording is adjustable; the disclosure is not.
- **GitHub MCP only.** Never use the `gh` CLI, never shell out to `git push`-style workarounds, never call the GitHub REST API by other means. If MCP is unavailable, stop with the Step 2 message.
- **Never invent findings.** Comments come from the review document or from explicit user direction. When the user asks for a new comment, read the code at that location before drafting it.
- **Do not edit source files.** This skill reads code and writes exactly one file: the submission draft/record at the repository root.
- **Respect existing review comments.** Default to dropping findings that duplicate feedback already on the PR, and tell the user what was dropped so they can override.
- **Inline where it helps, top-level where it doesn't.** A comment anchored to code the author is looking at is far more useful than a summary paragraph — but never force an anchor onto a line outside the diff just to make a comment inline.
- **Be honest about severity.** Do not inflate a nitpick into a warning to make the review look thorough, and do not soften a genuine critical finding to keep the review pleasant. If the user asks to downgrade a critical finding, do it — it is their review — but say once, plainly, what the risk is.
- **One review, not a comment storm.** Always submit as a single review. Multiple standalone comments spam the PR author with notifications and lose the verdict.
- **Handle interruption gracefully.** The submission draft file is written after every iteration round precisely so that a lost session does not lose the user's work. On re-run, look for it and offer to resume from it.
