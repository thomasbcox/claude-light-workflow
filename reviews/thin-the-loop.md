# thin-the-loop

Date: 2026-08-04 · Branch: claude/thin-the-loop · Status: approved

## Problem

The loop's ceremony has outgrown what it earns. Measured on the story that just shipped
(`fireworks-reviewer-backend`, merge `b04b15d`):

- The story file was **722 lines** governing a **2,198-line** change.
- The gate is dominated by grep-for-a-string assertions on Markdown rather than behavioral checks.
- `/deep-audit` is the largest skill at **258 lines** and its execution engine was retired
  2026-08-03, so it produces a costed plan for an audit nothing can run.

The decisive evidence is *what actually caught defects*. Six real defects were found in that story —
the `{}` silent-clean bug, partial promotion, CI gate drift, a too-narrow `finish_reason`, stale
`llm` references in two docs, and an 8k output truncation. **None was caught by the falsification
plan.** Every one came from a reviewer reading code, a behavioral test, or a live run. Meanwhile the
plan's own extent claim — the thing it exists for — under-enumerated **twice** in that single story,
both misses caught by hand.

So: the review loop catches bugs; the ceremony around it does not. This story removes the ceremony
and keeps the loop.

A second, immediate pressure: Codex credits are running low. Cutting `/deep-audit` and the pins
reduces what every review round has to read and re-verify.

## In scope

- Retire `/deep-audit` entirely — skill, schema, test suite, install entry, gate entry (local **and**
  CI), and doc references — preserved as a tag, matching how its engine and lib were retired.
- Reduce the falsification plan to **demonstrate-red**: write the test, prove it goes red, record it.
  Drop the (AC, surface) matrix, the `surfaces excluded` three-form declaration, and the append-only
  amendment log.
- Prune the wording pins to those guarding invariants whose silent failure degrades behaviour.
- Add the one structural check that makes AC-1's own oracle real (AC-7).
- Keep the gate green with no loss of *behavioural* coverage.

## Non-goals

- Changing `frame → review → close` itself. The loop stays; only its paperwork shrinks.
- Touching the behavioural suites (`fireworks_runner_test.sh`, `guard_test.sh`) — those are real
  oracles and are the thing being protected.
- Removing demonstrate-red. It is the part with teeth and it stays mandatory.
- Retiring `/dev-audit`. It has a live consumer (pre-loop recon) and is out of scope here.
- Reworking the reviewer backend seam. Separate story.

## Measured baseline

The gate is green on `main` at **368 checks**, not the 355 the draft cited. Measured
2026-08-04:

| Suite | Checks | Character |
|---|---|---|
| `guard_test.sh` | 19 | behavioural (hook) |
| `reviewer_test.sh` | 102 | ~11 behavioural, ~91 wording pins |
| `fireworks_runner_test.sh` | 91 | behavioural |
| `dev_audit_test.sh` | 46 | drift (out of scope, Q3) |
| `deep_audit_plan_test.sh` | 97 | drift — deleted by AC-1 |
| `docs_test.sh` | 13 | structural |

Expected landing point: **~190**. Behavioural checks must not move.

## Acceptance criteria

1. **`/deep-audit` retired.** `.claude/skills/deep-audit/` and `tests/deep_audit_plan_test.sh` are
   removed; the `install.sh` ARTIFACTS entry, the `.claude/workflow.json` `testCommand` entry, **and
   the `.github/workflows/ci.yml` gate command** are updated in lockstep; `README.md`,
   `ARCHITECTURE.md`, `ROADMAP.md`, and `BACKLOG.md` no longer present it as an available skill. The
   removed tree is preserved as an annotated tag `retired/deep-audit-plan` with a recovery command
   recorded in `BACKLOG.md`, matching `retired/deep-audit-engine` and `retired/deep-audit-lib`.

   *`ci.yml` added at the frame consult.* It hardcodes the gate command, and `reviewer_test.sh`
   compares it byte-for-byte against `workflow.json` — a behavioural check. Editing one without the
   other turns the gate red, so it was never optional; the draft simply omitted it from the file
   list, which would have put AC-1 in conflict with AC-6.

2. **Falsification plan reduced to demonstrate-red.** `frame/SKILL.md` step 5 requires only: for each
   AC, how it will be checked, and — where the oracle is the gate — that the check be demonstrated
   red before done. The (AC, surface) row matrix, the `surfaces excluded` declaration and its three
   permitted forms, and the `## Falsification-plan amendments` append-only log are gone. Step 6's
   reviewer prompt no longer asks for critique of surfaces, exclusions, or circular oracles.

3. **Demonstrate-red survives intact.** Step 9 still requires: apply the planned regression, run the
   gate, observe the named check fail, revert, record. A gate-oracle AC that cannot be driven red is
   still a dead assertion and still stops the story.

4. **Wording pins pruned.** A pin is retained only if its silent failure would let behaviour degrade
   unnoticed — the fail-closed promote, the no-silent-fallback rule, the unwired-backend stop, the
   read-only posture, and the absolute-schema / repo-relative-`-o` split. Every other `has`/`absent`
   pin is removed. The retained set is stated with its reason at the top of `tests/reviewer_test.sh`,
   so the next person knows the bar rather than guessing it.

5. **No behavioural coverage lost.** Every `check(` in `tests/fireworks_runner_test.py` and every
   behavioural assertion in `guard_test.sh` and `dev_audit_test.sh` still runs and still passes. The
   `reviewer_test.sh` behavioural block — the backend resolver, the backend-artifact presence loop,
   the fireworks-suite-in-gate check, and the CI-vs-config comparison — survives the prune intact.
   The gate is green.

6. **Scope containment.** `git diff --name-only main...HEAD` shows no files beyond those the ACs
   enumerate, excluding this story's own `reviews/` trail.

7. **Docs cannot advertise a retired skill.** *(Added at the frame consult.)* `tests/docs_test.sh`
   gains the reverse of the check it already makes: every `/command` referenced in `README.md` or
   `ARCHITECTURE.md` must correspond to a skill actually deployed by `install.sh`'s ARTIFACTS block.

   *Why this earns its place under AC-4's own bar.* The existing check runs one way only —
   deployed ⇒ documented. Verified by experiment on `main`: appending a stray `/deep-audit`
   mention to `README.md` leaves `docs_test.sh` green at 13/0. So the draft's AC-1 oracle
   ("re-add a reference, the docs suite goes red") described a check the repo does not have — a
   dead assertion, which step 9 says to fix rather than paper over. Documentation promising a
   command that does not exist is user-facing breakage, and this story is precisely the event that
   creates that risk. The check is structural — derived from `install.sh`, not coupled to any
   wording — so it is not the kind of pin AC-4 removes.

## Test notes

Gate after AC-1: `guard_test.sh && reviewer_test.sh && fireworks_runner_test.sh && dev_audit_test.sh
&& docs_test.sh` — `deep_audit_plan_test.sh` is gone, in both `.claude/workflow.json` and
`.github/workflows/ci.yml`.

Expected movement: **368 → roughly 190 checks**, of which 97 are the deleted `/deep-audit` drift
suite, 2 are the deep-audit rows `docs_test.sh` stops generating once it leaves ARTIFACTS, and the
remainder are pruned pins. **Behavioural checks must not move.** That asymmetry is the whole point
and is the headline result for the build note: pins down sharply, oracles unchanged.

*The draft claimed it would write its plan under the rules it is removing. It did not — it used the
reduced form throughout, and this file keeps that.* Writing a full (AC, surface) matrix for the story
that deletes the (AC, surface) matrix is ceremony for its own sake, which is the thing under
argument. The plan below is the reduced form the story is moving to; that is the honest description
and the reviewer should judge it as such.

### Demonstrate-red plan

| AC | How it is checked | Regression that must drive it red |
|---|---|---|
| 1 | `docs_test.sh`'s new reverse check (AC-7) | Re-add a `/deep-audit` reference to `README.md` after the skill leaves ARTIFACTS; the docs suite goes red |
| 1 | `install.sh --check` against a temp `CLAUDE_WORKFLOW_DEST` | Leave the ARTIFACTS entry pointing at the deleted tree; `--check` reports MISSING |
| 1 | `reviewer_test.sh`'s CI-vs-config comparison | Drop the suite from `workflow.json` but not `ci.yml`; the drift check goes red |
| 1 | The retirement tag resolves | `git rev-parse retired/deep-audit-plan` fails if the tag was never written |
| 2 | `reviewer_test.sh` asserts the removed machinery is absent from `frame/SKILL.md` | Leave `surfaces excluded` in step 5; the pin goes red |
| 3 | `reviewer_test.sh` asserts demonstrate-red survives | Remove "demonstrate red before done" from step 9; the pin goes red |
| 4 | The retained pins still fail on real drift | Break the fail-closed promote wording in `review/SKILL.md`; its pin goes red |
| 5 | The full gate | Break one `check(` in `fireworks_runner_test.py`; the gate exits non-zero |
| 6 | `git diff --name-only main...HEAD` | Manual — verify no file beyond the ACs' list, excluding this story's `reviews/` trail |
| 7 | `docs_test.sh` fails closed on an undeployed `/command` | Same regression as AC-1 row 1 — that is the point of adding it |

**AC-4 has no mechanical oracle and does not pretend to.** "Is this pin load-bearing?" is judgment,
and the honest oracle is the reviewer at the approach altitude. Naming that here rather than
inventing a count to check against is exactly the kind of thing this story is trying to restore.
(The row above checks something narrower and real: that the pins *kept* still fail on real drift.)

### Demonstrate-red results (2026-08-04)

Every gate-oracle row was driven red, observed, and reverted. Nothing below was inferred.

| AC | Regression applied | Observed |
|---|---|---|
| 1, 7 | Dropped the ARTIFACTS entry with `/deep-audit` still in README | `FAIL docs advertise /deep-audit but install.sh does not deploy it`, exit 1 |
| 1 | Kept a dangling ARTIFACTS entry after deleting the tree | `DRIFT skills/deep-audit — MISSING from deployment`, exit 1 |
| 1 | Dropped the suite from `workflow.json` but not `ci.yml` | `FAIL CI gate runs exactly the configured gate (no drift)`, both strings printed, exit 1 |
| 1 | — | `git rev-parse retired/deep-audit-plan` resolves |
| 2 | Re-inserted `surfaces excluded` into step 5 | 2 pins red (`no (AC, surface) matrix`, `no three-form exclusion declaration`), exit 1 |
| 3 | Replaced "demonstrate red before done" in step 9 | `FAIL step-9 demonstrate-red`, exit 1 |
| 4 | Broke the fail-closed promote wording in `review/SKILL.md` | `FAIL failed review publishes nothing`, exit 1 |
| 5 | Inverted `check("empty object {} is rejected", …)` | Full gate exit 1; `FAIL empty object {} is rejected — rc=1` |
| 6 | — | Manual: 14 files, each mapped to an AC; see below |

**AC-1's first row was rewritten, not massaged.** As drafted it named `docs_test.sh` as the oracle
for a stale doc reference. Tested on `main` first: that check did not exist — the suite stayed green
at 13/0 with a stray `/deep-audit` line in `README.md`. Step 9 says a check that cannot be driven red
is a dead assertion and the fix is the test, not the note. That is what AC-7 is.

### Result

Gate green at **202 checks**, from 368.

| Suite | Before | After | |
|---|---|---|---|
| `guard_test.sh` | 19 | 19 | behavioural — unchanged |
| `fireworks_runner_test.sh` | 91 | 91 | behavioural — unchanged |
| `dev_audit_test.sh` | 46 | 46 | out of scope (Q3) — unchanged |
| `reviewer_test.sh` | 102 | 30 | behavioural core 11 → 11; pins 91 → 19 |
| `deep_audit_plan_test.sh` | 97 | — | deleted with the skill |
| `docs_test.sh` | 13 | 16 | −2 deep-audit rows, +5 reverse checks |
| **Total** | **368** | **202** | |

**166 checks removed, 0 behavioural checks lost.** Behavioural coverage went from 167 to 167 and
gained 5: the reverse deployed-command check that closes the hole AC-1's own oracle fell into.
`frame/SKILL.md` step 5 went from six sub-bullets of matrix rules to one paragraph.

### Scope containment (AC-6)

`git diff --name-only main...HEAD` — 14 files, each mapped to the AC that authorises it:

- AC-1 (10): `.claude/skills/deep-audit/SKILL.md`, `.claude/skills/deep-audit/plan-schema.json`,
  `tests/deep_audit_plan_test.sh`, `install.sh`, `.claude/workflow.json`,
  `.github/workflows/ci.yml`, `README.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `BACKLOG.md`
- AC-2 / AC-3 (1): `.claude/skills/frame/SKILL.md`
- AC-4 (1): `tests/reviewer_test.sh`
- AC-7 (1): `tests/docs_test.sh`
- Excluded per AC-6: `reviews/thin-the-loop.md` (this story's own trail)

No file outside that list. Two consequential edits were made inside AC-1's files that the draft did
not anticipate, both because the retirement made standing text false:

- `ROADMAP.md`'s open decision 1 ("deep-audit: core / plugin / park") is **answered by this story** —
  parked. Left as an open question it would have pointed at a decision already taken.
- `BACKLOG.md`'s OPS-18 claimed to own review of the `## Falsification-plan amendments` log. AC-2
  deletes that log, so the duty is discharged rather than owed. Left alone, OPS-18 would have carried
  a live obligation to review an artifact that no longer exists.

### Known limits

- **Pruning pins means some doc drift will go uncaught.** That is the accepted trade, not an
  oversight. Drift in prose that no invariant depends on is cheap to fix when noticed; ~91 pins that
  break on every rephrase are not cheap to maintain. If a specific drift later proves expensive, the
  answer is one new pin with a stated reason, not restoring the set.
- **Dropping the amendment log loses the audit trail of plan changes.** In practice that trail
  recorded my own corrections and was read by no one else. Git history retains the same information
  at lower ceremony.
- **This removes a discipline that has never been shown to fail loudly.** The argument against it is
  evidential — it caught nothing in the last story while missing twice — not that it caused harm.
- **The design review (step 6) was not run.** The sketch is deletion-ordering plus one ten-line
  additive check, and Codex credit scarcity is one of the two pressures motivating this story.
  Spending a design review on a deletion would be the wrong call against the story's own rationale.
  Recorded as a deliberate skip, not an omission.

## Resolved questions

Decided by Thomas at the frame consult, 2026-08-04:

- **Q1 — preserve `/deep-audit` as a tag, or delete outright?** → **Tag it.** Matches
  `retired/deep-audit-engine` and `retired/deep-audit-lib`; keeps the retirement convention legible
  for the next person.
- **Q2 — thin the falsification plan, or trial it first?** → **Cut it.** An optional discipline in a
  solo repo is one you either always write from habit or never write, and either way the instruction
  weight stays in every `/frame` invocation, which is the real cost.
- **Q3 — does `/dev-audit`'s 46-check drift suite get the same pruning?** → Out of scope, deferred.
  The same argument plausibly applies; it is not assumed here.

## Build note (2026-08-04)

AC → file map:

| AC | Files |
|---|---|
| 1 — `/deep-audit` retired | `.claude/skills/deep-audit/SKILL.md` (deleted), `.claude/skills/deep-audit/plan-schema.json` (deleted), `tests/deep_audit_plan_test.sh` (deleted), `install.sh`, `.claude/workflow.json`, `.github/workflows/ci.yml`, `README.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `BACKLOG.md` |
| 2 — falsification plan reduced | `.claude/skills/frame/SKILL.md` (steps 5, 6, 8), `BACKLOG.md` (OPS-18 duty discharged) |
| 3 — demonstrate-red survives | `.claude/skills/frame/SKILL.md` (step 9) |
| 4 — wording pins pruned | `tests/reviewer_test.sh` |
| 5 — no behavioural coverage lost | no files — verified by the gate |
| 6 — scope containment | no files — verified by `git diff --name-only` |
| 7 — docs cannot advertise a retired skill | `tests/docs_test.sh` |

The retirement tag `retired/deep-audit-plan` is a git object, not a file in the diff.

## Design sketch — HOW

Deletion, not construction. Order matters only so the gate stays green between commits:

1. **Tag first** (`git tag -a retired/deep-audit-plan`), so the tree is preserved before anything is
   removed and the recovery command in `BACKLOG.md` is true when written.
2. **Add AC-7's reverse check** to `docs_test.sh` *before* removing anything, so it is demonstrably
   the thing that catches the stale references AC-1 is about to create.
3. **Remove `/deep-audit`** — skill directory, schema, test file, `install.sh` ARTIFACTS entry,
   `testCommand` entry, `ci.yml` gate line — then the doc references, then `BACKLOG.md`'s retirement
   note. The existing `OPS-13` entry already records the engine and lib retirements; this appends the
   plan slice to the same note rather than opening a new one.
4. **Thin `frame/SKILL.md`** steps 5, 6, and 9 in one edit. The step-5 rewrite is the substantive
   one: it collapses roughly forty lines of matrix rules to a short paragraph — for each AC, how it
   is checked, and demonstrate-red where the oracle is the gate.
5. **Prune `tests/reviewer_test.sh`** last, since it pins the files edited above. The retained set
   gets a header comment stating the bar — *a pin earns its place only if its silent failure lets
   behaviour degrade unnoticed* — so the next person prunes by the same rule instead of re-growing
   the set.

No new files, no new dependencies. The one addition is AC-7's ten-line structural check, which exists
to make AC-1's own oracle real. The build note should lead with the two numbers that matter: pins
removed, behavioural checks unchanged.
