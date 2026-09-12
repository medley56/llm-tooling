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
  version: 1.1.1
---

# PR Fix

Turn reviewer feedback into pushed changes and answered threads. The **github-pr-fix-planner** agent reads the comments and plans the response; the **user** decides which fixes happen; you implement, verify, and reply.

Not every comment becomes a code change. Some are questions, and some are wrong — a reasoned reply is a complete response.

## 1. Input

From the user's request: the PR identifier (number, URL, or branch — otherwise detect from the current branch), any scope limit ("just the comments from @alice", "only the blocking ones"), and context that should inform the fixes. All optional.

One option changes the shape of the workflow:

- **Plan review** — **on by default.** Step 6 stops for the user to approve the plan before any code is touched. Turn it off only when they say so explicitly at invocation — "don't make me review the plan", "just apply the fixes", "skip the gate". Not mentioning it is not permission, and neither is a plan that looks obvious.

## 2. GitHub Access

Resolve the MCP tools with `ToolSearch` — `select:mcp__github-mcp__pull_request_read,mcp__github-mcp__get_me`, plus a keyword search like `github pull request review comment reply` for the reply side. Names vary by server version. Call `mcp__github-mcp__get_me` to confirm the server answers and to record the user's login for attribution.

Do this **before any other work** — a user whose replies cannot be posted should know before anything is implemented.

If MCP cannot be resolved or reached, stop. Do not diagnose it, and do not fall back on your own:

> GitHub MCP is unavailable — <the error, verbatim>. This is usually a stale MCP auth token; refreshing it is the fastest fix. If you would rather run this through the `gh` CLI, say so and I will use it.

Then wait. `gh` is used **only** on explicit approval in this session, and approval does not carry to a later run. If `gh` is missing or unauthenticated, say so in one line, name `gh auth login`, and stop.

## 3. Resolve the PR and the Working Tree

Record owner, repo, number, head and base branch, head SHA, and author. If no PR resolves, stop and ask for a valid identifier.

- **The PR's head branch must be checked out.** If `git branch --show-current` does not match, stop and say which branch to check out.
- **Uncommitted changes** — if the tree is dirty, say what is uncommitted and ask whether to proceed. Your commits should contain the fixes, not whatever was already in progress.
- **The remote may have moved.** `git fetch origin <head>`; if the remote branch is ahead, the author pushed since you last looked. Pull before anything else.

## 4. Rebase onto the Base Branch

The base branch may have moved while the review sat. `git fetch origin <base>`; if the head branch is behind, rebase it onto `origin/<base>`. Conflicts stop the skill — report the files and hand them to the user rather than resolving or `--skip`ping them.

**Do not push the rebase.** Step 10 pushes it together with the fixes.

## 5. Plan the Response

Invoke the **github-pr-fix-planner** agent with the PR identifier and the context from step 1. It fetches every unresolved comment, reads the code around each one, applies the repo's conventions, and returns a plan sorting comments into **Clear Actions**, **Discussion-Only**, and **Needs Clarification**.

If step 4 rebased, say so — the comment line numbers it reads from GitHub may not match the local files.

Always invoke it — never fetch and triage comments by hand.

## 6. Review the Plan With the User — Default Gate

**The user approves the plan before implementation begins**, unless they explicitly waived the gate in step 1.

Answer the **Needs Clarification** questions first — nothing downstream is trustworthy while they are open. Ask them together, using `AskUserQuestion` where the choices are discrete. Never guess at an ambiguous comment or implement anything depending on an unanswered one. **These questions are asked even when the gate is waived** — the planner raised them precisely because they cannot be resolved from the code.

Then show every comment as a table with a proposed disposition:

```
#   Thread                        Reviewer   Type        Disposition   Plan
1   src/auth/tokens.py:48         @alice     bug fix     fix           Return the expiry error instead of None
2   src/api/routes.py:112         @alice     refactor    fix           Extract the pagination branch
3   src/api/routes.py:12          @bob       question    reply         Explain why the import order is pinned
4   src/models.py:88              @bob       logic       decline       Behavior is required by the spec — reply with the reference
```

Dispositions are **fix**, **reply** (answer, no code change), and **decline** (disagree or out of scope — still gets a reply saying so and why). Take free-form direction: change a disposition, adjust an approach, split a comment into several changes, ask why something was classified as it was. **Declining is a legitimate outcome** — a reviewer can be wrong or working from stale context. Say so plainly when you think a comment should be declined, and give the reason.

Keep going until the user says the dispositions are right. **Nothing is implemented before they do**, and a reply about one thread is not approval of the rest.

If the gate was waived, still print the table before starting so the user can interrupt, then proceed with the planner's dispositions. Where you disagree with one, say so in a line rather than silently implementing it.

## 7. Implement

Work one thread at a time, in table order, so each change stays traceable to the comment that prompted it. Follow the conventions the planner surfaced.

Change only what the comment calls for. A reviewer asking for a rename has not asked you to restructure the module.

If a fix turns out to be wrong, impossible, or much larger than the plan implied, stop and say so. That comment goes back to the user for a new disposition.

## 8. Verify

Run the tests and linters the repo's instruction files or config name, not a guess. In a Python repo, use the **pytest-runner** agent. Run the full suite unless it is prohibitively slow, in which case run everything touching the changed code and say what you skipped.

**Failures block the push.** Report them with output. Fix what your changes caused; for a failure that predates them, say so, show the evidence, and let the user decide whether to proceed.

## 9. Review the Diff

Show `git diff` grouped by the thread each hunk answers, so the user can check the response against the request. Call out anything you changed that no comment asked for, and why.

Get explicit approval before committing. If the user wants changes, go back to step 7.

## 10. Commit and Push

Commit the approved work — one commit per thread when the fixes are independent, a single commit when they are one coherent change. Use the repo's existing message style. Describe what changed, not that a reviewer asked for it.

Then push to the PR's head branch. Where step 4 rebased it, the push is not a fast-forward: say so, get an explicit yes, and use `--force-with-lease`, which refuses if the remote moved since you fetched. **Never plain `--force`**, and never push to the base branch.

If the push is rejected anyway, the author pushed while you worked. Stop and let the user choose how to reconcile — do not rebase, merge, or force anything on your own.

Report the pushed commit SHAs.

## 11. Reply on Each Thread

Every dispositioned comment gets a reply on its own thread, so the reviewer sees the response in context. A reply is a PR comment: read `.claude/skills/pr-review/comment-style.md` before drafting replies, and end each one with the attribution line it defines. A reply carries no severity line.

- **Fixed** — what changed and where, with the commit SHA. Not "done."
- **Reply** — the answer, at the length the question deserves.
- **Declined** — what you are not changing and why, without hedging into a fake apology. If it is a judgment call, say that and leave the thread open.

Show every reply in final form and get an unambiguous yes before posting. **Silence or an ambiguous answer means do not post.**

Do not resolve threads — that is the reviewer's call. Offer it only if the user asks.

If a reply fails to post, report which thread and why, and keep the remaining replies going.

## 12. Report

Give the pushed SHAs, the count of threads fixed, replied, and declined, and any comment left unaddressed with the reason. Note whether the suite passed at the pushed commit.

## Rules

- **The user decides what gets fixed.** No code change and no reply happens without their say-so.
- **Never plain `--force`, and never push to the base branch.** `--force-with-lease` after the step 4 rebase, with the user's yes, is the only force.
- **Never claim a fix you did not verify.** "Fixed in abc123" is a factual claim about tested code.
