---
name: pr-fix
description: >
  End-to-end handling of review feedback on a pull request: pulls the PR's
  unresolved comments, runs the github-pr-fix-planner agent to plan a response
  to each one, walks the user through them, implements the approved fixes,
  verifies and reviews the result, pushes, and replies on each comment thread.
  Invoked as /pr-fix, or when the user asks to "address review comments", "fix
  the PR feedback", or "respond to my reviewer". Uses the GitHub MCP server;
  falls back to the gh CLI only with the user's explicit approval.
metadata:
  author: llm-tooling
  version: 1.0.0
---

# PR Fix

Turn reviewer feedback into pushed changes and answered threads. The **github-pr-fix-planner** agent reads the comments and plans the response; the **user** decides which fixes happen; you implement, verify, and reply.

The workflow: check access → resolve the PR → plan → walk the comments with the user → implement → verify → review the diff → push → reply on each thread.

Not every comment becomes a code change. Some are questions, and some are wrong — a reasoned reply is a complete response to a comment.

## 1. Input

From the user's request, take the PR identifier (number, URL, or branch — otherwise detect from the current branch), any scope limit ("just the comments from @alice", "only the blocking ones"), and context that should inform the fixes. All optional.

One option changes the shape of the workflow:

- **Plan review** — **on by default.** Step 5 stops and has the user approve the plan before any code is touched. Turn it off only when the user says so explicitly at invocation — "don't make me review the plan", "just apply the fixes", "skip the gate". Their not mentioning it is not permission to skip it, and a long or obvious-looking plan is not a reason to skip it either.

## 2. GitHub Access

Resolve the GitHub MCP tools with `ToolSearch` — `select:mcp__github__pull_request_read,mcp__github__get_me`, plus a keyword search like `github pull request review comment reply` for the reply-side tools. Names vary by server version; resolve them rather than assuming. Call `mcp__github__get_me` to confirm the server answers and record the user's login for the attribution header.

Do this **before any other work** — a user whose replies cannot be posted should know before implementing anything.

If MCP cannot be resolved or reached, stop and hand the decision to the user. Do not diagnose it, and do not fall back on your own:

> GitHub MCP is unavailable — <the error, verbatim>. This is usually a stale MCP auth token; refreshing it is the fastest fix. If you would rather run this through the `gh` CLI, say so and I will use it.

Then wait. The `gh` CLI is used **only** on explicit approval in this session; approval does not carry to a later run. If `gh` then turns out to be missing or unauthenticated, say so in one line, name `gh auth login`, and stop. Do not troubleshoot it or try alternative auth paths.

## 3. Resolve the PR and the Working Tree

Record owner, repo, number, head and base branch, head SHA, and author. If no PR resolves, stop and ask for a valid identifier.

- **The PR's head branch must be checked out.** If `git branch --show-current` does not match, stop and say which branch to check out. Never fix a PR from a different branch.
- **Uncommitted changes** — if the working tree is dirty, say what is uncommitted and ask whether to proceed. Your commits should contain the fixes, not whatever was already in progress.
- **The remote may have moved.** `git fetch origin <head>`; if the remote branch is ahead, the author pushed since you last looked. Pull before doing anything else.

## 4. Plan the Response

Invoke the **github-pr-fix-planner** agent with the PR identifier and the context from step 1. It fetches every unresolved comment, reads the code around each one, applies the repo's conventions, and returns a plan sorting comments into **Clear Actions**, **Discussion-Only**, and **Needs Clarification**.

Always invoke it — never fetch and triage comments by hand. It encodes the classification, ambiguity detection, and convention-reading this workflow depends on.

## 5. Review the Plan With the User — Default Gate

The planner has proposed a response to every comment. **The user approves that plan before implementation begins.** This is the gate; it is on unless they explicitly waived it in step 1.

Answer the **Needs Clarification** questions first — nothing downstream is trustworthy while they are open. Ask them together rather than one at a time, using `AskUserQuestion` where the choices are discrete. Do not guess at an ambiguous comment, and do not implement anything that depends on an unanswered one. **These questions are asked even when the gate is waived** — waiving a review is not answering a question, and the planner raised these precisely because they cannot be resolved from the code.

Then show every comment as a table with a proposed disposition:

```
#   Thread                        Reviewer   Type        Disposition   Plan
1   src/auth/tokens.py:48         @alice     bug fix     fix           Return the expiry error instead of None
2   src/api/routes.py:112         @alice     refactor    fix           Extract the pagination branch
3   src/api/routes.py:12          @bob       question    reply         Explain why the import order is pinned
4   src/models.py:88              @bob       logic       decline       Behavior is required by the spec — reply with the reference
```

Dispositions are **fix**, **reply** (answer, no code change), and **decline** (disagree or out of scope — still gets a reply saying so and why). Take free-form direction: change a disposition, adjust an approach, split a comment into several changes, ask why something was classified as it was. **Declining is a legitimate outcome** — a reviewer can be wrong or working from stale context. Say so plainly when you think a comment should be declined, and give the reason.

Keep going until the user says the dispositions are right. **Nothing is implemented before they do.** Do not begin a fix while the plan is still under discussion, and do not treat a reply about one thread as approval of the rest.

If the gate was waived, still print the table before starting so the user can see what is about to happen and interrupt, then proceed with the planner's dispositions. Where you disagree with one — a comment you would have declined — say so in a line rather than silently implementing it.

## 6. Implement

Work one thread at a time, in the order the table shows, so each change stays traceable to the comment that prompted it. Follow the conventions the planner surfaced from the repo's own instruction files.

Change only what the comment calls for. A reviewer asking for a rename has not asked you to restructure the module, and unrequested changes make the re-review harder than the original.

If a fix turns out to be wrong, impossible, or much larger than the plan implied, stop and say so rather than forcing it through. That comment goes back to the user for a new disposition.

## 7. Verify

Run the repo's tests and linters — the ones its instruction files or config name, not a guess. In a Python repo, the **pytest-runner** agent is the way to run the suite. Run the full suite unless it is prohibitively slow, in which case run everything touching the changed code and say what you skipped.

**Failures block the push.** Report them with output. If a failure is caused by your fix, fix it. If it predates your changes, say so, show the evidence, and let the user decide whether to proceed.

## 8. Review the Diff

Show `git diff` grouped by the comment thread each hunk answers, so the user can check the response against the request. Call out anything you changed that no comment asked for, and why.

Get explicit approval before committing. If the user wants changes, go back to step 6.

## 9. Commit and Push

Commit the approved work — one commit per thread when the fixes are independent, or a single commit when they are one coherent change. Write messages in the repo's existing style. Do not describe the change as being made because a reviewer asked; describe what changed.

Then push to the PR's head branch. **Never force-push** — it destroys the review history the reviewer is working from and can drop their commits. Never push to the base branch.

If the push is rejected as non-fast-forward, the author pushed while you worked. Stop, say so, and let the user choose how to reconcile — do not rebase, merge, or force anything on your own.

Report the pushed commit SHAs.

## 10. Reply on Each Thread

Every comment the user dispositioned gets a reply on its own thread, so the reviewer sees the response in context. Each reply opens with the attribution line, then a blank line, then the body:

```
🤖 AI-assisted comment, reviewed and approved by @<github-login> before posting.

<reply body>
```

Follow the comment-writing conventions in `rules/pr-review-comments.md` (installed at `.claude/rules/`) if the repo carries it; read it now if it has not loaded. A reply is a PR comment and holds to the same bar.

- **Fixed** — what changed and where, with the commit SHA. Not "done."
- **Reply** — the answer to the question, at the length the question deserves.
- **Declined** — what you are not changing and the reason, without hedging into a fake apology. If it is a judgment call, say that and leave the thread open for the reviewer.

Show every reply in final form and get an unambiguous yes before posting. **Silence or an ambiguous answer means do not post.**

Do not resolve threads. Marking a conversation resolved is the reviewer's call; offer it only if the user asks.

If a reply fails to post, report which thread and why, and keep the remaining replies going.

## 11. Report

Give the pushed SHAs, the count of threads fixed, replied, and declined, and any comment left unaddressed with the reason. Note whether the test suite passed at the pushed commit.

## Rules

- **The user decides what gets fixed.** The planner proposes and you implement, but no code changes and no replies happen without their say-so.
- **The plan gate is on unless explicitly waived.** Only the user waives it, only at invocation, and only for that run. Never infer a waiver from impatience, a small plan, or an earlier run.
- **Never force-push, and never push to the base branch.**
- **Ambiguity goes to the user.** Never guess at what a comment meant.
- **Fix what was asked, nothing more.** Unrequested changes buried in a fix commit are how re-reviews get missed.
- **Attribution is non-negotiable.** Every posted reply carries the 🤖 header. The wording is adjustable; the disclosure is not.
- **Never claim a fix you did not verify.** A reply saying "fixed in abc123" is a factual claim about tested code.
- **MCP first.** Never call the GitHub API by other means, and never reach for `gh` unasked.
