---
name: implement-change
description: >
  End-to-end path from a change request to implemented, verified code: reads
  the request from wherever it lives (a markdown file, a Jira ticket, a Notion
  page, a GitHub issue, or the prompt itself), runs the implementation-planner
  agent to draft an approach, runs it past the implementation-plan-reviewer
  agent for unnecessary complexity and missed detail, develops it into an
  agreed plan with the user, implements it, verifies it with the
  implementation-reviewer agent (which owns running the tests and linters),
  and offers both to open a pull request and to archive the plan and outcome
  to a Notion database of implementation artifacts. Invoked as
  /llm-tooling:implement-change, or when the user asks to "implement this",
  "build this feature", "work this ticket", "make this change", or "plan and
  implement".
metadata:
  author: llm-tooling
  version: 1.3.0
---

# Implement Change

Turn a change request into implemented, verified code. The **implementation-planner** agent drafts the approach, the **user** decides what gets built, you build it.

The plan is the product of the first half. A wrong plan costs more than a wrong line of code, so nothing is written until the user has approved one.

## How Each Turn Reads

This skill runs over many turns, and the user comes back to each one without the last in their head. Write every message so it can be acted on without scrolling up.

- **Open with where things stand**: the step, what just finished, what it produced. "Step 5 of 13: plan agreed, written to `implementation-plan-retry.md`." Let the plan file's checkboxes carry progress; do not retell the plan.
- **Close on the one thing you need.** When a turn waits on the user, its last line is that single ask: "Approve the plan, or say what to change."
- **Show what now works**, concretely — the test that passes, the command that runs — not a list of edits.
- **State an error as cause and fix**: "`test_retry.py:42` expected 3 attempts, got 1 — the policy never reaches `Client.__init__`." No "uh oh", no "there seems to be".
- **Hold tangents.** A second problem found mid-step waits until the step is done, then comes up once as its own question.
- **Show at most five items per list**, grouped and ranked; keep the rest for when they come up. The plan table, open questions, and review findings are the exception — show them whole.
- **Name the specific thing** — file, line, command, count — and size work in real units: "about 40 lines across 3 files", not "a moderate change". Say what you verified and what you inferred.
- **No preamble, recap, or sign-off**: no "Great question", "Let me…", "I've now done X, Y, and Z", "Let me know if…". No marketing words ("leverage", "seamless", "robust") and no idiom where the literal statement is as short.

A request to explain or walk through something gets the full explanation, under headers; it still opens with the answer and ends when done.

Before sending, read only the first and last lines. If they do not say where things stand and what happens next, rewrite them.

## 1. The Source

The request comes from one of the sources below. Find a remote source's tools with a `ToolSearch` keyword search for what the tool does, never a server prefix: MCP servers can be registered under any name.

- **The prompt itself** — the user describes the change inline.
- **A file** — a path to a markdown or text spec in the repo or on disk.
- **A Jira ticket** — an issue key or URL. Search `jira get issue`. Read the description, acceptance criteria, comments, and linked issues.
- **A Notion page** — a URL or page title. Search `notion page`.
- **A GitHub issue or discussion** — search `github issue read`.
- Anything else the user points at — a URL, a pasted transcript, a design doc.

Follow a link one level deep when the source leans on it — a ticket whose real content is in an attached doc. Say what you read.

If the server for a remote source cannot be resolved or reached, stop and say which one, with the error verbatim. Do not diagnose it and do not substitute a guess at the content — offer to work from text the user pastes in instead.

With no source at all, ask what the change is. Do not infer one from the repo state.

## 2. The Brief

Restate the request as a brief and show it:

- **Goal** — what is different when this is done.
- **Scope and non-goals** — especially anything the source mentions that you are *not* doing.
- **Constraints** — compatibility, deadlines, interfaces that cannot move, stated preferences.
- **Acceptance criteria** — how the user will judge it.
- **Assumptions** — every place you filled a gap the source left open, marked as yours.

Ask about anything undecided that changes the shape of the work, using `AskUserQuestion` where the choices are discrete. Ask nothing you can answer by reading the code — that is step 3's job.

A one-line change gets a one-line brief. Match the ceremony to the size.

## 3. Draft the Approach

Invoke the **implementation-planner** agent with the brief and the verbatim source text. It explores the codebase and returns findings with real file references, a recommended approach, ordered steps, a test strategy, risks, and open questions.

Always invoke it. The one exception is a change whose whole diff you can state in a sentence — then say you are skipping the planner and why.

## 4. Adversarial Plan Review

Before the user sees the plan, invoke the **implementation-plan-reviewer** agent with the brief, the verbatim source, and the current draft. It hunts for unnecessary complexity and missed detail, and returns `CLEAN` or `CHANGES REQUESTED` with findings marked blocking or non-blocking.

Revise the draft for each blocking finding and invoke it again with the revision, its previous findings, and your reason for each one you declined. Loop until it returns `CLEAN`, or after three rounds, whichever comes first. A non-blocking finding you decline, or a blocking one still standing at the cap, goes to the user in step 5 with the reviewer's reasoning — never drop one silently.

A finding that turns on a decision only the user can make is an open question, not a revision: carry it into step 5.

Skip this step only when step 3 skipped the planner.

## 5. Agree the Plan — Gate

**The user approves the plan before anything is written.**

Answer the planner's **Open Questions**, and any the plan review raised, first; nothing downstream is trustworthy while they are open. Ask them together, and never guess at one.

Then show the plan as ordered steps:

```
#   Step                                  Files                     Verified by
1   Add the retry policy type             src/http/policy.py        unit test, new
2   Thread it through the client          src/http/client.py        existing client tests
3   Default it in the config loader       src/config.py             unit test, new
4   Document the new setting              README.md                 —
```

Plus the approach in a sentence or two, the risks, anything the planner flagged as larger than the request implied, and any reviewer finding left standing from step 4.

Take free-form direction: reorder, split, drop, or add steps, change the approach, cut scope, push back on a risk. Where you disagree with a change, say so once with the reason, then do it.

Keep going until the user says the plan is right. Approval of one step is not approval of the plan.

Write the agreed plan to `implementation-plan-<slug>.md` — steps, approach, answered questions, and a checkbox per step. It is what makes an interrupted session resumable, and it is a planning artifact, not part of the change: never commit it. Mention it once.

## 6. Branch

Check the tree is clean; if it is not, say what is uncommitted and ask whether to proceed. Your commits should contain this change, not whatever was already in progress.

Branch from the up-to-date base, following the repo's existing branch naming. If the repo's instructions say it commits to its default branch, stay on it and say so.

## 7. Implement

Work the steps in order, keeping the plan file's checkboxes current. Follow the conventions in the repo's instruction files — the planner surfaced them.

Code, comments, docstrings, and docs describe the code as it now is. A comment can say why the code works this way, but not how it got there: no mention of this session, the plan, options you rejected, or what the code used to do. That history goes in the commit message and the PR.

Build what the plan says. A discovery that invalidates a step — the interface is not what it looked like, the change is twice the size, a dependency is missing — goes back to the user with what you found and what you propose instead. **Do not absorb a plan change silently**, and do not widen the work because you are already in the file.

## 8. Verify

Do not run the tests or linters yourself. Invoke the **implementation-reviewer** agent with the plan file path, the brief, and the base to diff against. It runs the suite and linters, judges the diff against the plan and scope, and holds the code and tests to the repo's style. It returns `SATISFIED` or `NOT SATISFIED` with findings marked blocking or non-blocking.

Fix every blocking finding, then invoke it again with its previous findings. Loop until it returns `SATISFIED`. Stop and bring the user its latest report when:

- a failure predates your change — the reviewer shows the evidence, and the user decides;
- a finding would change the agreed plan — that goes to the user, as in step 7;
- the same finding survives two fixes, or five rounds pass.

Where the change is observable in the running app rather than only in tests, exercise it yourself and say what you saw.

## 9. Review the Diff

Show `git diff` grouped by plan step, so the user can check the code against what they approved. Call out anything you changed that no step called for, and why, and any non-blocking reviewer finding you left unaddressed.

Get explicit approval before committing. If they want changes, go back to step 7; step 8 runs again before the next approval.

## 10. Commit

Use the **commit** skill (`/llm-tooling:commit`) — it decides what belongs in the commit and writes the message. Exclude the plan file.

## 11. Offer the Pull Request

Ask whether to open one. On yes, use the **pr-create** skill (`/llm-tooling:pr-create`), which pushes the branch and writes the description. **Never open a PR unprompted**, and never push before the user has said yes to one — say what is committed locally and stop.

## 12. Offer to Record in Notion

**Ask whether to archive this change to Notion** — the plan and what actually happened, kept where they outlive the session. Ask once, here, and take a no as a no. If the user already said at invocation whether they want it, honor that instead of asking again.

On yes, resolve the tools with `ToolSearch` (`notion page`). If the server is not connected or not authorized, say so in one line and go to step 13 — Notion being unavailable never blocks or undoes finished work.

**Find the database before creating one.** Search for a Notion database named **Implementation Artifacts**. Reuse it if it exists. If it does not, ask the user which page to create it under and get a yes before creating it — a second database on a near-miss name is worse than no record. Its properties:

| Property | Type | Value |
|---|---|---|
| Name | title | The change, as a person would refer to it |
| Date | date | Completion date |
| Repo | text | Repository name |
| Branch | text | The branch the work landed on |
| PR | url | Empty when no PR was opened |
| Source | text | The step 1 source — ticket key, URL, or "inline" |
| Status | select | `Merged`, `In review`, `Committed`, `Abandoned` |

**One page per change.** Write the record after the fact — it describes what happened, not what was planned:

- The brief from step 2.
- The plan as agreed, and every deviation from it with the reason.
- What changed: files and commit SHAs.
- Verification: what was run and the result, including anything skipped.
- Links: the source, the PR, the commits.
- Anything left open.

Show the page content and the property values before writing, then write it and report the URL. Never put a credential, token, or pasted secret in it, whatever the source contained.

Once the record exists it supersedes `implementation-plan-<slug>.md` — offer to delete the local file.

If the write fails, report the error verbatim and leave the local plan file in place. Do not retry into a half-written page.

## 13. Report

What was implemented, the commit SHAs, whether the suite passed at the final commit, the PR URL if one was opened, the Notion record URL if one was written, and anything from the plan you did not do, with the reason.

## Rules

- **The user approves the plan before any file is touched**, and approves the diff before it is committed.
- **Never invent a requirement the source does not carry.** A gap is an assumption you state in the brief or a question you ask — not a decision you bury in the code.
