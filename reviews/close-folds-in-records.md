Date: 2026-06-17 · Branch: claude/close-folds-in-records · Status: approved

> **Approved 2026-06-17.** Thomas approved scope as written, choosing **O3**
> (close this story under the old `/close`; one-time in-session fold of this
> story's records after the merge instruction; run `install.sh` from `main`
> *after* merge — the next story is the first true dogfood) and **named story,
> CHANGELOG only** (no `OPS-` backlog item).

# Story: `/close` folds release records into the pre-merge branch; retire bookkeeping-only stories

## Problem

`BACKLOG.md`'s stated lifecycle ends `… → /close → CHANGELOG.md`, but `/close`
deliberately **writes nothing after the merge** (step 6: *"Nothing else is
written — the merge commit is the whole record"*; step 7: *"write nothing to the
base branch"*). That prohibition is correct in spirit — it came from the BUG-D1
fix that made git the single source of truth for *shipped* state — but it was
applied too broadly: it also stopped `/close` from recording the **declarative**
release facts (the `CHANGELOG.md` entry and the `BACKLOG.md` Done-move) that the
lifecycle promises.

The gap is filled today by a **separate bookkeeping story per shipped story** —
`bookkeeping-pr8-pr9`, `bookkeeping-pr11-pr12`, `bookkeeping-pr14-bug5` — whose
only job is to reconcile records the prior story left stale. Each such story is
itself a full `frame → review → close` cycle that, by the same doctrine, leaves
*its* records stale, so the pattern is a self-perpetuating ratchet.

The books are **currently out of balance** on `main`, demonstrating the gap live:
- `BACKLOG.md`'s BUG-5 Done row carries an unfilled placeholder: `PR #17 / <merge>`.
- `CHANGELOG.md` has **no `drop-shipped-tag` entry** (PR #17, merge `d994dfa`),
  because that story explicitly deferred its own bookkeeping
  ([drop-shipped-tag.md:82](reviews/drop-shipped-tag.md)).

Two root causes, addressed together:
1. **`/close` doesn't fold in the declarative records.** Fix: it writes the
   `CHANGELOG.md` entry and the `BACKLOG.md` Done-move **on the feature branch,
   after the merge instruction**, so they ride in on the merge commit — no
   separate base-branch write, and not speculative.
2. **Doctrine has no rule against bookkeeping-only follow-ups, and `BACKLOG.md`
   freezes derivable merge SHAs** (`b18993e`, `0504e31`, …) that go stale. Fix:
   state "no bookkeeping-only stories", and reference Done items by
   `PR #N / merge: <slug>` (the SHA is derivable via `git log --grep`).

## The BUG-D1 non-regression (read this carefully)

BUG-D1 was: `/close` pre-set `Status: merged` in the **story header**
*speculatively*, before the step-4 re-review/merge fork was answered — so a
re-review choice left a `merged` header on an unmerged branch. The lesson: never
write **observed/shipped** state until the merge is actually chosen and
happening.

This story does **not** reopen that, by these guards (tightened after Codex
BLOCKER #1, which correctly flagged the original over-broad claim):
- The new record-keeping lives **inside step 5**, ordered **preflight → record →
  re-gate → merge**, and runs **only after Thomas's distinct merge instruction**
  at the step-4 fork. Choosing re-review never reaches it; and the merge-strategy
  preflight (auto-merge / required-checks abort) runs **before** the record
  commit, so a *known-preventable* abort never leaves records on the branch
  either.
- **Precise claim (not the original over-broad one):** records are *never* written
  speculatively before the merge is chosen, and *never* reach the **base branch**
  except via the merge commit. A record commit **can** briefly sit on the *PR
  branch* while a **handed-off** merge is still pending (auto-merge waiting on
  async checks, or the local MERGED poll timing out after a valid hand-off) — but
  that branch is unmerged, so `main` never carries a premature record, and the
  pending merge completes the record when it lands. This is a strictly weaker,
  defensible statement than "records can never sit on an unmerged branch."
- The **story header is still untouched** — it stays `proposed → approved`, never
  `merged`. Whether it shipped remains *derived* from git (the SSOT discipline is
  intact).
- The records written are **declarative** ("this is what this branch delivers"),
  committed in the same atomic action that then issues the merge — exactly
  resolution **(c)** the BUG-D1 story pre-authorized (*"`merged` is set in the
  same step that issues the merge and is true within the same atomic action"*).
- The record commit is itself **re-gated** (step 5c) before push/merge, so the
  `--match-head-commit` shipped commit is the one that passed `testCommand`
  (Codex IMPORTANT #2).

## The deploy-ordering seam (the central open question — see Open questions)

The three skills run from their **deployed** copies in `~/.claude` (placed by
`install.sh`), not from this repo. So when *this* story reaches its own `/close`,
the `/close` skill that executes is the **old, un-folded** deployed copy — unless
`install.sh` is run first. And `install.sh` is a **hard overwrite of `~/.claude`
from the current checkout**: running it mid-story would deploy **unmerged
feature-branch** instructions to *every* repo on the machine. The decision of
*when* the new behavior goes live, and *how this story itself is closed*, is
deferred to Thomas in **Open questions** and must be recorded in this story so the
reviewer can audit it.

## In scope

- **`.claude/skills/close/SKILL.md`** — in step 5, before the merge recipe and
  gated on the merge instruction, add a record-keeping sub-step: write the dated
  `CHANGELOG.md` entry and (if the story resolves a tracked `BUG-`/`OPS-` item)
  move that `BACKLOG.md` row to **Done**, referenced as `PR #N / merge: <slug>`
  (never a raw SHA); commit on the feature branch; leave the header `approved`.
  State that this record-keeping is mechanical, rides post-review by design, and
  needs no separate review round or bookkeeping story. Reword step 6 so it no
  longer claims "nothing else is written" (records now ride in on the merge
  commit); fix the `localSha` comment to note HEAD now includes the record commit.
- **`.claude/workflow-protocol.md`** — loop step 3 mentions the record-keeping;
  add a doctrine note: records ride with the merge (not after it), and **no
  bookkeeping-only stories**.
- **`BACKLOG.md`** — rewrite the lifecycle paragraph (records land via `/close` on
  the branch; reference Done items by `PR #N / merge: <slug>`, not raw SHA; the
  no-bookkeeping-only-stories rule). **One-time squaring:** fix the BUG-5 row
  placeholder `<merge>` → `merge: drop-shipped-tag`.
- **`CHANGELOG.md`** — **one-time squaring:** add the missing dated
  `drop-shipped-tag (PR #17)` entry (an already-merged, observed fact — not
  speculative).
- **`reviews/close-folds-in-records.md`** — this story file (incl. the recorded
  deploy-ordering decision).

## Non-goals

- **No change to merge mechanics or the merge-approval gate** — the step-4 fork,
  the distinct-merge-instruction rule, `gh pr merge --auto`/direct strategy,
  `--match-head-commit`, and the MERGED poll are all untouched.
- **No guard-hook or test change** (`block-main-writes.sh`, `tests/guard_test.sh`).
  This is a doc/instruction change; the gate is unaffected.
- **No rewriting of historical records.** Existing `BACKLOG.md` Done rows that
  already carry raw SHAs stay as-is (the `PR #N / merge: <slug>` convention is
  forward-looking); past `CHANGELOG.md` entries are history.
- **No `README.md` or `/frame`/`/review` change** — neither contradicts the new
  flow.
- **No new `BUG-`/`OPS-` backlog item for this story**, and **no separate
  bookkeeping follow-up** — this story's own CHANGELOG entry is added at its
  `/close` per the rule it introduces (see Open questions for the transition).

## Acceptance criteria

1. **`/close` folds records in, gated after the merge instruction.**
   `close/SKILL.md` step 5 contains a record-keeping sub-step that (a) runs only
   after the distinct merge instruction, (b) writes the `CHANGELOG.md` entry and
   the `BACKLOG.md` Done-move on the feature branch, (c) commits them there, and
   (d) explicitly leaves the story header at `approved`.
2. **BUG-D1 non-regression is explicit and holds.** The skill text states the
   header is never set to `merged`, and that on a re-review choice no records are
   written. Nothing in the change writes observed/shipped state before the merge
   instruction.
3. **Records reach base only via the merge commit.** Step 6 no longer asserts
   "nothing else is written"; the hard constraint that the only base write is the
   merge commit itself is preserved (records ride in on it, written on the feature
   branch pre-merge).
4. **Done items are referenced by `PR #N / merge: <slug>`, not raw SHA.** The
   `BACKLOG.md` lifecycle paragraph states the convention and the derive-the-SHA
   method; the new BUG-5 row uses it.
5. **The no-bookkeeping-only-stories rule is in doctrine.** Both `BACKLOG.md` and
   `.claude/workflow-protocol.md` state it; `workflow-protocol.md` loop step 3
   references the record-keeping.
6. **The books are squared (one-time).** `BACKLOG.md`'s BUG-5 row reads
   `PR #17 / merge: drop-shipped-tag` (no `<merge>` placeholder remains), and
   `CHANGELOG.md` has a dated `drop-shipped-tag (PR #17)` entry.
7. **The deploy-ordering decision is recorded** in this story file (a resolved
   `## Open questions` / dedicated note), so the reviewer can audit the reasoning
   for when the new `/close` behavior goes live and how this story is closed.
8. **Gate green, guard/tests unchanged.** `bash tests/guard_test.sh` passes (still
   19 cases), and `git diff main...HEAD -- .claude/hooks/block-main-writes.sh
   tests/guard_test.sh` is empty.
9. **Scope containment.** `git diff --name-only main...HEAD` shows no files beyond
   `.claude/skills/close/SKILL.md`, `.claude/workflow-protocol.md`, `BACKLOG.md`,
   `CHANGELOG.md`, and `reviews/close-folds-in-records.md`.

## Test notes

- AC1–AC5, AC7: read the edited sections of `close/SKILL.md`, `BACKLOG.md`, and
  `workflow-protocol.md`; confirm the record-keeping is inside step 5 and gated on
  the merge instruction, the header stays `approved`, the convention and rule are
  present, and the deploy-ordering decision is written down.
- AC6: inspect the BUG-5 row in `BACKLOG.md` (no `<merge>` token) and the
  `drop-shipped-tag` entry in `CHANGELOG.md`.
- AC8: `bash tests/guard_test.sh` → `ALL GUARD TESTS PASSED`, `passed=19`; and the
  guard/test diff against `main` is empty.
- AC9: run `git diff --name-only main...HEAD` and verify no files appear beyond
  the five the AC enumerates.
- This story's own release record (the `close-folds-in-records` CHANGELOG entry)
  is intentionally **not** written during implementation — it is added at this
  story's `/close`, after the merge instruction, per AC1's flow and the
  Open-questions transition decision (so this story does not itself write a
  speculative pre-merge entry).

## Open questions

_Resolved at approval (2026-06-17): **(1) O3** — close this story under the old
`/close`, fold this story's records as a one-time in-session step after the merge
instruction, then `install.sh` from `main` after merge; the next story is the first
true dogfood. **(2) Named story, CHANGELOG only** — no `OPS-` item. The originally
analysed options are kept below for the reviewer's audit trail._

1. **Deploy ordering — the central decision.** When does the new, record-folding
   `/close` go live, and how is *this* story closed? `install.sh` hard-overwrites
   `~/.claude` from the current checkout, so deploying mid-story pushes unmerged
   feature-branch instructions machine-wide. Three options:

   - **(O1) Never install mid-story; close this story with the old deployed
     `/close`.** Safest for the machine, but the old `/close` won't fold this
     story's own records — I'd fold them *manually from this session's context*
     following the new design. Risk: relies on me overriding the (old) injected
     skill text from memory — the exact "trust the model to remember" the protocol
     warns against.
   - **(O2) Install mid-story (from the feature branch) before this story's
     `/close`, to dogfood the new step.** Maximum dogfood, but deploys
     **unmerged** instructions to every repo on the machine; if review forces a
     change or rejects, the machine is left on a feature-branch deploy. The
     OPS-2 manifest would stamp a feature-branch (possibly dirty) commit.
   - **(O3, recommended) Close this story under the old `/close`; fold this
     story's records as a deliberate one-time in-session step after the merge
     instruction; then run `install.sh` from `main` *after* merge.** The new
     behavior goes live only once merged; the **next** story is the first true
     dogfood. Never deploys from an unmerged branch. The one-time manual fold is
     bounded and human-gated, not a precedent (once deployed, the encoded skill
     carries it).

   **Recommendation: O3.** It keeps the "never deploy unmerged" invariant, avoids
   the machine-wide blast radius of O2, and avoids O1's reliance-on-memory while
   still not spawning a bookkeeping follow-up. Decision needed from Thomas.

2. **Should this story be logged as an `OPS-` backlog item** (e.g. OPS-10) so its
   Done-move exercises the new flow, or stay a named story with only a CHANGELOG
   entry (as `drop-shipped-tag` was)? Recommending **named story, CHANGELOG only**
   — it's a doctrine/process change, not a tracked defect/tooling gap.

## Build note (2026-06-17)

AC → file map:

- **AC1** (`/close` step 5 folds records, gated after the merge instruction) →
  `.claude/skills/close/SKILL.md`
- **AC2** (BUG-D1 non-regression stated; header never `merged`; re-review writes
  nothing) → `.claude/skills/close/SKILL.md` + the `## The BUG-D1 non-regression`
  argument in this story file
- **AC3** (records reach base only via the merge commit; step 6 reworded) →
  `.claude/skills/close/SKILL.md`
- **AC4** (`PR #N / merge: <slug>` reference convention, not raw SHA) → `BACKLOG.md`
- **AC5** (no-bookkeeping-only-stories rule; loop step 3 mentions record-keeping) →
  `BACKLOG.md`, `.claude/workflow-protocol.md`
- **AC6** (one-time squaring: BUG-5 row placeholder fixed; `drop-shipped-tag`
  CHANGELOG entry added) → `BACKLOG.md`, `CHANGELOG.md`
- **AC7** (deploy-ordering decision O3 recorded) → this story file (`## Open
  questions`, resolved)
- **AC8** (gate green; guard/tests unchanged) → no file change (verification)
- **AC9** (scope containment) → the five files above

## Codex review (2026-06-17, base main, HEAD 205c6d6)

**Summary:** 2026-06-17 12:10:16 PDT — Review of `main...HEAD` found two
substantive issues in the edited `/close` flow and one wording inconsistency. The
O3 deploy-ordering choice is recorded and is directionally consistent with avoiding
an unmerged `install.sh` deploy. Could not verify `bash tests/guard_test.sh` —
read-only sandbox prevented `mktemp`; the guard/test diff itself is empty.

### BLOCKER

1. **Release records can be left on an unmerged PR after a failed merge attempt**
   (`.claude/skills/close/SKILL.md:25`). Step 5 commits CHANGELOG/BACKLOG release
   records before invoking the merge path, but the same recipe can still abort
   afterward — e.g. auto-merge disabled with required checks detected, or the
   MERGED poll timing out. That contradicts the BUG-D1 non-regression claim that
   release records are not speculative and cannot remain on an unmerged branch: a
   valid merge instruction can still leave a pushed PR branch carrying
   `Done`/changelog records while no merge commit / PR `MERGED` exists.
   *Suggestion:* move all known merge preflight/abort checks before the
   release-record commit, and define an explicit cleanup path for any post-commit
   merge failure or timeout (revert/drop the record commit before stopping, or
   don't push it until the merge can actually be handed off).

### IMPORTANT

2. **Final merged HEAD is no longer gated after the release-record commit**
   (`.claude/skills/close/SKILL.md:28`). The gate runs in step 3, but step 5 then
   creates a new release-record commit and `localSha` is taken from that new HEAD.
   In the direct-merge path with no required checks, this untested HEAD is merged
   immediately, so `/close` no longer guarantees the exact shipped commit has
   passed `testCommand`. Even mechanical CHANGELOG/BACKLOG edits can break markdown
   or repository checks. *Suggestion:* after committing the step-5 records, re-run
   `testCommand` against that final HEAD before pushing/merging — no new review
   round needed, but it should be the gated commit `--match-head-commit` protects.

### NIT

3. **CHANGELOG instruction conflicts with the current file shape**
   (`.claude/skills/close/SKILL.md:26`). The skill says to "turn `[Unreleased]`
   into" a dated entry, but the changed `CHANGELOG.md` keeps `## [Unreleased]` and
   adds the dated entry below it. Read literally, future runs could delete the
   standing Unreleased section. *Suggestion:* reword to "add a dated entry
   immediately below `## [Unreleased]`, leaving the Unreleased section in place."

## Decisions (2026-06-17)

Thomas: "fix all these as suggested." All three findings → **fix**.

1. **BLOCKER #1 → fix.** Reorder `/close` step 5 so all local merge preflights/abort
   checks run *before* the release-record commit; the record commit is only made
   once the merge can actually be handed off. Tighten the BUG-D1 non-regression
   wording (skill + story) to be precise: release records may briefly ride a PR
   branch while a *handed-off* merge is pending, reach base only via the merge
   commit, and the header is never set to `merged`.
2. **IMPORTANT #2 → fix.** After the step-5 record commit, re-run `testCommand`
   against that HEAD before push/merge, so the shipped (`--match-head-commit`)
   commit is the gated one. No new review round.
3. **NIT #3 → fix.** Reword the CHANGELOG instruction to "add a dated entry
   immediately below `## [Unreleased]`, leaving the Unreleased section in place."

## Fixes (2026-06-17)

All three approved findings applied; scope unchanged (same five files).

1. **BLOCKER #1** → `.claude/skills/close/SKILL.md` step 5 restructured to
   **preflight → record → re-gate → merge**: the merge-strategy preflight
   (auto-merge / required-checks abort) now runs in **(a)**, *before* the
   release-record commit in **(b)**, so a known-preventable abort never leaves
   records on the branch. The BUG-D1 non-regression section in this story file was
   tightened from the original over-broad claim to the precise one (records never
   reach *base* except via the merge commit; a record may briefly sit on an
   unmerged *PR branch* only while a handed-off merge is pending).
2. **IMPORTANT #2** → added step 5**(c)**: re-run `testCommand` against the record
   commit HEAD before push/merge, so the `--match-head-commit` shipped commit is
   the gated one. `localSha` comment updated to "gated record HEAD".
3. **NIT #3** → step 5(b) CHANGELOG instruction now reads "add a dated
   `## [<date>] — <slug> (PR #N)` entry **immediately below** `## [Unreleased]`,
   leaving the Unreleased section in place."

## Codex review (2026-06-18, base 205c6d6, HEAD ba83005) — round 2 (diff-only)

**Summary:** 2026-06-18 07:14:21 PDT — The re-gate, tightened BUG-D1 wording,
CHANGELOG instruction, and doctrine files are consistent, but the reordered shell
recipe introduces a blocker: its preflight decision does not survive into merge
dispatch.

### BLOCKER

1. **Preflight merge strategy is lost before merge dispatch**
   (`.claude/skills/close/SKILL.md:59`). `autoMerge` is assigned in the separate
   (a) shell block, then used in (d) after the record and gate operations. Shell
   variables do not survive separate command invocations, so ordinary execution
   reaches (d) with `autoMerge` empty and incorrectly selects direct merge. If (a)
   cleared because auto-merge was enabled despite required checks, the (d)
   direct-merge assumption is false; the direct merge can fail after the record
   commit is pushed, recreating the prior BLOCKER. *Suggestion:* persist and reload
   an explicit `auto`/`direct` merge mode across phases, or make (d) select an
   explicit command from a recomputed preflight result. Abort if the mode is
   missing; never default an unset value to direct merge.

## Decisions (2026-06-18)

Thomas: "sure try fixing." Round-2 BLOCKER #1 → **fix**.

- Make `/close` step 5(d) **self-contained and authoritative**: recompute
  `autoMerge` + `reqChecks` there (vars from (a) do not survive a separate
  invocation) and run the full 3-way decision. **Decide the mode before `git
  push`** so a backstop abort never pushes the record commit. **Explicit mode with
  abort-on-unknown** (`case "$autoMerge"` → `true`/`false`/`*`-abort); never
  default an unset value to direct merge. Keep (a) as the *early* abort (fast-fail
  before records); (d) is the authoritative gate and is correct even if (a) were
  skipped.

## Fixes (2026-06-18) — round 2

Round-2 BLOCKER #1 applied in `.claude/skills/close/SKILL.md` step 5; scope
unchanged.

- **(d) is now self-contained**: it recomputes `autoMerge` + `reqChecks` (the (a)
  vars don't survive a separate shell invocation) and runs the full 3-way logic.
- **Mode decided before `git push`**, via an explicit `case "$autoMerge"` →
  `auto` / `direct` / `*`-abort. The unknown/empty case **aborts** instead of
  defaulting to a direct merge; the disabled+required-checks case aborts before
  pushing — so a backstop abort never pushes the record commit.
- **(a) reframed** as the *early* fast-fail; (d) is the authoritative gate, correct
  even if (a) were skipped.

## Codex review (2026-06-18, base ba83005, HEAD 9fec4bd) — round 3 (diff-only)

**Summary:** 2026-06-18 08:10:03 PDT — The round-2 BLOCKER is closed and step 5(d)
otherwise preserves the required safeguards, but step 5(a) is inconsistent with the
new authoritative unknown-state gate.

### BLOCKER

1. **Early preflight permits a known-invalid unknown mode**
   (`.claude/skills/close/SKILL.md:26`). Step 5(a) claims to stop known-preventable
   failures before records are committed, but its condition only aborts when
   required checks are positive. If `autoMerge` is empty or unknown and `reqChecks`
   is zero, (a) clears, (b) commits release records, and the new authoritative `*`
   branch in (d) then aborts. This leaves records on a branch without a handed-off
   merge, contradicting the preflight ordering and BUG-D1 framing. *Suggestion:*
   give step 5(a) the same three-way `case "$autoMerge"` policy as (d) — allow
   `true`, allow `false` only with zero required checks, abort unknown/empty values
   before creating records — keeping (d)'s independent recomputation as the
   authoritative backstop.

> **Note (round 3 — recurring defect class).** This is the **third consecutive
> BLOCKER in this one recipe**, and all three are the same shape: a
> *consistency* defect between step 5(a) and step 5(d), which duplicate the
> merge-strategy policy in two places. Patching (a) to mirror (d) (Codex's
> suggestion) fixes this instance but leaves two copies of a three-way policy to
> keep in sync forever — the exact surface that produced rounds 2 and 3. Decision
> for Thomas at the fork: targeted patch vs. simplify to a single decision point.

## Decisions (2026-06-18) — round 3

Thomas: "fix via B." Round-3 BLOCKER #1 → **fix via Option B (simplify to a single
decision point)**, not the targeted patch.

- `/close` step 5(a) **decides the merge mode once** via the three-way
  `case "$autoMerge"` (`true`→`MODE=auto`; `false`→abort if required checks else
  `MODE=direct`; `*`→abort). **Every** abort happens here, before any record, so a
  known-preventable failure never leaves records on the branch.
- Step 5(d) **dispatches the `MODE` decided in (a)** — push, then run the single
  `gh pr merge` command for that mode (the only difference is the `--auto` flag),
  then poll. No recomputation, no second copy of the policy → the (a)/(d)
  consistency surface that produced rounds 2 and 3 is removed. (d)'s only abort is
  the MERGED-poll timeout (a handed-off-merge case). This avoids the round-2
  shell-var trap: (d) does not read an (a) shell variable; it runs the command
  matching (a)'s printed `MODE`.

## Fixes (2026-06-18) — round 3 (Option B)

Round-3 BLOCKER #1 fixed by simplification, **superseding** the round-2
(d)-recomputes approach.

- **`/close` step 5(a)** is now the single merge-strategy decision: a three-way
  `case "$autoMerge"` that prints `MODE=auto` / `MODE=direct` or **aborts**
  (`false` + required checks, or unknown/empty `autoMerge`). All aborts happen
  before (b), so a known-preventable failure never commits records.
- **Step 5(d)** no longer recomputes or re-decides — it pushes and dispatches the
  single `gh pr merge` command for `MODE` (only the `--auto` flag differs), then
  polls. The (a)/(d) policy duplication that caused the round-2 and round-3
  BLOCKERs is gone; there is exactly one decision point.
- The `*`-abort lives only in (a) now, so the round-3 gap (unknown mode clearing
  (a) but aborting (d) after records) is structurally impossible.

## Codex review (2026-06-18, base 9fec4bd, HEAD 2b072ef) — round 4 (diff-only)

**Summary:** 2026-06-18 09:55:26 PDT — Round-3 BLOCKER is closed. Step 5(a) is the
sole complete merge-policy decision; step 5(d) only maps the recorded `MODE` to the
correct command, using the gated `localSha`. BUG-D1 framing and all doctrine files
remain consistent.

**Findings:** none — empty findings array.
