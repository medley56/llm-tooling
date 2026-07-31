# Worked Examples

Two condensed examples for calibration. Both show the spec sheet and what the cheat test surfaced — the parts that are hardest to get right.

---

## Example 1 — Greenfield, strong reference available

**User's opening ask:** "I want to build a browser-based drum machine. Something like Ableton but simple."

**Goal (after climbing the ladder):**
> Someone with no music training can sit down, tap out a beat that sounds good within two minutes, and keep it — without reading documentation, installing anything, or making an account.

Note what got removed: "like Ableton" is a bar candidate, not a goal. "Simple" is not a requirement until it is made observable (it became dimension 1).

**Bar sources (rung 1 + rung 2):**
- Ableton Live's Session View and the Roland TR-8S web demo — both operable in a browser tab, open side by side with our output
- Screenshots of both at `./bar/screenshots/` for blind A/B comparison
- Where the references say nothing (load time, first-run experience) the spec lines below carry the bar

**Spec sheet:**

| # | Dimension | Requirement | Probe | Losing looks like | Pri |
|---|-----------|-------------|-------|-------------------|-----|
| 1 | Time to first beat | A first-time user produces a looping 4-bar beat they would keep, within 2 minutes, with no instructions | Hand the URL to a subagent told to act as a non-musician with no prior context; time it and record every dead end | The user hunts for where to click; needs a tooltip to understand the grid; produces something they call "noise" | P0 |
| 2 | Timing accuracy | Playback jitter under 5ms at 120bpm over a 60-second loop | Record output, measure inter-onset intervals against the ideal grid | Audible drift or swing the user did not ask for | P0 |
| 3 | Sound quality | Blind A/B against the TR-8S demo on the same pattern: a listener cannot reliably pick which is which | Render the same 4-bar pattern on both, present unlabeled, ask 3 fresh critics to pick the better one | Ours identified as "the cheap one" by 3/3 | P0 |
| 4 | Visual craft | Blind A/B screenshot against Ableton Session View: ours is not identifiable as the amateur one | Screenshot both at 1440x900, present unlabeled to 3 fresh visual critics | Default browser controls visible; misaligned grid; inconsistent spacing; system font | P0 |
| 5 | Interaction feel | Every input responds within one frame; no click is ever dropped during playback | Script 200 rapid grid toggles during playback; measure response latency and count dropped inputs | Lag between click and visual state; steps that silently fail to toggle | P1 |
| 6 | Cold start | Interactive within 2 seconds on a throttled 4G profile, from a cold cache | Lighthouse run with network throttling, cold cache | Blank screen, spinner, or an audio-permission wall before anything is visible | P1 |
| 7 | Persistence | A pattern survives a page refresh without an account | Create a pattern, hard-refresh, confirm it is intact | Work lost on refresh; a sign-up prompt to save | P1 |

**Cheat test:** the laziest passing build is a 16-step grid with one good-sounding preset kit, no pattern chaining, no tempo change. Verdict: **acceptable.** That is a real drum machine that meets the goal. Bar holds — no new line added.

**Over-constraint test:** an excellent build might use a radial step layout rather than a linear grid. No line forbids that — dimension 4 judges against the reference on craft, not on layout. Bar holds.

**Out of scope:** MIDI export, multi-track, effects chain, mobile layout, sharing.

---

## Example 2 — Existing codebase, no reference implementation

**User's opening ask:** "Our CSV import keeps failing on customer files. I want to rewrite it with a streaming parser and a proper state machine."

**What the skill did:** climbed the ladder. "Streaming parser" and "state machine" are routes. Why → "large files time out." Why → "support spends hours per week on failed imports and customers give up." That is the goal.

**Goal:**
> A customer uploads whatever CSV their system exported and it imports successfully, or they are told precisely what to fix in their file and can fix it themselves. Support is not involved.

**Bar sources (rung 5 + rung 4 + rung 7):**
- **The thing being replaced:** 40 real failed customer uploads at `./bar/failed-uploads/`, with the support ticket for each. Today's system fails all 40. That corpus is the bar.
- **In-repo exemplar:** `src/imports/quickbooks/` — the same team's best-built importer. Match its structure, error taxonomy, and test density.
- No external reference exists for the error-message quality dimension; dimension 3's probe carries it.

**Spec sheet:**

| # | Dimension | Requirement | Probe | Losing looks like | Pri |
|---|-----------|-------------|-------|-------------------|-----|
| 1 | Real-world tolerance | At least 36 of the 40 archived failures now import successfully | Run the corpus; report per-file outcome | Passing on synthetic fixtures while real files still fail | P0 |
| 2 | Scale | A 500MB / 2M-row file imports without exceeding 512MB RSS or a 10-minute wall clock | Generate the file, run under a memory cap, record peak RSS and duration | OOM, timeout, or memory that grows with row count | P0 |
| 3 | Self-serve errors | For each of the 4 files that still fail, a non-technical user can fix the file from the error message alone | Give a fresh subagent only the error message and the broken file, told it is a bookkeeper; can it produce a file that imports? | Row/column offsets with no excerpt; stack traces; "invalid input" | P0 |
| 4 | Partial success | A file with 3 bad rows out of 10,000 imports the 9,997 and reports the 3 | Inject known-bad rows; verify committed count and the rejection report | All-or-nothing rollback on a single bad row | P1 |
| 5 | Encoding and dialect | Handles UTF-8, UTF-16, Latin-1, BOM, CRLF, semicolon and tab delimiters, and quoted embedded newlines without configuration | Matrix test across the corpus, all variants | Requiring the user to declare encoding or delimiter | P1 |
| 6 | Fits the codebase | Structure, error taxonomy, and test density match `src/imports/quickbooks/` | Diff the shape of both modules; run coverage on the new one | A parallel set of conventions invented for this importer | P1 |
| 7 | **Do not regress** | All existing import tests pass; the `POST /v1/imports` response schema is byte-identical; existing successful imports produce identical rows | Full suite; schema snapshot diff; replay 20 known-good historical imports and diff the resulting rows | Any change to the public response shape; any drift in historical results | P0 |

**Cheat test:** the laziest passing build special-cases the 40 archived files by fingerprint. Verdict: **unacceptable** — it fails the next customer. Closed by rewording dimension 1's probe: *the critic must also generate 10 novel malformed files not in the corpus and confirm they import or produce a fixable error.* That change is the cheat test earning its keep.

**Over-constraint test:** no line mentions streaming or a state machine. An excellent solution might buffer intelligently instead. Dimension 2 protects the outcome those mechanisms were proposed for. Bar holds.

**Constraints:** must not change the `POST /v1/imports` request or response schema; must not add a dependency outside the existing lockfile; must run on the current Node version.

**Out of scope:** the upload UI, XLSX support, import scheduling, retry-from-dashboard.
