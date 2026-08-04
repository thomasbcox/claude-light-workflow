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
