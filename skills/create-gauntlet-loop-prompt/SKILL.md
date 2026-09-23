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
  version: 1.0.1
---

# Create Gauntlet Loop Prompt

Produce a prompt that sends a coding agent through a **Gauntlet Loop**: give it the *goal* and a *bar* it can inspect, let it split the work into independently judgeable pieces, and cycle each piece through a builder and a separate harsh critic until the output stops losing to the bar.

The prompt you generate is the deliverable. You are not implementing the feature.

## Why the bar is the whole job

A vague bar ("make it great") lets the critic grade on a curve and the loop stops at "pretty good for AI." A bar made of implementation details ("use Redis, use a state machine") turns the loop into a compliance check and forecloses better solutions. A good bar states **what must be true about the finished thing, observably, from the outside**, and gives the critic a concrete way to look.

Separating real requirements from implementation detail is the hard part. Steps 3–5 are the tools for it; do not skip them, and do not accept a list of technical tasks as a bar.

## Instructions

### Step 1: Establish the working context

**Greenfield or existing codebase?** Check the working directory for source, `README.md`, `CLAUDE.md`, a package manifest, git history. A request naming an existing feature or file is brownfield.

**If brownfield, investigate before asking questions.** Gather:

- `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `README.md` — purpose, conventions, constraints
- Build/run/test commands — the critic needs these to inspect real output
- The subsystem the change touches, and its current behavior
- **Existing exemplars** — the module, page, or endpoint already built to the standard the user wants. Often the best available bar.
- **Regression surface** — what currently works that must not break

**If greenfield**, note language and runtime preferences, deployment target, and anything already scaffolded.

Summarize what you found in a few lines so the user can correct you early.

### Step 2: Extract the goal, not the route

Get the user to state the **destination**: a goal describes what is true for whoever uses the thing; a route describes how you get there.

Ask, skipping anything already clear:

1. **"When this works, what does someone do with it that they couldn't do before?"** — the goal in user terms
2. **"Who is that someone, and what do they compare it to today?"** — surfaces the bar candidate for free
3. **"What would make you say this shipped badly even though it technically works?"** — surfaces the real quality dimensions

If the user answers in implementation terms ("add a WebSocket layer", "migrate to Postgres"), climb the ladder: ask *why* until the answer stops being about mechanism. Stop at the last rung that is still falsifiable.

> "Use Redis" → why → "cache must survive restarts" → why → "cold start is under 2 seconds at p95"

That last rung is the requirement; everything above it is implementation detail the loop should be free to solve its own way.

Write the goal as one paragraph, no mechanism words, and confirm it.

### Step 3: Find the strongest available bar

The bar must be something an agent can **inspect and compare its own work against**. Take the highest rung that is real for this project:

| Rung | Bar source | Example |
|---|---|---|
| 1 | A running artifact the agent can operate | The competitor app, the production system, the previous version, the real game |
| 2 | A captured artifact | Screenshots, recorded sessions, a golden output set, an API response corpus, a design mockup |
| 3 | A reference implementation | A repo doing the same job well, a library's behavior, an RFC-conformant tool |
| 4 | An in-repo exemplar | The best-built module already here — "match the quality of `src/billing/`" |
| 5 | The thing being replaced | The manual process, the spreadsheet, the human doing it by hand. Very strong for internal tooling. |
| 6 | A constructed reference | Have the loop's first task produce one slice by hand, expensively and carefully, then make that the bar |
| 7 | A written spec sheet with observable probes | Last resort — Step 4 makes this work |

Prefer a hybrid: a reference for the dimensions it covers, spec lines for the rest. A reference rarely covers everything (the real Call of Duty says nothing about your load times).

State the bar sources and how the agent reaches them — URL, path, command, screenshot directory. **A bar the agent cannot open is not a bar.**

### Step 4: Build the spec sheet

Turn the goal into **5–9 dimensions** the finished work is judged on. More dilutes the critic; fewer misses whole failure modes.

Draw candidates from what the user said made things "ship badly", from the reference artifact, and from the domain: correctness, perceived quality, performance, robustness under bad input, first-run experience, discoverability, fit with existing conventions, operability, accessibility.

Each dimension needs four things:

- **Requirement** — one observable statement about the finished thing. No mechanism.
- **Probe** — the concrete action the critic takes to see it: run this command, open this page, feed this input, screenshot and A/B against the reference, benchmark on this hardware.
- **Losing looks like** — the specific failure the critic hunts for. This is what stops grade inflation.
- **Priority** — P0 ship-blocking, P1 strong, P2 nice.

Force numbers wherever numbers exist. "Fast" is not a bar; "first paint under 400ms on a throttled 4G profile" is. Where no number exists, the probe carries the weight: "a reviewer who has used the reference cannot tell which is which in a blind A/B."

| # | Dimension | Requirement (observable) | Probe | Losing looks like | Pri |
|---|---|---|---|---|---|

**Brownfield addition — do-not-regress lines.** Add explicit P0 lines for behavior that must survive: tests that must still pass, API contracts that must not change, performance that must not degrade. A gauntlet loop optimizes hard for what you named and is indifferent to what you did not.

### Step 5: Stress the bar before you trust it

Run both tests on the draft spec sheet, out loud with the user.

**The cheat test — catches under-specification.** Describe the laziest implementation that passes every line: hardcoded demo values, happy path only, one beautiful screen and the rest bare.

- Acceptable? The bar is sound.
- Unacceptable? Name what makes it unacceptable — that is a missing dimension. Add it and re-run.

**The over-constraint test — catches implementation detail in disguise.** Imagine an implementation you would be delighted with, built in a way you did not anticipate, and walk the bar against it. Any line it fails is prescribing a route: rewrite it as the outcome it was protecting, or delete it.

Two per-line checks:

- **Substitution** — swap in a completely different implementation satisfying this line. Does anyone notice or care? If not, it is not a requirement.
- **Counter-example** — name a system that violates this line and is still good. If that is easy, it is a preference: demote to P2 or cut.

### Step 6: Name the boundaries and the anti-goals

**Constraints** — non-negotiable facts about the environment: must run in the browser, must not change the public API, must use the existing schema. These bound the search. The critic does not grade them; it rejects violations outright.

**Out of scope / do not optimize** — what the loop must not spend rounds on. Ask directly: "What would you be annoyed to find the agent spent five rounds perfecting?"

### Step 7: Confirm the bar with the user

**CRITICAL: stop here and get approval before generating the prompt.** Present the one-paragraph goal, the bar sources and how the agent reaches them, the spec sheet, what the cheat test surfaced and how you closed it, the constraints and out-of-scope lists, and the proposed stop condition.

Ask whether the priorities are right and whether anything in the table is really an implementation detail. Revise until the user approves. **Do not proceed on silence.**

### Step 8: Choose the stop condition

Offer these and let the user pick:

- **Convergence (default)** — stop when, for two consecutive rounds, the critic rates the work at or above the bar on every P0 and P1 line and cannot name a new gap above trivial severity.
- **Budget** — a fixed number of rounds per piece, or a wall-clock or token ceiling. Use when the user is cost-sensitive.
- **Checkpoint** — loop to convergence on P0 lines only, then return to the user before P1/P2.

Whichever is chosen, the prompt must forbid stopping because output is "good enough" or "impressive for an AI."

### Step 9: Assemble the prompt

Read `${CLAUDE_SKILL_DIR}/assets/prompt-template.md` and fill it in from Steps 1–8. Consult `${CLAUDE_SKILL_DIR}/assets/examples.md` for greenfield and brownfield worked examples if you need calibration.

Keep the loop mechanics intact — they are what make this a gauntlet loop rather than a long feature request:

- Lead agent gets the goal and the bar, and **chooses its own approach**
- Lead agent splits the work into the **smallest pieces that can be improved and judged independently** — each mapping to at least one bar line
- **Builder and critic are separate agents.** The critic gets fresh context and never sees the builder's self-assessment.
- The critic **inspects real output** — runs it, opens it, screenshots it — compares against the bar, **blind A/B where possible**, names **the single biggest remaining gap**, and sends it back
- Keep looping to the stop condition. Never accept "good enough for AI."
- Maintain a **live progress document** so the run can be monitored without interruption
- Optional **smoothing pass** at the end to align consistency across independently built pieces

### Step 10: Write the output and hand it off

Write the prompt to `GAUNTLET-<slug>.md` in the working directory, `<slug>` being a short kebab-case name for the goal, truncated to 32 characters.

Then tell the user: the output path; that the prompt goes into a **fresh agent session** with subagents available (and `ultracode` enabled if their harness supports it), not this conversation; the bar sources the agent needs access to and anything they must place on disk first (screenshots, reference checkout, credentials); and any dimension you could not make observable, so they know where the loop is weakest.

## Rules

- **Produce the prompt, do not run it.** This skill ends with a file. Building the feature is a separate invocation in a fresh session.
- **Never accept a task list as a bar.** "Add caching, add retries, add tests" is a route. Climb to the outcome each item protects.
- **Be honest about a weak bar.** If the best available bar is a spec sheet with soft probes, say so in the handoff rather than dressing it up.
