# falsification-surface-rows — falsification rows per (criterion, surface), append-only, with declared exclusions

Date: 2026-08-03 · Branch: claude/falsification-surface-rows · Status: approved

Scope approved by Thomas 2026-08-03: **"fix all three, skipping line for every promise"** —
all three design findings fixed; `surfaces excluded` required on every AC (three-valued).

## Problem

`frame-falsification-plan` (merged 2026-08-03, `merge: frame-falsification-plan`) requires
each acceptance criterion to name a regression and its oracle, then requires that regression
to be **demonstrated red** at implementation. That closes the *liveness* question: is this
check capable of firing at all?

It does not close the **extent** question: does the check cover everywhere the criterion
applies? The two are independent. Of the three txl-assessment-collector instances that
motivated the original story, demonstrate-red kills the first two — an impossible regex and
a ban on a never-emitted token both fail to go red, exposing themselves. The third, a
closure scoped to one element type, **survives it cleanly**: you mutate the element type the
closure watches, the check goes red, the evidence looks complete, and every other element
type stays unguarded. A criterion satisfied on one surface and dead on another is invisible
to the mechanism we just shipped.

The residual is therefore *extent*, and it needs its own row key. A single row per criterion
cannot express "this must hold for each element type" — it can only record that it held
somewhere.

### Known limits (stated, not solved)

- **No mechanical denominator.** With one row per AC, a script can count ACs and count rows.
  With per-surface rows, nothing tells an automated check that a criterion has four surfaces
  and three were listed — under-enumeration is invisible to any script. This story does not
  solve that; it converts the silent gap into a **written claim** (AC2) that the step-6
  reviewer can attack, which is the mechanism that has actually been catching this class
  (txl rounds 1–2; the AC7 catch in `frame-falsification-plan` round 1).
- **Reviewer judgment quality is unverifiable here.** AC2 and AC4 delegate extent-checking to
  the step-6 reviewer; no check in this repo observes whether the reviewer reliably attacks a
  lazy `none`. The delegate cannot also be the verifier. Recorded as a limit, not represented
  as an excluded surface (design finding 2).
- **Amendment volume is unbounded.** Nothing stops a deliberately thin spec-time plan whose
  real content arrives through the append valve. The `added at: implement` marker makes it
  visible to a reader; no check counts it. Accepted limit.
- **Retraction reasons are unreviewed until OPS-18 ships.** A retraction can only exist after
  step 9, so the step-6 design review — which runs before approval — cannot see one. That
  duty is handed to OPS-18 and the step-6 prompt says so explicitly rather than claiming a
  check it cannot perform. Added round 1 (approach finding 1, minimal variant).

## In scope

1. **Row key** (`.claude/skills/frame/SKILL.md` step 5): the falsification plan's unit
   becomes **(AC, surface)** rather than (AC). `surface` is **free text** naming where in the
   product the criterion is observable, derived from the criterion — typically from its own
   quantifier ("any element type", "every deployed skill", "all `*.sh` files"). One row per
   surface the criterion spans; a criterion naming a single observable keeps one row. A
   surface is a **place, not a mechanism**: a test, the gate, or the reviewer is an *oracle*,
   never a surface.
2. **Declared exclusions**, same step: each AC carries a `surfaces excluded` line, **three
   valued** — a list of named surfaces with reasons, `none`, or `n/a` (single observable).
   Silence is not an option. Exclusions name **product surfaces only**; machinery limits go
   in prose.
3. **No circular oracles**, same step: a row may not name as its oracle the same mechanism
   whose failure is that row's regression.
4. **Append-only after approval, via one amendment log** (steps 8–9): the plan in the `spec:`
   commit is the frozen baseline. Post-approval changes are recorded in a single
   `## Falsification-plan amendments` section — one entry per change stating the action
   (`add` / `retract`), the AC, the exact surface targeted, the reason, and
   `added at: implement`. Approved rows are never edited or deleted in place; a wrong row is
   **retracted**, and the retraction is itself a claim the reviewer may reject.
   Implement-added rows carry the same demonstrate-red obligation as spec-time rows.
5. **Reviewer prompt** (step 6): the design reviewer additionally critiques **surface
   enumeration**, the **`surfaces excluded`** claim, **retractions**, and **circular
   oracles**.
6. **Minimal drift assertions** in `tests/reviewer_test.sh` pinning the load-bearing phrase
   at each edit site, per that file's "linter, not a behavioral gate" charter.

## Non-goals

- **A closed vocabulary of surfaces.** Deliberately rejected: a fixed list would have to be
  built by reading the codebase and enumerating the surfaces it happens to have, making
  every plan artifact-anchored by construction — the exact bias this line of work exists to
  remove. Free text is the anti-anchoring choice.
- **A mechanical completeness check on surface counts.** No denominator exists (see Known
  limits). Not attempted.
- **The cross-AC consistency heuristic** (flagging when two ACs quoting the same quantifier
  list different surface counts). Considered and declined: no ground truth, wording-coupled,
  and the same brittleness class `tests/reviewer_test.sh`'s charter warns against. Recorded
  here, not built.
- **/review-side changes** (OPS-18 remains the companion story) and **`AGENTS.md`** or the
  design-review schema — reviewer critiques flow through existing finding fields.

## Acceptance criteria

1. Step 5's falsification-plan bullet keys rows by **(AC, surface)**: `surface` is free text
   naming where in the product the criterion is observable, derived from the criterion (its
   quantifier) rather than from any intended implementation; one row per spanned surface; a
   single-observable criterion keeps one row; and a surface is explicitly a **place, not a
   mechanism** (a test / the gate / the reviewer is an oracle, never a surface). The existing
   per-row requirements — oracle mode (`gate` / `manual` / `reviewer`) and the
   renders-nothing case for presence/shape — carry forward unchanged **per row**.
2. Step 5 requires a per-AC **`surfaces excluded`** line with exactly three permitted forms:
   a list of named surfaces each with a reason, `none`, or `n/a`. Silence is not an option,
   and exclusions name product surfaces only. This holds **even when the design sketch is
   `N/A — mechanical`**: the mechanical label waives the per-row regression/oracle detail,
   never the per-AC extent claim. *(Amended round 1 — the whole-plan mechanical escape hatch
   would otherwise let a self-applied story-level label erase every per-AC declaration; see
   Decisions.)*
3. Step 5 forbids a **circular oracle**: no row may name as its oracle the mechanism whose
   failure is that row's own regression.
4. Steps 8–9 state the **append-only** rule and its **amendment log**: the `spec:` commit is
   the frozen baseline; post-approval changes go in one `## Falsification-plan amendments`
   section, each entry giving action (`add` / `retract`), AC, target surface, reason, and
   `added at: implement`; approved rows are never edited or deleted in place; a wrong row is
   retracted rather than removed; implement-added rows carry demonstrate-red.
5. The step-6 reviewer prompt directs the reviewer to critique surface enumeration, the
   `surfaces excluded` claim, and circular oracles. It does **not** cover retractions: step 6
   runs before approval and an amendment log exists only after step 9, so that duty is
   OPS-18's and the prompt says so. *(Amended round 1 — the original wording assigned a check
   to a phase temporally incapable of performing it; see Decisions and Known limits.)*
6. `tests/reviewer_test.sh` gains drift assertions pinning the load-bearing phrase at each
   edit site, and the full gate passes.
7. Scope containment: the diff touches only `.claude/skills/frame/SKILL.md`,
   `tests/reviewer_test.sh`, `BACKLOG.md`, and this story's artifacts
   (`reviews/falsification-surface-rows.*`). *(Amended round 1 — `BACKLOG.md` added to carry
   the one-line OPS-18 handoff that the minimal fix to finding 1 depends on; see Decisions.)*

## Test notes

Written in the **proposed** per-surface format — the story demonstrates the format it asks
for. Surfaces below are **places**: the instruction text itself, the specs that instruction
produces, a story file's own history, the linter file, and the branch diff. Mechanisms
(`gate` / `manual` / `reviewer`) appear only in the oracle column, per design finding 2.

**AC1 — row key (AC, surface)**

| surface | regression that must be caught | oracle |
|---|---|---|
| the step-5 instruction text | reverts to one row per AC, or drops the criterion-derived requirement so surfaces may be listed from the implementation, or drops the place-not-mechanism rule | `gate` |
| specs produced by that instruction | an author writes one row for a criterion that quantifies over several kinds ("any element type") — the under-enumeration this story exists to catch | `reviewer` (step 6) |

*surfaces excluded:* `none`.

**AC2 — declared exclusions**

| surface | regression that must be caught | oracle |
|---|---|---|
| the step-5 instruction text | the three-valued vocabulary collapses — a blank becomes permissible, or `n/a` and `none` merge so "I looked and excluded nothing" is no longer distinguishable from "nothing to look at" | `gate` |
| specs produced by that instruction | an author types `n/a` on a criterion that plainly quantifies, or `none` without having considered extent | `reviewer` (step 6) |

*surfaces excluded:* `none`.

**AC3 — no circular oracles**

| surface | regression that must be caught | oracle |
|---|---|---|
| the step-5 instruction text | the prohibition is dropped, permitting a row whose oracle is the very mechanism its regression breaks | `gate` |
| specs produced by that instruction | an author names the reviewer as the oracle for "the reviewer misses this" | `reviewer` (step 6) |

*surfaces excluded:* `none`.

**AC4 — append-only + amendment log**

| surface | regression that must be caught | oracle |
|---|---|---|
| the step-8/9 instruction text | the append-only rule is dropped, the amendment log stops being required, or the retraction path is written so a row may be removed rather than marked | `gate` |
| a story file's own git history | a plan row present at the `spec:` commit is absent at merge — the plan shrank to fit the artifact | `manual`: `git diff <spec-commit>..HEAD -- reviews/<slug>.md`, verify no plan row was removed |
| specs produced by that instruction | amendments are written inline in the tables instead of the log, leaving active-vs-retracted state ambiguous to a reader | `reviewer` (step 6) |

*surfaces excluded:* `none`.

**AC5 — reviewer prompt**

| surface | regression that must be caught | oracle |
|---|---|---|
| the step-6 prompt text | the prompt stops naming enumeration, exclusions, retractions, or circular oracles — silently removing the one mechanism with any purchase on extent | `gate` |

*surfaces excluded:* `n/a` — the criterion names a single observable (the prompt text). Whether
the reviewer then *acts* on the prompt is delegated judgment, recorded under Known limits;
naming it here would make the failing mechanism its own oracle (design finding 3).

**AC6 — drift pins**

| surface | regression that must be caught | oracle |
|---|---|---|
| the drift-linter file (`tests/reviewer_test.sh`) | a pin stays green when its pinned phrase is weakened or deleted — a vacuous check | `gate`, demonstrated red: each new pin run against the pre-change file from `main` must fail |

*surfaces excluded:* `n/a` — single observable.

**AC7 — scope containment**

| surface | regression that must be caught | oracle |
|---|---|---|
| the branch diff | a file outside the enumerated set appears | `manual`: `git diff --name-only main...HEAD`, verify no files beyond those AC7 enumerates |

*surfaces excluded:* `n/a` — single observable.

### Demonstrate-red record (2026-08-03, at implementation)

Every `gate`-oracle row above is carried by a drift pin whose planned regression is the
pinned phrase being weakened or deleted. All ten were exercised at once against the
**pre-change file** (`git show main:.claude/skills/frame/SKILL.md`), where each phrase is
genuinely absent — the maximal form of the planned regression:

| AC | surface | pinned phrase | result |
|---|---|---|---|
| AC1 | step-5 instruction text | `where in the product the criterion is observable` | red on main ✓ |
| AC1 | step-5 instruction text | `A surface is a **place, not a mechanism**` | red on main ✓ |
| AC2 | step-5 instruction text | `in exactly three permitted forms` | red on main ✓ |
| AC2 | step-5 instruction text | `Exclusions name **product surfaces only**` | red on main ✓ |
| AC3 | step-5 instruction text | `**No circular oracles:**` | red on main ✓ |
| AC4 | step-8/9 instruction text | `falsification plan in this commit is the frozen baseline` | red on main ✓ |
| AC4 | step-8/9 instruction text | `The approved plan is append-only:` | red on main ✓ |
| AC4 | step-8/9 instruction text | `## Falsification-plan amendments` | red on main ✓ |
| AC4 | step-8/9 instruction text | `retracted, never removed` | red on main ✓ |
| AC5 | step-6 prompt text | `rather than a place in the product` | red on main ✓ |

Then the full gate on the branch: **green**, verified per suite with explicit exit codes
(guard, reviewer-seam, dev-audit, deep-audit-plan, docs — all `0`). Red-on-main →
green-on-branch proves the ten pins are live, not vacuous (AC6's `gate` oracle).

**One genuine red caught in passing.** The first full-gate run failed
(`reviewer_test.sh`: `passed=59 failed=1`). Restructuring the step-5 bullet into a nested
list dropped the word "name" from "name at least one plausible regression", breaking the pin
the *previous* story installed. Fixed by restoring the wording in the skill text rather than
editing the pin to match — a pin edited to fit the artifact is the failure this whole line
of work exists to prevent. This is a live instance of **OPS-17** (one rule restated in skill
prose and in a linter pin; editing one copy silently breaks the other), and an instance of
the gate doing its job.

*Process note:* the initial run masked this by piping the suite through `tail`, which
returns `tail`'s exit status rather than the suite's — the run printed `failed=1` and
`GATE GREEN` in the same breath. Re-run per suite with explicit exit codes. Recorded because
a gate whose result can be masked by the way it is invoked is worth knowing about.

## Falsification-plan amendments

The plan frozen at the `spec:` commit (`59c99fa`) is never edited in place. Round-1 fixes
changed two criteria, so their rows are **retracted and replaced** here — an in-place edit is
exactly what the rule forbids, and retract-plus-add is how a change to an existing
`(AC, surface)` pair is expressed while uniqueness on the pair still holds.

| action | AC | surface | reason | when |
|---|---|---|---|---|
| `retract` | AC5 | the step-6 prompt text | AC5 amended: the prompt no longer covers retractions, so the row's regression named a duty that no longer exists | `added at: implement` |
| `add` | AC5 | the step-6 prompt text | replacement row for the amended criterion (below) | `added at: implement` |
| `retract` | AC2 | the step-5 instruction text | AC2 amended: the row's regression covered only vocabulary collapse, not the mechanical hatch erasing every per-AC declaration | `added at: implement` |
| `add` | AC2 | the step-5 instruction text | replacement row for the amended criterion (below) | `added at: implement` |
| `retract` | AC5 | the step-6 prompt text | **round-2 correctness finding:** the row named only content-removal and duty-reinstatement as regressions, so deleting the *handoff sentence* itself was an uncovered regression — the row was incomplete, and the test built from it was correspondingly blind | `added at: implement` |
| `add` | AC5 | the step-6 prompt text | replacement row covering handoff deletion as well (below) | `added at: implement` |

**Active replacement rows** (both carry the same demonstrate-red obligation as spec-time rows):

| AC | surface | regression that must be caught | oracle |
|---|---|---|---|
| AC5 | the step-6 prompt text | ~~the prompt stops naming enumeration, exclusions, or circular oracles … or the impossible retraction duty is reinstated~~ **(retracted round 2 — incomplete)** | ~~`gate`~~ |
| AC5 | the step-6 prompt text | the prompt stops naming enumeration, exclusions, or circular oracles — silently removing the one frame-time mechanism with purchase on extent; **or** the impossible retraction duty is reinstated, re-claiming a check that phase cannot perform; **or** the handoff sentence itself is deleted, so the phase boundary and OPS-18's ownership vanish and the deferral becomes silent rather than recorded | `gate` |
| AC2 | the step-5 instruction text | the three-valued vocabulary collapses (a blank becomes permissible, or `n/a` and `none` merge) **or** the mechanical label is allowed to waive the per-AC extent claim rather than only the per-row detail | `gate` |

*No other row changed.* AC7's row references "those AC7 enumerates" rather than restating the
file list, so amending AC7's list left its row correct — the reason step 5 tells scope-
containment ACs to reference rather than restate.

## Open questions

_None — resolved at the frame consult: `surfaces excluded` is required on every AC
(three-valued). See Design decisions._

## Design sketch — HOW

Three edits to `.claude/skills/frame/SKILL.md`, plus drift pins:

- **Step 5, falsification-plan bullet:** re-key rows to (AC, surface) with `surface` defined
  as a place in the product derived from the criterion's quantifier, explicitly not a
  mechanism; keep oracle mode and the renders-nothing rule **per row**; forbid circular
  oracles; add the `surfaces excluded` line with its three permitted forms. No new heading —
  the plan stays inside `## Test notes`, as merged. The bullet becomes a short nested list
  rather than one long sentence, because it now carries four rules.
- **Step 6, codex prompt:** extend the existing falsification sentence to name surface
  enumeration, the exclusion claim, retractions, and circular oracles. One sentence, no
  schema change — findings continue to flow through the design-review schema's existing
  fields.
- **Steps 8–9:** the `spec:` commit is the frozen baseline (step 8); append-only with a
  single `## Falsification-plan amendments` log, retraction-not-removal, and demonstrate-red
  extended to implement-added rows (step 9).
- **`tests/reviewer_test.sh`:** one `has` pin per load-bearing phrase, in the existing
  falsification block; no new test file.

**Format note:** the plan is written as a small table per AC rather than prose bullets,
because the unit is now a pair and a table makes an omitted surface visible as a missing
row. This is a presentation convention in the template, not a parser — nothing reads these
tables mechanically.

## Build note (2026-08-03)

AC→file map:

- **AC1** (row key `(AC, surface)`; place-not-mechanism) → `.claude/skills/frame/SKILL.md` step 5, `## Test notes` bullet
- **AC2** (`surfaces excluded`, three-valued, product surfaces only) → same bullet
- **AC3** (no circular oracles) → same bullet
- **AC4** (frozen baseline; append-only + amendment log; retract-not-remove) → `.claude/skills/frame/SKILL.md` steps 8 and 9
- **AC5** (reviewer critiques enumeration / exclusions / retractions / circular oracles) → `.claude/skills/frame/SKILL.md` step 6, codex prompt
- **AC6** (drift pins, gate green) → `tests/reviewer_test.sh`, ten `has` checks
- **AC7** (scope containment) → the diff itself

*Round 2 (2026-08-03):* AC5's map entry gains `BACKLOG.md` — the round-1 minimal fix moved
retraction review to OPS-18, and the handoff line lives in that entry. No other mapping
changed.

## Codex design review (2026-08-03)

**Verdict:** "The per-(AC, surface) model is proportionate for this instruction-driven
repository, and no dependency manifest or existing library supplies the missing denominator.
However, I would tighten the shape before adopting it globally: preserve the approved plan
through one explicit amendment log, keep surfaces distinct from verification mechanisms and
policy limits, and remove a self-referential reviewer oracle."

### IMPORTANT

- **Append-only tables lack an explicit amendment model** · one-way × kludgy ·
  *locus: In scope 3; AC3; Design sketch — Steps 8–9*
  Making arbitrary Markdown rows append-only without saying where amendments live, how a
  retraction identifies its target, or how a reader derives the active plan creates an
  ambiguous cross-cutting protocol. Git already preserves the approved `spec:` version.
  **Alternative:** freeze the approved tables; add one declarative
  `Falsification-plan amendments` log (action / AC / exact surface / reason /
  `added at: implement`), with demonstrate-red records referencing active additions.
  **Win:** one place for all post-approval change, unambiguous retraction targets, no mixed
  active/retracted state in tables, reuses git's immutable baseline.

- **The example collapses surfaces, oracles, and known limits** · one-way × kludgy ·
  *locus: Test notes introduction; AC2–AC4 `surfaces excluded` entries*
  The contract defines a surface as where the criterion is observable, but the example calls
  the gate a surface and lists reviewer judgment quality and amendment volume as *excluded
  surfaces* — an oracle quality and a policy limit respectively. Future stories copy the
  example, so the model invites authors to enumerate tests and reviewers instead of the
  criterion's extent — the anchoring this story exists to prevent.
  **Alternative:** reserve surface rows and `surfaces excluded` for criterion-derived product
  observables only; put unverifiable oracle quality and assurance limits in Known
  limits / Non-goals prose.
  **Win:** one invariant for every row; prevents plans that look complete by listing
  verification machinery instead of omitted product surfaces.

- **AC4 assigns the reviewer as oracle for its own omission** · two-way × nonstandard ·
  *locus: Test notes — AC4, `reviewer output on a future story` row*
  The regression is "the reviewer never flags an under-enumerated plan" and the named oracle
  is that same reviewer. An oracle that fails in the regression cannot detect it.
  **Alternative:** keep the gate row for prompt removal; either drop the future-behavior row
  or name an independent inspection as `manual`.
  **Win:** removes one impossible detection path; every retained row names a mechanism
  capable of observing its regression.

## Codex approach review (2026-08-03, base main, HEAD 6650969)

*Record correction (round 2): this header originally cited HEAD `3d09300`, a SHA that does
not exist in this repository — a transcription error, not a real commit. The pass ran with
HEAD at `6650969` (`review: build note`), which is the SHA the round-2 re-review bases on.
Corrected rather than left standing, since a story file citing a non-existent commit is an
unusable audit trail.*

**Verdict:** "The per-(AC, surface) table and lightweight phrase pins are proportionate,
consistent with this instruction-only repository, and introduce no unnecessary dependency or
parser. I would not ship the shape unchanged, however: retraction review is assigned to a
phase that runs before retractions can exist, and the mechanical-story escape hatch
contradicts the new every-AC exclusion invariant."

### IMPORTANT

- **Retractions are reviewed before they can exist** · one-way × kludgy ·
  *locus: `.claude/skills/frame/SKILL.md` steps 6 and 9; AC4–AC5*
  Step 6 tells the frame-time design reviewer to critique amendment-log retractions, but
  step 6 runs **before approval** while the amendment log can only be created during step-9
  implementation. The only explicitly tasked check is temporally incapable of seeing a
  retraction; the later approach pass is generic, and this story excludes `/review`-side
  changes — leaving a cross-cutting claim future stories may treat as reviewed when it was
  never observable.
  **Alternative:** move amendment/retraction inspection to the post-implementation approach
  pass; preferably define the falsification-plan rubric once in the shared reviewer contract
  and have both phases apply it — frame review takes enumeration, exclusions, and circular
  oracles; approach review additionally takes actual amendments and retractions.
  **Win:** eliminates an impossible review path; every retraction is inspected only after it
  exists; the rubric is centralized instead of duplicated per phase.

- **Whole-plan mechanical N/A bypasses the per-AC invariant** · one-way × kludgy ·
  *locus: `.claude/skills/frame/SKILL.md` step 5*
  The new contract says every AC must carry a three-valued `surfaces excluded` declaration
  and that silence is not permitted — but the retained whole-plan `N/A — mechanical` escape
  hatch lets every per-AC declaration disappear on a subjective story-level label. The
  central extent claim becomes conditional, and future stories get a protocol-wide bypass.
  **Alternative:** keep the mechanical exemption for regression/oracle detail if desired, but
  still enumerate each AC and require its `surfaces excluded` line in one of the three
  approved forms.
  **Win:** removes a special-case bypass; one invariant for reviewers and any future presence
  check — every AC always declares its considered extent.

## Fixes (2026-08-03)

- **Approach finding 1 (retractions reviewed before they can exist) → minimal variant.** The
  step-6 prompt's retraction clause is removed and replaced with an explicit statement that
  amendment-log retractions are out of scope at that phase, naming OPS-18 as the owner —
  so the prompt no longer claims a check it cannot perform. `BACKLOG.md`'s OPS-18 entry gains
  the handoff and the plain statement that retraction reasons go unreviewed until it ships.
  AC5 and AC7 amended; a Known limit records the gap.
- **Approach finding 2 (mechanical N/A bypasses the per-AC invariant) → fixed.** Step 5's
  carve-out now waives only the per-row regression/oracle detail; every AC still carries its
  `surfaces excluded` line in one of the three forms. AC2 amended.
- **Plan rows** changed via the new `## Falsification-plan amendments` log (retract + add per
  affected `(AC, surface)` pair), never edited in place — the story's first exercise of its
  own mechanism.

### Demonstrate-red for the round-1 added rows

- **AC2 / step-5 instruction text** — new pin `The mechanical label waives the detail, never
  the extent claim`: **red against `main`** ✓ (the phrase does not exist there).
- **AC5 / step-6 prompt text** — the reinstatement guard is an `absent` check, so its
  regression is the impossible duty *returning*. Verified both directions: the check **fires**
  against a file containing the reinstated clause ✓, and is **satisfied** by the current file
  ✓. An `absent` pin that never fires would be the vacuous case; this one does.

Full gate green, verified per suite with explicit exit codes.

**A second real red caught in this round.** `reviewer_test.sh` failed (`passed=61 failed=1`):
rewriting the mechanical carve-out capitalised "Silence", breaking the previous story's pin
on the lowercase phrase. Fixed by restoring the wording in the skill text, not by editing the
pin. That is **two instances in two rounds** of the same mechanism — a rule stated in both
skill prose and a linter pin, where editing the prose silently breaks the pin. It is exactly
**OPS-17**, and this story has now supplied it two fresh data points.

## Codex approach review — round 2 (2026-08-03, base 6650969, HEAD 61d5dc8)

**Verdict:** "The shape is sound and proportionate. I would satisfy the ACs with the same
structure: one declarative per-(AC, surface) contract in frame step 5, phase-appropriate
reviewer guidance, one append-only amendment protocol, and lightweight drift pins. The
round-one fixes remove the mechanical-story bypass and the temporally impossible retraction
review without adding runtime machinery. The repository has no dependency manifest or
framework facility that this reinvents, and the phrase pins match its documented
instruction-as-product conventions. I found no remaining high-leverage approach concern;
this verdict does not assess line-level correctness."

**Findings:** none — both round-1 findings verified closed. Shape blessed; correctness pass
runs this same round.

## Codex review (2026-08-03, base 6650969, HEAD f8e5426)

**Summary:** "The implementation satisfies the two amended behavior requirements, but its new
drift coverage does not protect the required OPS-18 handoff. The directly relevant reviewer
linter passes; the full gate could not run because the read-only sandbox prevents its
temporary-directory setup."

### IMPORTANT

- **OPS-18 handoff is not pinned** · `tests/reviewer_test.sh:129`
  The new assertion only checks that the *former* retraction-review wording is **absent**. If
  the newly required parenthetical — declaring retractions out of scope at step 6 and
  assigning them to OPS-18 — were deleted, the check would still pass. AC5's required handoff
  is unprotected, and AC6 requires the load-bearing phrase pinned at **each** edit site.
  **Suggestion:** add a positive `has` assertion for the phase-boundary and OPS-18 ownership
  wording, keeping the `absent` assertion against reinstating the impossible duty.

## Hidden-failure review (2026-08-03, base 6650969, HEAD f8e5426)

**Summary:** "The diff introduces no swallowed exceptions, blind catches, silent fallbacks,
catch-and-continue behavior, or deletion of an effective safety check. The deferred retraction
review is explicitly surfaced in the frame prompt, story, and backlog rather than hidden."

**Findings:** none.

## Fixes — round 2 (2026-08-03)

- **IMPORTANT (OPS-18 handoff not pinned) → fixed at both levels.**
  - **Test:** two positive `has` pins added — one on the phase-boundary wording
    (`Amendment-log retractions are **out of scope here**`), one on the ownership wording
    (`that duty is OPS-18's`) — alongside the retained `absent` guard against the old duty
    returning. The `absent` guard alone could never catch deletion; only a positive pin can.
  - **Plan:** AC5's round-1 replacement row is **retracted and replaced** through the
    amendment log. The row was the root defect — it named content-removal and
    duty-reinstatement as its regressions but not deletion of the handoff sentence, so a test
    built faithfully from it was blind by construction. Corrected by retract-plus-add, never
    edited in place.

**Demonstrate-red for both added pins** — verified in both directions, since a pin that
cannot fail is the defect this story exists to catch:

| pin | red against `main` | fires when the handoff sentence is deleted |
|---|---|---|
| `Amendment-log retractions are **out of scope here**` | ✓ | ✓ |
| `that duty is OPS-18's` | ✓ | ✓ |

Full gate green, per suite with explicit exit codes; `reviewer_test.sh` now `passed=64
failed=0`.

**Worth recording:** this finding is the story's own thesis turned on itself. The round-1 test
was derived from an incomplete plan row rather than from AC5's criterion, and it passed
convincingly while leaving the criterion's real extent unguarded — liveness without extent,
which is precisely the gap the (AC, surface) key exists to close. The independent reviewer
caught it by reading the criterion, not the test.

## Decisions — round 2 (2026-08-03)

Approach pass clean (both round-1 findings verified closed); hidden-failure pass clean; one
correctness finding. Thomas: **"fix and /close"**.

**Correctness**

- **IMPORTANT — OPS-18 handoff is not pinned** → **fix.** The round-1 edit added an `absent`
  guard against the *old* retraction wording returning, but pinned nothing positive, so
  deleting the new phase-boundary/OPS-18 sentence would leave the gate green — AC5's handoff
  unprotected and AC6's "each edit site" unmet. Fix adds positive `has` pins for the phase
  boundary and the OPS-18 ownership, retaining the `absent` guard.
  **The underlying defect is in the plan, not only the test:** AC5's round-1 replacement row
  named only prompt-content removal and duty reinstatement as its regressions, not deletion
  of the handoff sentence. That row is therefore retracted and replaced through the amendment
  log — an incomplete row is corrected by retract-plus-add, never edited in place.

**Approach** — no findings.

**Hidden-failure** — no findings.

## Decisions (2026-08-03)

Round 1 — approach pass, two IMPORTANT findings. Thomas: **"fix both, minimal for the
first"**. Both are shape changes, so per `review/SKILL.md` step 7 the **correctness pass does
not run this round**; the fixes are applied and the branch returns for a fresh review.

**Approach**

- **IMPORTANT — Retractions are reviewed before they can exist** → **fix, minimal variant.**
  The step-6 prompt's retraction clause is removed: step 6 runs before approval and cannot
  observe an amendment log that only exists after step 9, so the clause claimed a check that
  could never happen. Retraction and amendment review is handed to **OPS-18** (the
  already-filed /review-side companion), which is where post-implementation falsification
  review belongs. The scope-expanding variant — stating the rubric once in the shared
  reviewer contract so both phases apply it — was **declined for this story**: it is a
  larger one-way door than this story was framed for, and a cross-cutting contract change
  should not be made as a mid-round addendum.
  - **AC5 amended:** the step-6 prompt covers surface enumeration, the `surfaces excluded`
    claim, and circular oracles — **not** retractions.
  - **AC7 amended:** `BACKLOG.md` added to the permitted file list, for the one-line OPS-18
    addition that carries the handoff.
  - **Known limit added:** retraction review is unassigned until OPS-18 ships. Recorded
    rather than silently claimed.

- **IMPORTANT — Whole-plan mechanical N/A bypasses the per-AC invariant** → **fix.**
  `N/A — mechanical` may waive the per-row regression/oracle detail, but **every AC still
  carries its `surfaces excluded` line** in one of the three permitted forms. The extent
  claim stops being conditional on a self-applied story-level label.
  - **AC2 amended** to state the narrowed carve-out.

## Design decisions (2026-08-03)

Thomas: **"fix all three, skipping line for every promise"**.

- **Finding 1 (amendment model) → fix.** Approved plan tables are frozen at the `spec:`
  commit; all post-approval change goes in one `## Falsification-plan amendments` log with
  action / AC / target surface / reason / `added at: implement`. Now AC4.
- **Finding 2 (surfaces vs mechanisms vs limits) → fix.** `surface` is defined as a place in
  the product, explicitly not a mechanism; `surfaces excluded` names product surfaces only;
  reviewer-judgment quality and amendment volume moved to **Known limits** prose. This
  spec's own Test notes rewritten accordingly — the worked example is what future stories
  copy, which is why the fix lands here too.
- **Finding 3 (circular oracle) → fix.** Generalised into a rule (AC3): no row may name as
  its oracle the mechanism whose failure is that row's regression. The offending AC4 row is
  dropped; its subject is recorded under Known limits.
- **Open question (`surfaces excluded` scope) → every AC, three-valued.** Keeps the cheap
  presence check (a script can assert the line exists on every AC); accepts that the field
  reads `n/a` on single-observable criteria. Two-way door.
