---
name: commit
description: >
  Decides what in the working tree belongs in a commit, writes the message, and
  creates the commit locally. Invoked as /commit, or when the user asks to
  "commit this", "commit my changes", or "write a commit message". Excludes
  review and planning artifacts, and asks when the right contents are unclear.
  Falls back to showing the message without committing when the repo's context
  says not to commit. Never pushes.
metadata:
  author: llm-tooling
  version: 4.0.0
---

# Commit

Work out what belongs in this commit, write the message, and make the commit locally. Invoking this skill is the user's authorization to commit — do not ask again unless something below says to.

What is already staged is a signal about intent, not the definition of the commit. Read the whole tree.

## Survey

Look at the whole working tree, not just the index:

- `git status -sb` — branch, in-progress operations, and the full picture of staged, modified, and untracked paths.
- `git diff --cached` and `git diff` — what the staged and unstaged changes actually do.
- `git ls-files --others --exclude-standard` — untracked files that are candidates for this commit.
- `git log --oneline -20`. If the repo follows a convention — Conventional Commits, a ticket prefix, a trailer, a consistent voice — match it and ignore the defaults below.

If the tree is entirely clean, say so and stop.

## Decide What Belongs in the Commit

**Start from what this session did.** The strongest signal is the work you just carried out: the files you created or edited to fulfill the user's request are the commit. Group them by what they accomplish and check the diffs match what you believe you changed.

Everything else in the tree is a question, not a given. A modified file this session never touched was changed by someone else or in earlier work — it may belong, but assume nothing. A file this session created as scaffolding rather than as the deliverable does not belong at all.

If you have no session context to reason from — a fresh session, or `/commit` invoked before any work — say so, describe the groupings the tree suggests, and let the user pick. Do not guess at authorship of changes you did not make.

**Never commit these, even when the user staged them:**

- Review and planning artifacts — `pr-*-review.md`, `pr-*-review-submission.md`, fix plans, scratch notes, design docs written to drive the work rather than ship with it. These exist to produce the change; they are not part of it.
- Anything that looks like a credential or private configuration — `.env`, key material, tokens, local connection strings.
- Build output, caches, editor and OS files, and dependency directories that the repo simply forgot to gitignore.

When you exclude something, say which paths and why. If an excluded artifact keeps reappearing, mention that gitignoring it would stop the recurrence — but do not edit `.gitignore` yourself.

**Stop and ask** when the answer is not obvious:

- The changes split into two or more unrelated units of work. Describe the groupings you see and let the user choose one, or ask them to confirm committing all of it together.
- Something staged looks unrelated to the rest, or something unstaged looks like it belongs.
- A file could plausibly be an artifact or a deliverable — a Markdown document in a docs repo, a fixture that might be test data or might be scratch output.
- The staged set is a deliberate-looking subset and unstaged changes touch the same files. Committing half a change is worse than asking.

Asking is cheap; an unwanted file in the permanent history is not. When in doubt, ask.

Stage exactly what you decided on with an explicit `git add <path>` for each file. **Never `git add -A`, `git add .`, or `git add -u`** — those sweep in whatever happens to be sitting in the tree, which is the failure this step exists to prevent. Then confirm with `git status -sb` that the index holds what you intended and nothing else.

## Decide Whether to Commit

Draft the message either way. Do **not** commit, and hand the message to the user instead, when:

- The repo's own context — `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, or the caller's instructions — restricts who or what may commit, or requires a step you cannot complete (sign-off, a ticket reference you do not have).
- A merge, rebase, cherry-pick, or bisect is in progress. Concluding one of those is the user's decision, and the staged tree is not theirs alone.
- HEAD is detached.

When the current branch is the repo's default branch (`main`/`master`), ask before committing rather than assuming. Offer to branch first.

In every one of these cases, say plainly which condition applies and what the user can run themselves.

## Write

Title, blank line, body.

- **Title**: imperative mood, under 50 characters, capitalized, no trailing period.
- **Body**: bullets (`- `), hard-wrapped at 72 characters, one concrete change each — the file, function, or behavior that changed. Order by significance. Skip whitespace and import churn unless that is all the diff contains. On a very large diff, group bullets into blank-line-separated blocks under the one title.

Describe what the diff shows. State a reason only when the user gave you one in this session; never reconstruct intent from the code. A guessed rationale in the permanent history is worse than none.

Plain text only. No markdown, no bold, no links.

## Commit

Show the message first, in an unlabeled code fence, so the user sees exactly what is being recorded. Then commit it by passing the message on stdin:

```bash
git commit -F - <<'MSG'
<message>
MSG
```

Use `-F`, never `-m`: `-m` mangles multi-line bodies and breaks on quotes and backticks in the text.

Report the short SHA and the branch. Then stop — **never** `git push`, and never `git commit --amend` unless the user asks for an amend by name.

If the commit fails, **the run ends there.** Report what happened, leave the message on screen so nothing is lost, and tell the user to re-run `/commit` once they have looked at the state. Do not retry, restage, or commit again in this run.

- **A hook rejected it** — report the hook's output verbatim. Never retry with `--no-verify`; the hook is the repo telling you something is wrong.
- **A hook reformatted files** — its changes are now sitting unstaged. Show what it rewrote. The user needs to see what a formatter did to their code before it goes into history, and that judgment is theirs — not something to resolve by restaging and trying again.
- **Anything else** — report the error verbatim.
