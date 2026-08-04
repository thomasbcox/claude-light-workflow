# approach-on-fireworks

Date: 2026-08-04 · Branch: claude/approach-on-fireworks · Status: proposed

## Problem

Codex credits are running low. Codex runs the **design** pass once per story but the **approach**
pass once per *round*, so approach is what scales with the burn — a three-round story is four codex
invocations, three of them approach. Moving approach to `fireworks` is the single change that most
reduces credit consumption.

The predecessor story deliberately left this as the follow-up and pre-routed `approach` in
`fireworks-models.json` so wiring it would be a pass-table entry plus a dispatch line.

## In scope

- Wire the `approach` altitude to the fireworks runner: pass-table entry, its context profile, and
  the `review/SKILL.md` step-6 dispatch.
- Route `approach` to `fireworks` in this repo's `.claude/workflow.json`.
- Update the docs and routing-table rationales that say approach is unwired.

## Non-goals

- **Wiring the `design` pass.** It stays on `codex` deliberately, not by omission: it runs once per
  story, so it is the cheapest codex consumer, and it is where codex has demonstrably produced the
  highest-leverage findings (its two design BLOCKERs reshaped the predecessor story). Spending
  remaining credits there is the best use of them.
- Changing the approach→correctness gate, the decision menu, or any codex command block.
- Judging whether fireworks is *as good as* codex at this altitude — see Known limits.

## Acceptance criteria

1. **`approach` runs on the fireworks runner.** A pass-table entry binds it to
   `design-review-schema.json` (severity + reversibility + standing + alternative + win), its own
   prompt, and `reviews/<slug>.approach.json` — the same artifact the codex path writes, so step 7
   reads it identically. It runs through the existing assemble → validate → promote path; no second
   code path.
2. **Its context profile is shape-level.** The approach altitude judges shape, which a diff cannot
   show. The runner pushes the **whole contents of every changed file** plus any dependency
   manifest, in addition to the diff, log, contract, and story.
3. **Changed files are read at HEAD, never from the working tree.** The diff is computed against
   HEAD; reading the working tree would splice two snapshots into one payload and let uncommitted
   work reach a review of committed work.
4. **An absent dependency manifest is stated, not omitted.** Repos without a manifest are normal.
   The payload says so explicitly so the reviewer knows the input was not withheld — a silent
   omission would leave it unable to tell "no manifest" from "manifest not provided".
5. **Dispatch and config updated.** `review/SKILL.md` step 6 dispatches by resolved backend;
   `.claude/workflow.json` routes `approach` to `fireworks`; `README.md`, `ARCHITECTURE.md`, and the
   routing table no longer describe approach as unwired. The design pass remains the only unwired
   pair and still stops loudly.
6. **Scope containment.** `git diff --name-only main...HEAD` shows no files beyond those these ACs
   enumerate, excluding this story's own `reviews/` trail.

## Build note (2026-08-04)

| AC | Files |
|---|---|
| 1 — `approach` runs on the runner | `.claude/skills/review/fireworks_runner.py` (`PASSES["approach"]`, `ALTITUDES["approach"]`) |
| 2 — shape-level context profile | `fireworks_runner.py` (`CONTEXT_SOURCES["changed_files"]`, `["manifest"]`, `MANIFEST_NAMES`) |
| 3 — changed files read at HEAD | `fireworks_runner.py` (`_changed_files`), `tests/fireworks_runner_test.py` |
| 4 — absent manifest stated, not omitted | `fireworks_runner.py` (`_manifests`, `assemble_context` optional branch) |
| 5 — dispatch + config + docs | `.claude/skills/review/SKILL.md` (step 6, backend list, unwired-stop scope), `.claude/workflow.json`, `.claude/skills/review/fireworks-models.json`, `README.md`, `ARCHITECTURE.md`, `tests/reviewer_test.sh` |
| 6 — scope containment | (no file — verified against the branch diff) |

## Test notes

Gate: unchanged suite list; 355 → 362 checks, all additions behavioral.

| AC | Check | Regression that drives it red |
|---|---|---|
| 1 | `approach altitude runs` + writes `demo.approach.json` | Remove the `approach` entry from `ALTITUDES`; the altitude is unknown and the run aborts |
| 2 | `pushes whole changed files, not just the diff` | Drop `changed_files` from the pass's context list; the payload no longer contains file bodies |
| 3 | `uncommitted working-tree edits never reach the reviewer` | Read via `cat <name>` instead of `git show HEAD:<name>` — **demonstrated red** |
| 4 | `states manifest absence explicitly rather than omitting it` | Treat `manifest` as required; a repo without one aborts instead of proceeding |
| 5 | `this repo routes approach+…to fireworks, design to codex` (exact match) + dispatch pins | Revert `approach` to `codex` in `workflow.json`; the exact-match assertion fails |
| 6 | `git diff --name-only main...HEAD` | Manual |

**AC-3 was found by running it, not by planning it.** The first live approach run reviewed the
merged predecessor diff while reading my *uncommitted* work from the working tree, and reported
confidently on a state that exists in no commit. The oracle was written afterward, from the failure.
Recording that honestly because it is the pattern worth noticing: the live run found the bug; the
plan did not.

**AC-5's exact-match assertion replaces a faulty one.** The previous check used the glob
`*"fireworks fireworks"`, which matched any string ending in those two words and therefore could not
detect what the first two positions held. A reviewer caught it. It is now an exact match on all four.

## Fireworks approach review (2026-08-04, base main, HEAD c234375)

*First approach pass run by the `fireworks` backend — the wiring reviewing itself.*

**Verdict: approve-with-concerns.**

### IMPORTANT — `_manifests` reads the working tree, not HEAD
*two-way · nonstandard · locus: `fireworks_runner.py` — `_manifests` (rglob + read_text)*

AC-3 establishes reading at HEAD as a load-bearing invariant: the diff is computed against HEAD, so
reading the working tree splices two snapshots and lets uncommitted work reach a review of committed
work. `_changed_files` honours it via `git show HEAD:<name>`. `_manifests` does not — it uses
`rglob` + `read_text()`, straight off the working tree. Two failure modes: a manifest that is *also*
a changed file appears twice in the payload, at HEAD and from the working tree, contradicting itself
if there are uncommitted edits; and a manifest that is not a changed file carries uncommitted edits
into the review — precisely the class AC-3 exists to prevent.

**Alternative:** resolve each candidate relative to the root and `git show HEAD:<relative_path>`;
manifests absent at HEAD fall into the same "NOT INCLUDED" listing `_changed_files` already uses.
**Win:** one invariant — *every context source reads at HEAD* — replaces two rules and removes a
contradiction the reviewer cannot resolve.

## Decisions — approach pass (2026-08-04)

| Finding | Decision |
|---|---|
| IMPORTANT — `_manifests` reads the working tree, not HEAD | **Fix** — *"fix please"* |

A tidy, not a redesign: it applies a pattern already established in the same file, so the shape is
blessed and the correctness pass continues in this round.

## Fixes — approach round (2026-08-04)

`_manifests` now reads at HEAD, and the invariant is uniform: **every context source reads at HEAD**.
Manifests are discovered via `git ls-tree -r --name-only HEAD` and read with `git show HEAD:<path>`,
so no working-tree content reaches the payload from any source.

One addition beyond the literal finding: an **untracked** manifest is now *named* in the payload,
contents withheld. Without it, a repo whose only manifest is uncommitted would report "no manifest"
— a silent omission of the same kind the absent-manifest statement (AC-4) exists to prevent. Names
only, because including contents would reintroduce the leak just fixed.

*Red demonstrated:* reverting the manifest read to the working tree trips
`uncommitted manifest edits never reach the reviewer`. Suite 85 → 89 checks; gate 362 → 366.

## Fireworks review (2026-08-04, base main, HEAD e05e229)

**No findings.** The change wires the approach altitude via a pass-table entry, two context sources,
dispatch updates, and routing. All ACs appear satisfied — pass-table entry with
`design-review-schema`, shape-level context profile, reads at HEAD, absent manifest stated,
dispatch/config/docs updated. Tests cover the key invariants.

## Hidden-failure review (2026-08-04, base main, HEAD e05e229)

### IMPORTANT — `_manifests` silently drops a manifest it found but could not read

Candidates are discovered via `git ls-tree -r --name-only HEAD`, then read with
`git show HEAD:<rel>` under `check=False`. On a non-zero return the code does `continue` — the
manifest vanishes from the payload with no accounting. The reviewer cannot distinguish *"a manifest
exists at HEAD but was unreadable"* from *"no manifest exists at HEAD"*, which is exactly the silent
omission AC-4 was written to prevent.

The asymmetry is visible one function up: `_changed_files` appends every unreadable file to a
`skipped` list and emits a "NOT INCLUDED" section. `_manifests` — the same function that goes to
lengths to state absence explicitly and to name untracked manifests — has no equivalent. If
`git show` fails (encoding, a git internal error, a submodule edge case) the review proceeds
degraded, missing a manifest the reviewer was never told existed.

## Decisions — correctness round (2026-08-04)

**Correctness (fireworks):** no findings — nothing to decide.

**Hidden-failure (fireworks):**

| Finding | Decision |
|---|---|
| IMPORTANT — `_manifests` silently drops a manifest it found but could not read | **Fix** — *"fix it then /close"* |

Routing to `/close`. Not a merge authorization — `/close` stops at its fork.

### Known limits

- **Fireworks is unproven at this altitude, on a sample of one.** Run head-to-head against codex on
  the identical diff, it found three findings codex did not (including the faulty test glob above)
  and missed the two codex did find (the atomicity overclaim, the `--model` metadata split). That is
  *different*, not clearly worse or better — and one comparison cannot settle it. The honest position
  is that this trades an unmeasured amount of approach-altitude quality for a large credit saving,
  and the trade is worth revisiting after a few stories rather than declared settled now.
- **Whole changed files make the approach payload much larger than correctness'.** The size guard
  covers it against `glm-5p2`'s 1M window, but a very large branch will trip the guard where the
  correctness pass would have fit. That is the guard working, not a defect — but it will be the first
  place this shows strain.

## Design sketch — HOW

A pass-table entry and two context sources; no new orchestration, exactly as the predecessor's design
sketch predicted.

- **Pass table** — `approach` binds `design-review-schema.json`, the shape-level prompt (adapted from
  the codex prompt, minus the instructions to *run* commands it cannot run, plus an instruction to
  raise a finding rather than assume if something it needs was not provided), and the existing
  artifact path.
- **`ALTITUDES["approach"] = ["approach"]`** — one pass, so no fan-out, but it goes through the same
  assemble → validate → promote path so the guarantees are identical.
- **Two new context sources.** `changed_files` reads each changed path via `git show HEAD:<path>`,
  and lists anything it could not include rather than dropping it silently. `manifest` globs the
  common manifest names and, finding none, says so in the payload.
- **Optional inputs, declared.** `CONTEXT_SOURCES` entries may set `optional: True`; an optional
  input that is empty is recorded as "(none present in this repository)" instead of aborting.
  Required inputs still abort. This is the minimum change that lets a legitimately-absent input
  coexist with the fail-closed rule.

**Process note — the `/frame` design review was skipped, deliberately.** This shape was design
reviewed as part of the predecessor story, which specified adding these passes as "a table entry, not
new orchestration", and the implementation is exactly that. Re-reviewing it would have re-tread
blessed ground and spent a codex design call — the resource this story exists to conserve. Flagged
here rather than done silently: if you disagree, the remedy is to run `/review approach codex` once
and let codex judge the shape.
