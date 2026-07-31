---
name: create-gauntlet-loop-prompt
description: >
  Interactively builds a "Gauntlet Loop" prompt — a goal-plus-quality-bar prompt
  that a coding agent runs as a builder/critic loop until the output matches or
  beats a reference standard. Use when the user says they want to "create a
  gauntlet loop", "run a gauntlet loop", "write a gauntlet prompt", "set the bar
  for a feature", or asks for help turning a vague feature idea into a
  requirements-driven agent prompt. Works for greenfield products and for
  changes to an existing codebase, with or without a reference implementation.
  Do NOT use to actually implement the feature — this skill produces the prompt,
  not the code.
metadata:
  author: llm-tooling
  version: 1.0.0
---

# Create Gauntlet Loop Prompt

Produce a prompt that sends a coding agent through a **Gauntlet Loop**: give it the *goal* and a *bar* it can inspect, let it split the work into independently judgeable pieces, and cycle each piece through a builder and a separate harsh critic until the output stops losing to the bar.

The prompt you generate is the deliverable. You are not implementing the feature.

## Why the bar is the whole job

A gauntlet loop only works as well as its bar. A vague bar ("make it great") lets the critic grade on a curve and the loop stops at "pretty good for AI." A bar made of implementation details ("use Redis, use a state machine") turns the loop into a compliance check and forecloses better solutions.

A good bar states **what must be true about the finished thing, observably, from the outside** — and gives the critic a concrete way to look.

Your hardest work in this skill is separating real requirements from implementation detail. Steps 3–5 are the tools for that. Do not skip them, and do not let the user hand you a list of technical tasks and call it a bar.

## Instructions

### Step 1: Establish the working context

Before asking the user anything, find out what kind of project this is. The answer changes every later step.

**Determine greenfield vs. existing codebase.** Check the working directory: is there source code, a `README.md`, a `CLAUDE.md`, a package manifest, a git history? If the user's request names an existing feature or file, it is brownfield.

**If brownfield, investigate before you ask questions.** Gather:

- `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `README.md` — project purpose, conventions, constraints
- Build/run/test commands — the critic will need these to inspect real output
- The subsystem the change touches, and its current behavior
- **Existing exemplars** — the module, page, or endpoint in this repo that is already built to the standard the user wants. This is often the best available bar.
- **Regression surface** — what currently works that must not break

**If greenfield**, note what exists to build on: language and runtime preferences, deployment target, whether anything has been scaffolded.

Summarize what you found in a few lines before moving on, so the user can correct you early.

### Step 2: Extract the goal, not the route

Get the user to state the **destination**. The test: a goal describes what is true for whoever uses the thing; a route describes how you get there.

Ask, skipping anything already clear:

1. **"When this works, what does someone do with it that they couldn't do before?"** — the goal in user terms
2. **"Who is that someone, and what do they compare it to today?"** — surfaces the bar candidate for free
3. **"What would make you say this shipped badly even though it technically works?"** — surfaces the real quality dimensions

If the user answers in implementation terms ("add a WebSocket layer", "migrate to Postgres"), climb the ladder: ask *why* until the answer stops being about mechanism and starts being about outcome. Stop at the last rung that is still falsifiable.

> "Use Redis" → why → "cache must survive restarts" → why → "cold start is under 2 seconds at p95"

The last rung is the requirement. Everything above it in the chain is implementation detail, and the loop should be free to solve it any way it likes.

Write the goal as one paragraph, no mechanism words. Confirm it with the user.

### Step 3: Find the strongest available bar

The bar must be something an agent can **actually inspect and compare its own work against**. Work down this ladder and take the highest rung that is real for this project:

| Rung | Bar source | Example |
|---|---|---|
| 1 | A running artifact the agent can operate and compare against | The competitor app, the production system, the previous version, the real game |
| 2 | A captured artifact | Screenshots, recorded sessions, a golden output set, an API response corpus, a design mockup |
| 3 | A reference implementation | A repo doing the same job well, a library's behavior, an RFC-conformant tool |
| 4 | An in-repo exemplar | The best-built module already in this codebase — "match the quality of `src/billing/`" |
| 5 | The thing being replaced | The manual process, the spreadsheet, the human doing it by hand. Very strong for internal tooling. |
| 6 | A constructed reference | Have the loop's first task be producing one slice by hand, expensively and carefully, then make that the bar for the rest |
| 7 | A written spec sheet with observable probes | Last resort — Step 4 makes this work |

Prefer a hybrid: a reference for the dimensions it covers, plus spec lines for the dimensions it does not. A reference implementation rarely covers everything (the real Call of Duty says nothing about your load times).

State the chosen bar sources explicitly, including how the agent reaches them (URL, path, command, screenshot directory). A bar the agent cannot open is not a bar.

**If there is no reference at all**, say so plainly and go to Step 4 — the spec sheet becomes the bar, and it has to be built to be inspectable.

### Step 4: Build the spec sheet

Turn the goal into a small set of dimensions the finished work is judged on. Aim for **5–9 dimensions**. More than that and the critic dilutes; fewer and it misses whole failure modes.

Draw candidate dimensions from what the user said made things "ship badly", from the reference artifact, and from the domain. Typical families: correctness, perceived quality/feel, performance, robustness under bad input, first-run experience, discoverability, fit with existing conventions, operability, accessibility.

Each dimension needs four things:

- **Requirement** — one observable statement about the finished thing. No mechanism.
- **Probe** — the concrete action the critic takes to see it. Run this command, open this page, feed this input, screenshot and A/B against the reference, run this benchmark on this hardware.
- **Losing looks like** — the specific failure the critic is hunting for. This is what stops grade inflation.
- **Priority** — P0 ship-blocking, P1 strong, P2 nice.

Force numbers wherever numbers exist. "Fast" is not a bar; "first paint under 400ms on a throttled 4G profile" is. "Smooth" is not a bar; "no frame over 16ms during a 30-second pan" is. When no number exists, the probe carries the weight: "a reviewer who has used the reference cannot tell which is which in a blind A/B."

Format it as a table:

| # | Dimension | Requirement (observable) | Probe | Losing looks like | Pri |
|---|---|---|---|---|---|

**Brownfield addition — the do-not-regress lines.** In an existing codebase, add explicit P0 lines for the behavior that must survive: the tests that must still pass, the API contracts that must not change, the performance that must not degrade. A gauntlet loop optimizes hard for what you named and is indifferent to what you didn't.

### Step 5: Stress the bar before you trust it

Run both tests on the draft spec sheet. This is the step that catches bad requirements, and it is worth doing out loud with the user.

**The cheat test — catches under-specification.**
Describe the laziest, most degenerate implementation that passes every line of the bar. Hardcode the demo values, handle only the happy path, make one screen beautiful and the rest bare.

- If that implementation would be *acceptable*, the bar is sound.
- If it would be *unacceptable*, the bar has a hole. Name what makes it unacceptable — that is a missing dimension. Add it and re-run the test.

**The over-constraint test — catches implementation detail in disguise.**
Imagine an implementation you would be delighted with, built in a way you did not anticipate. Walk the bar lines against it.

- If any line fails, that line is prescribing a route, not a destination. Rewrite it as the outcome it was protecting, or delete it.

Two supporting checks worth applying per line:

- **Substitution** — swap the implementation for a completely different one satisfying this line. Does anyone notice or care? If not, it is not a requirement.
- **Counter-example** — name a system that violates this line and is still considered good. If you can name one easily, it is a preference; demote it to P2 or cut it.

### Step 6: Name the boundaries and the anti-goals

Two lists, both short, both important.

**Constraints** — non-negotiable facts about the environment the loop must work inside. Must run in the browser. Must not change the public API. Must use the existing Postgres schema. Must stay under the current dependency set. These bound the search; they are not quality targets and the critic does not grade them, it rejects violations outright.

**Out of scope / do not optimize** — what the loop must *not* spend rounds on. A gauntlet loop will happily polish whatever the critic finds interesting. Naming the things you genuinely do not care about is how you keep the loop pointed at the goal. Ask the user directly: "What would you be annoyed to find the agent spent five rounds perfecting?"

### Step 7: Confirm the bar with the user

**CRITICAL: stop here and get approval before generating the prompt.**

Present:
- the one-paragraph goal
- the bar sources and how the agent reaches them
- the spec sheet table
- what the cheat test surfaced and how you closed it
- constraints and out-of-scope lists
- the proposed stop condition (Step 8)

Ask specifically whether the priorities are right and whether anything in the table is really an implementation detail. Revise until the user approves. Do not proceed on silence.

### Step 8: Choose the stop condition

The methodology says keep looping rather than stopping at an arbitrary point, but a real run needs a defined end. Offer these and let the user pick:

- **Convergence (default)** — stop when, for two consecutive rounds, the critic rates the work at or above the bar on every P0 and P1 line and cannot name a new gap above a trivial severity.
- **Budget** — a fixed number of rounds per piece, or a wall-clock or token ceiling, whichever comes first. Use when the user is cost-sensitive.
- **Checkpoint** — loop until convergence on P0 lines only, then return to the user before continuing on P1/P2.

Whichever is chosen, the prompt must forbid stopping because output is "good enough" or "impressive for an AI."

### Step 9: Assemble the prompt

Read `assets/prompt-template.md` (relative to this skill's directory) and fill it in from Steps 1–8. Consult `assets/examples.md` for a greenfield and a brownfield worked example if you need calibration on tone and specificity.

Keep the loop mechanics section intact — those instructions are what make it a gauntlet loop rather than a long feature request:

- Lead agent gets the goal and the bar, and **chooses its own approach**
- Lead agent splits the work into the **smallest pieces that can be improved and judged independently** — each piece must map to at least one bar line
- **Builder and critic are separate agents.** The critic gets fresh context and never sees the builder's self-assessment.
- The critic **inspects real output** — runs it, opens it, screenshots it — compares directly against the bar, **blind A/B where possible**, names **the single biggest remaining gap**, and sends it back.
- Keep looping to the stop condition. Never accept "good enough for AI."
- Maintain a **live progress document** so the run can be monitored without interrupting it.
- Optional **smoothing pass** at the end to align consistency across independently built pieces.

### Step 10: Write the output and hand it off

Write the prompt to `GAUNTLET-<slug>.md` in the working directory, where `<slug>` is a short kebab-case name for the goal, truncated to 32 characters.

Then tell the user:

- the output file path
- that the prompt is meant to be pasted into a **fresh agent session** with subagents available (and `ultracode` enabled if their harness supports it), not run in this conversation
- the bar sources the agent will need access to, and anything they must place on disk first (screenshots, reference repo checkout, credentials for the reference system)
- any dimension you were unable to make observable, so they know where the loop is weakest

## Rules

- **Produce the prompt, do not run it.** This skill ends with a file. If the user wants the feature built, that is a separate invocation in a fresh session.
- **Never accept a task list as a bar.** "Add caching, add retries, add tests" is a route. Climb to the outcome each item protects and put that in the spec sheet instead.
- **Every bar line needs a probe.** If you cannot say how a critic observes it, the line will be graded on vibes and the loop will stop early. Either find a probe or cut the line.
- **Never let the bar prescribe architecture.** The loop's value comes from the agent finding an approach you did not specify. Architecture belongs in Constraints only when it is genuinely non-negotiable.
- **Always run the cheat test.** It is the single highest-yield step in this skill. Report what it surfaced.
- **Brownfield always gets do-not-regress lines.** An unstated regression is an unprotected one.
- **Investigate the codebase before asking questions.** Do not ask the user what you can read. Ask them what only they know: intent, priorities, what "bad" looks like.
- **Keep the spec sheet to 5–9 dimensions.** If more seem necessary, the goal is too big — suggest splitting it into two gauntlet loops.
- **Stop for approval at Step 7.** The bar is the deliverable's foundation; generating a prompt on an unconfirmed bar wastes an entire run.
- **Be honest about a weak bar.** If the best available bar is a spec sheet with soft probes, say so in the handoff rather than dressing it up.
