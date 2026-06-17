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

This story does **not** reopen that, by three guards:
- The new record-keeping lives **inside step 5**, which runs **only after Thomas's
  distinct merge instruction** at the step-4 fork. Choosing re-review never
  reaches it, so no records are ever written to an unmerged-and-staying-unmerged
  branch.
- The **story header is still untouched** — it stays `proposed → approved`, never
  `merged`. Whether it shipped remains *derived* from git (the SSOT discipline is
  intact).
- The records written are **declarative** ("this is what this branch delivers"),
  committed in the same atomic action that then issues the merge — exactly
  resolution **(c)** the BUG-D1 story pre-authorized (*"`merged` is set in the
  same step that issues the merge and is true within the same atomic action"*).

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
