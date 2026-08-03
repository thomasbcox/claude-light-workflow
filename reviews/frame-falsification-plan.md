# frame-falsification-plan — /frame requires a falsification plan per acceptance criterion

Date: 2026-08-02 · Branch: claude/frame-falsification-plan · Status: approved

## Problem

A mutation sweep written **after** the tests anchors on the tests' own shape: every mutation
is "break the thing this assertion looks at," so the sweep goes fully red while assertions
that cannot fail sit inside it. Demonstrated in txl-assessment-collector
(`reviews/component-test-gate.md`, rounds 1–2): three generations of unfalsifiable
assertions — a regex that could never match, a ban on a token the product never emits, a
closure scoped to one element type — each "proven" by a self-derived sweep, each caught only
by the independent reviewer applying the **criterion** instead of the artifact.

The fix has two halves (the second added at the frame consult, resolving the design
review's BLOCKER):

1. **Derive at spec time.** Every spec names, per acceptance criterion, the regression that
   must be caught and the oracle that catches it — written before any test or assertion
   exists, so the plan can only be derived from the requirement; the artifact it might
   anchor on does not exist yet.
2. **Execute at implementation time.** A plan is guidance, not evidence — nothing about
   writing it proves the later assertions can fail. So step 9 requires each `gate`-oracle
   plan entry to be **demonstrated red** (apply the regression, watch the named check fail,
   revert, record) before its AC is done. A dead assertion is caught at implementation,
   before review ever sees it.

## In scope

1. **Step-5 spec template** (`.claude/skills/frame/SKILL.md`): the `## Test notes` bullet
   gains a **falsification plan** requirement — for each AC, name at least one plausible
   regression **and the oracle mode that detects it**: `gate` (an executable check goes
   red), `manual` (a named inspection), or `reviewer` (judgment at a review altitude).
   "The gate goes red" is reserved for `gate` oracles. For any AC asserting **presence or
   shape**, the plan must include the case where the element renders *nothing*.
2. **Mechanical carve-out**, same bullet: a story whose design sketch is `N/A — mechanical`
   may declare falsification `N/A` with a one-line reason. Silence is not an option.
3. **Step-6 design-review prompt**, same file: one tight sentence directing the reviewer to
   critique the falsification plan at the same altitude as the design sketch — flagging any
   planned falsification derived from an implementation shape rather than from the
   criterion, and any missing or unreasoned `N/A`.
4. **Step-9 demonstrate-red** (design decision, Fix A), same file: for each AC whose plan
   names a `gate` oracle, apply the planned regression, observe the named check fail,
   revert, and record the result in the story file — before the AC is done.
5. **Minimal drift assertions** in `tests/reviewer_test.sh` pinning the load-bearing phrase
   at each edit site (steps 5, 6, 9), consistent with that file's "linter, not a behavioral
   gate" charter and the antipattern-lens precedent.
6. **File the /review-side companion** as an OPS line in `BACKLOG.md` (build stays a
   non-goal).

## Non-goals

- **Building the /review-side companion** (reviewer proposes mutations for test-bearing
  stories) — filed in `BACKLOG.md`, not built.
- **Mutation tooling** (Stryker etc.) — deliberately not adopted; it mutates existing code
  and cannot generate additive regressions, which is where this defect class lived.
- Changes to the **review** or **close** skills, `AGENTS.md`, or the design-review schema —
  the reviewer reports plan critiques as ordinary findings; no schema change needed.

## Acceptance criteria

1. The step-5 `## Test notes` bullet in `.claude/skills/frame/SKILL.md` requires a
   falsification plan: per AC, at least one plausible regression **and its oracle mode**
   (`gate` / `manual` / `reviewer`), written at spec time before any test or assertion
   exists; "the gate goes red" reserved for `gate` oracles; for any AC asserting presence
   or shape, the renders-nothing case included.
2. The same bullet states the mechanical carve-out: sketch `N/A — mechanical` may declare
   falsification `N/A` with a one-line reason; silence is not an option.
3. The step-6 codex prompt directs the reviewer to critique the falsification plan at the
   same altitude as the design sketch, flagging planned falsifications derived from an
   implementation shape rather than from the criterion, and missing or unreasoned `N/A`s.
4. Step 9 requires demonstrate-red: for each AC whose plan names a `gate` oracle, the
   planned regression is applied, the named check observed failing, the change reverted,
   and the result recorded in the story file — before the AC is done.
5. `tests/reviewer_test.sh` gains minimal drift assertions pinning the load-bearing phrase
   at each edit site, and the full gate passes.
6. `BACKLOG.md` files the /review-side companion as an OPS item.
7. Scope containment: the diff touches only `.claude/skills/frame/SKILL.md`,
   `tests/reviewer_test.sh`, `BACKLOG.md`, and this story's artifacts
   (`reviews/frame-falsification-plan.md`, `reviews/frame-falsification-plan.design.json`).

## Test notes

Written criterion-first per the design review's third finding: for each AC, the semantic
weakenings that must be caught come first; the checks are chosen to catch them, not the
other way round. Stated limit: the deliverable is Markdown instructions, so the automated
gate catches only wording drift; behavioral compliance on future stories is enforced by the
step-9 demonstrate-red discipline (design decision Fix A) and the step-6 reviewer.

- **AC1** — weakenings to catch: (i) the template permits an AC with *no falsification
  entry*; (ii) it drops the *renders-nothing* requirement for presence/shape ACs; (iii)
  "gate goes red" language covers non-executable oracles. Oracles: `gate` — drift
  assertions pinning the phrases that carry (i)–(iii); `reviewer` — the step-6 critique
  catches what a grep cannot (an entry that exists but is implementation-shaped).
- **AC2** — weakenings: a mechanical story declares `N/A` *without a reason*, or stays
  *silent*. Oracles: `gate` — assertion pinning the carve-out sentence; `reviewer` —
  per-spec compliance on future runs.
- **AC3** — weakening: the reviewer accepts a plan phrased as a selector/assertion rather
  than required behavior. Oracles: `gate` — assertion pinning the prompt's flag-clause;
  `reviewer` — inherently judgment on future runs (no oracle in this repo proves future
  reviewer behavior; stated, not hidden).
- **AC4** — weakenings: an AC is marked done with *no demonstrated red*; a plan entry that
  cannot be made to go red is silently dropped instead of stopping. Oracles: `gate` —
  assertion pinning the step-9 demonstrate-red sentence; `manual` — this story's own
  demonstrate-red record (below) is the first compliance instance.
- **AC5** — weakening: the gate stays green when a pinned phrase vanishes. Oracle: `gate`,
  demonstrated red: each new assertion run against the pre-change file (from `main`) must
  fail — proving the checks are live, not vacuous. Record below.
- **AC6** — oracle: `manual` — the OPS line exists in `BACKLOG.md`.
- **AC7** — oracle: `manual` — run `git diff --name-only main...HEAD` and verify no files
  appear beyond those AC7 enumerates.

### Demonstrate-red record (2026-08-02, at implementation)

The `gate` oracles here are the six new drift pins; the planned regression for each is the
pinned phrase being absent (weakened or deleted wholesale — same grep catches both). Rather
than six sequential delete-and-rerun cycles, all six were exercised at once against the
**pre-change file** (`git show origin/main:.claude/skills/frame/SKILL.md`), where every
pinned phrase is genuinely absent — the maximal form of the planned regression:

- `name at least one plausible regression` — **red on main** ✓ (AC1: template stops
  requiring a per-AC entry)
- `reserve "the gate goes red" for `gate` oracles` — **red on main** ✓ (AC1: oracle typing
  dropped)
- `include the case where the element renders *nothing*` — **red on main** ✓ (AC1:
  renders-nothing requirement dropped)
- `silence is not an option` — **red on main** ✓ (AC2: carve-out weakened to silent N/A)
- `derived from an implementation shape` — **red on main** ✓ (AC3: prompt stops flagging
  anchored plans)
- `demonstrate red before done` — **red on main** ✓ (AC4: step 9 stops requiring executed
  falsification)

Then the full gate on the branch: **green** (guard 19, reviewer-seam 50, dev-audit,
deep-audit-plan 97, docs 13 — zero failures). Red-on-main → green-on-branch proves the six
checks are live, not vacuous (AC5's `gate` oracle).

## Open questions

_None — resolved at the frame consult (companion filed; see Design decisions)._

## Design sketch — HOW

Three surgical edits to `.claude/skills/frame/SKILL.md`, drift assertions, one backlog line:

- **Step 5, `## Test notes` bullet:** append the falsification-plan requirement — per AC,
  ≥1 plausible regression + oracle mode (`gate` / `manual` / `reviewer`), derived from the
  criterion; "gate goes red" reserved for `gate`; presence/shape ACs include the
  renders-nothing case; sketch `N/A — mechanical` ⇒ plan may be `N/A — <one-line reason>`;
  silence disallowed. The plan lives **inside Test notes** (per the story), not as a new
  section — the spec template grows no new heading.
- **Step 6, codex prompt:** one added sentence at the same altitude as the existing
  design-sketch instructions: critique the falsification plan; flag implementation-shaped
  falsifications and missing/unreasoned `N/A`s. Dilution budget respected — one sentence,
  no new schema field; findings flow through the existing design-review schema.
- **Step 9:** demonstrate-red discipline — apply each planned `gate` regression, observe
  the named check fail, revert, record in the story file; a plan entry that cannot be made
  to go red means stop and fix the test, not the plan.
- **`tests/reviewer_test.sh`:** minimal `has` checks pinning the load-bearing phrase at
  each edit site. Both the template and the prompt sit on the reviewer seam (step 5
  produces the artifact the step-6 reviewer critiques), so the charter fits; no new test
  file.
- **`BACKLOG.md`:** one OPS entry for the /review-side companion (compact — provenance and
  complement relationship; build not committed).

## Build note (2026-08-02)

AC→file map:

- **AC1** (per-AC falsification plan, oracle-typed) → `.claude/skills/frame/SKILL.md` step 5, `## Test notes` bullet
- **AC2** (mechanical `N/A` carve-out with reason) → same bullet
- **AC3** (reviewer critiques the plan) → `.claude/skills/frame/SKILL.md` step 6, codex prompt
- **AC4** (demonstrate-red before done) → `.claude/skills/frame/SKILL.md` step 9
- **AC5** (drift pins, gate green) → `tests/reviewer_test.sh`, six `has` checks
- **AC6** (companion filed) → `BACKLOG.md` OPS-18
- **AC7** (scope containment) → the diff itself (four files + two story artifacts)

## Codex design review (2026-08-02)

**Verdict:** "The edit locations are proportionate and add no dependency, but the design
conflates a pre-code test plan with evidence that future assertions fail. Its own test
notes also expose gaps in the proposed contract."

### BLOCKER

- **A pre-code plan cannot prove future assertions are falsifiable** · one-way ×
  nonstandard · *locus: Problem; Design sketch — Step 5 and Step 6*
  No later workflow step executes the planned regressions against the implemented tests, so
  the stated outcome ("a dead assertion surfaces at the frame consult") is not established —
  a sound plan can still be implemented with an impossible regex. Calling the plan
  "falsification evidence" creates an assurance the workflow does not deliver.
  **Alternative:** keep the criterion-derived plan at frame time, but require the
  implemented tests to be exercised against each planned negative case before the gate is
  accepted — or narrow the story's claim to test-design guidance.
  **Win:** adds the missing point where negative cases meet real tests, so an unfalsifiable
  assertion is actually detected; or removes a false guarantee from the workflow contract.

### IMPORTANT

- **The gate-red rule lacks an oracle model for manual criteria** · one-way × kludgy ·
  *locus: ACs 1–2; Test notes — AC5; Design sketch — Step 5*
  "Must turn the gate red" assumes an executable oracle, but documentation/review/process
  criteria often have manual oracles — this very spec's AC5 (`git diff --name-only` always
  exits 0) already needed an N/A escape despite a non-mechanical sketch. Universal
  gate-language invites pretend-red checks.
  **Alternative:** require each AC to name the regression **and the oracle that detects
  it**, with an explicit mode (automated gate / manual inspection / reviewer judgment);
  reserve "turn the gate red" for executable checks.
  **Win:** closes the contract's first loophole; one template covers code, docs, and
  process stories without fake automation.

- **The story's own falsification plan is assertion-shaped** · two-way × kludgy ·
  *locus: Test notes — AC1/AC2/AC3/AC4*
  The planned mutations ("red on main", delete the pinned sentence) are derived from the
  planned grep checks — the exact anchoring failure this story exists to prevent. They do
  not challenge the semantic weakenings: an AC with no falsification entry, a presence AC
  omitting the renders-nothing case, an unexplained mechanical N/A, a reviewer accepting an
  implementation-shaped plan.
  **Alternative:** state negative cases from each criterion first, then choose `has`
  strings broad enough that each semantic weakening breaks its drift check.
  **Win:** the first example complies with the policy it introduces.

## Codex approach review (2026-08-02, base origin/main, HEAD 44efe88)

**Verdict:** "The approach is sound, proportionate, and idiomatic for this
instruction-driven repository. It uses one criterion-first plan contract, typed oracles, a
matching design-review check, implementation-time evidence for executable oracles, minimal
drift pins, and no new dependency or unnecessary machinery. The configured gate could not
run because the read-only sandbox forbids its temporary repositories; that is
environmental, not an approach concern."

**Findings:** none — clean pass. Shape blessed; correctness pass runs this same round.

## Codex review (2026-08-02, base origin/main, HEAD 94b6d1e)

**Summary:** "The behavioral changes satisfy AC1–AC6, but the branch violates the approved
scope-containment criterion because it adds an unlisted review artifact."

### BLOCKER

- **Unlisted approach-review artifact violates AC7** ·
  `reviews/frame-falsification-plan.approach.json:1`
  AC7 lists only `frame-falsification-plan.md` and `frame-falsification-plan.design.json`
  as permitted story artifacts; the added approach-review artifact is not among them, so
  the branch fails an explicit acceptance criterion as written.
  **Suggestion:** remove the artifact, or amend AC7 with Thomas's approval so
  workflow-generated review artifacts are explicitly permitted.

## Hidden-failure review (2026-08-02, base origin/main, HEAD 94b6d1e)

**Summary:** "The diff introduces no swallowed exceptions, ignored failures,
catch-and-continue paths, silent fallbacks, or removed safety checks. Its new
falsification workflow explicitly requires failed checks to stop implementation, so no
hidden-failure issue was found."

**Findings:** none.

*Process note for this round:* the deployed review skill at `~/.claude` (July 2) predates
the parallel hidden-failure critic (OPS-12, July 17): the round initially ran per the stale
single-critic instructions, was caught against the repo's current `review/SKILL.md`, and
the hidden-failure critic was then run to complete the pair. Its first launch failed
fail-closed — `hidden-failure-schema.json` is absent from the stale deployment — and was
rerun against this repo's own copy of the schema (this repo is the skill's home; the
absolute-`$HOME` rule exists for repos that don't carry it). Redeploy via `./install.sh`
belongs to /close, post-merge.

## Design decisions (2026-08-02)

Scope approved by Thomas: **"Approved — Fix A, fix 2 and 3, file the backlog line."**

- **BLOCKER (plan ≠ evidence) → Fix A.** Step 9 gains demonstrate-red: each `gate`-oracle
  plan entry is executed (apply regression → observe red → revert → record) before its AC
  is done. The frame consult surfaces the *plan*; the *evidence* lands at implementation
  time. The story's claim now matches its mechanism.
- **IMPORTANT (no oracle model) → fix.** Plan entries name the regression **and** its
  oracle mode (`gate` / `manual` / `reviewer`); "the gate goes red" is reserved for `gate`.
- **IMPORTANT (assertion-shaped plan) → fix.** This spec's Test notes rewritten
  criterion-first (weakenings before checks).
- **Open question (companion filing) → file.** The /review-side companion goes into
  `BACKLOG.md` as an OPS item; building it stays a non-goal.

## Decisions (2026-08-02)

Round 1 — approach pass clean, hidden-failure pass clean, one correctness BLOCKER.

**Correctness**

- **BLOCKER — Unlisted approach-review artifact violates AC7** → **fix, by amending AC7.**
  Thomas: *"Amend AC7"*. The AC's artifact clause was written at spec time, before the
  review round existed, and enumerated only the two artifacts that existed then; the loop's
  own review outputs (`.approach.json`, `.codex.json`, `.hidden-failure.json`) are mandated
  by `/review` and are repo convention on every prior story. AC7 is reworded to cover this
  story's artifacts as a set (`reviews/frame-falsification-plan.*`). The criterion's purpose
  — containing the *product* diff to the frame skill, the test file, and the backlog line —
  is unchanged.

**Approach** — no findings; shape blessed.

**Hidden-failure** — no findings.
