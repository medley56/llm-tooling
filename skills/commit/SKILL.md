---
name: commit
description: >
  Decides what in the working tree belongs in a commit, writes a Conventional
  Commits message, and creates the commit locally. Invoked as /commit, or when
  the user asks to "commit this", "commit my changes", or "write a commit
  message". Excludes review and planning artifacts, and asks when the right
  contents are unclear. Never pushes.
metadata:
  author: llm-tooling
  version: 5.1.0
---

# Commit

Work out what belongs in this commit, write the message, make the commit. Invoking this skill is the authorization to commit — do not ask again unless something below says to.

## What Goes In

Survey the whole tree: `git status -sb`, `git diff`, `git diff --cached`, `git ls-files --others --exclude-standard`. What is already staged is a signal about intent, not the definition of the commit. If the tree is clean, say so and stop.

**Start from what this session did.** The files you created or edited to fulfill the user's request are the commit. Everything else is a question — a file this session never touched may belong, but assume nothing. With no session context to reason from, describe the groupings the tree suggests and let the user pick rather than guessing at changes you did not make.

Never commit these, even when staged:

- Review and planning artifacts — `pr-*-review.md`, fix plans, scratch notes, documents written to drive the work rather than ship with it.
- Credentials and private configuration — `.env`, keys, tokens.
- Build output, caches, editor and OS files.

Say which paths you excluded and why.

Ask when the answer is not obvious: unrelated units of work in one tree, a file that could be artifact or deliverable, a deliberate-looking staged subset that overlaps unstaged edits to the same files. A question costs less than an unwanted file in permanent history.

Stage by naming paths. **Never stage without naming a path** — `git add -A`, `git add .`, and a bare `git add -u` sweep in whatever else is sitting in the tree. A deletion stages like any other change: `git add <deleted-path>`, or `git rm <path>` if the file is still on disk. A rename stages as both paths. Then check `git diff --cached --stat` against the list you chose; if it does not match, fix the index before writing the message.

## When Not to Commit

Draft the message anyway and hand it to the user instead of committing when the repo's own context restricts commits, when a merge, rebase, cherry-pick, or bisect is in progress, or when HEAD is detached. On the default branch, ask first and offer to branch — unless the user has already said this repo commits to its default branch, in session or in repo instructions, in which case commit and say you did. Say which condition applies and what they can run themselves.

## Message

Conventional Commits:

```
<type>(<optional scope>): <description>

- <what changed>
```

Choose the type by what the change does — `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `build`, `ci`, `chore` — not by which directory moved; a docstring-only edit under `src/` is `docs`. Add a scope only when it clarifies. Keep the description imperative and lowercase with no trailing period, and the whole title under 72 characters. A breaking change takes `!` before the colon and a `BREAKING CHANGE:` footer — never leave one unmarked.

Body bullets wrap at 72 characters, one concrete change each, ordered by significance. Skip whitespace and import churn. A small change needs no body.

Describe what the diff shows. Give a reason only when the user gave you one this session; never reconstruct intent from the code.

## Commit

Show the message, then:

```bash
git commit -F - <<'MSG'
<message>
MSG
```

Use `-F`, never `-m` — `-m` mangles multi-line bodies and breaks on quotes and backticks.

Report the short SHA and branch. **Never push**, and never amend unless asked for an amend by name.

If the commit fails, the run ends there. Report what happened, leave the message on screen, and tell the user to re-run `/commit` once they have looked at the state. Never retry with `--no-verify` — the hook is the repo objecting. If a hook reformatted files, show what it rewrote; whether that goes into history is the user's call.
