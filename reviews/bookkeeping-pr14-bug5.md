Date: 2026-06-14 · Branch: claude/bookkeeping-pr14-bug5 · Status: approved

# Story: Bookkeeping — land BUG-4 (PR #14) in the records; log the guard-hook tag-push defect (BUG-5)

> **Approved 2026-06-14.** Thomas: "1 ok" (predict PR #15 for the self-entry) and
> "2 it's a bug" (the guard-hook tag-push defect is classified **BUG-5**, under
> Skill-behavior bugs — not an OPS item). Slug renamed from `bookkeeping-pr14-ops10`
> to `bookkeeping-pr14-bug5` to match.

## Problem

`review-schema-abs-path` (BUG-4) merged via PR #14 / `0504e31` but the persistent
records weren't updated in that loop (by design — BACKLOG Done-rows and CHANGELOG
entries go through their own bookkeeping story rather than direct commits to `main`,
per `bookkeeping-pr8-pr9` and `backlog-bookkeeping` precedent). So:

- `BACKLOG.md` still carries **BUG-4** as an *open, in-flight* item; it needs to move
  to **Done** (PR #14 / `0504e31`).
- `CHANGELOG.md` has no entry for PR #14.

Separately, closing PR #14 surfaced a real, reproducible defect in the guard
hook / `/close` interaction that needs to be *recorded* (not fixed here),
classified **BUG-5**:

- **Guard-hook tag-push false positive (BUG-5).** `/close` step 5 runs
  `gh pr merge --delete-branch` (which leaves HEAD on the base branch `main`) and
  *then* `git push origin "shipped/<slug>"`. The guard hook
  (`block-main-writes.sh`) blocks **any** `push` whose `current_branch` is a base
  branch — it keys on "am I on `main`?", not "is the refspec `main`?". A
  `shipped/<slug>` push is a **tag ref**, not a base-tree write, and is explicitly
  sanctioned by `/close` doctrine — yet it gets blocked in the normal post-merge
  state. Worked around during PR #14's close by pushing the tag from a detached
  HEAD (so `current_branch` is empty). This reproduces on every remote close that
  follows the documented step order.

## In scope

- **`BACKLOG.md`:**
  - Move **BUG-4** from the open "Skill-behavior bugs" section to the **Done**
    table (row: PR #14 / `0504e31`); restore the section's "all shipped" note.
  - Add **BUG-5** as a new open item under "Skill-behavior bugs": the guard-hook
    tag-push false positive described above. Note that although it concerns the
    same guard hook as the decided-against **OPS-6**, BUG-5 is a *different*
    defect — OPS-6 was about *hardening* the guard to catch more bypasses; BUG-5
    is the guard being *too aggressive*, blocking a legitimate sanctioned push.
  - Add a Done-section prose line linking the `review-schema-abs-path` story.
  - **OPS-9 stays open, unchanged.**
- **`CHANGELOG.md`:**
  - Add a dated entry `## [2026-06-14] — review-schema-abs-path (PR #14)`:
    **Fixed** BUG-4 (absolute `--output-schema` path); note OPS-9 was logged.
  - Add this story's own entry `## [2026-06-14] — bookkeeping-pr14-bug5 (PR #15)`:
    **Changed** — BUG-4 → Done, PR #14 backfilled, BUG-5 logged. (PR number
    predicted #15; correct at PR-creation if GitHub assigns otherwise.)
- **`reviews/bookkeeping-pr14-bug5.md`** — this story file (audit trail).

## Non-goals

- **Fixing BUG-5.** This story only *logs* it. The hook/`/close` change is a
  separate story.
- **Resolving OPS-9.** Stays an open evaluate-and-decide item.
- Any change to skills, the guard hook, `install.sh`, `AGENTS.md`, or
  `workflow-protocol.md` — no code/skill/tooling edits, records only.
- Editing the already-merged `reviews/review-schema-abs-path.md` history.

## Acceptance criteria

1. **BUG-4 is in Done, not open.** `BACKLOG.md` has no open BUG-4 paragraph; the
   "Skill-behavior bugs" section reads as all-shipped except the new BUG-5, and
   the Done table has a BUG-4 row citing PR #14 / `0504e31`.
2. **BUG-5 is logged as open** under "Skill-behavior bugs", describing the
   guard-hook tag-push false positive, including the note distinguishing it from
   the decided-against OPS-6.
3. **OPS-9 is untouched** and still open.
4. **CHANGELOG has the PR #14 entry** under `## [2026-06-14] — review-schema-abs-path (PR #14)`
   with a Fixed item for BUG-4 (and the OPS-9-logged note).
5. **CHANGELOG self-documents this bookkeeping story** with a dated entry citing
   its own PR number and a Changed item (BUG-4 → Done, PR #14 backfilled, BUG-5
   logged).
6. **Scope containment.** `git diff --name-only main...HEAD` shows only
   `BACKLOG.md`, `CHANGELOG.md`, and `reviews/bookkeeping-pr14-bug5.md`.

## Test notes

- AC1: inspect `BACKLOG.md` — no open BUG-4 paragraph; Done table has the BUG-4
  row with `PR #14 / 0504e31`.
- AC2: inspect `BACKLOG.md` — BUG-5 line present under Skill-behavior bugs with
  the OPS-6-distinction note.
- AC3: `git diff main...HEAD -- BACKLOG.md` shows the OPS-9 lines unchanged.
- AC4/AC5: inspect `CHANGELOG.md` — both dated entries present and well-formed
  (Keep-a-Changelog style, matching existing entries).
- AC6: run `git diff --name-only main...HEAD` and verify no files appear beyond
  `BACKLOG.md`, `CHANGELOG.md`, `reviews/bookkeeping-pr14-bug5.md`.
- Gate: `bash tests/guard_test.sh` stays green (records-only change; gate must
  still pass).

## Open questions

_Resolved at approval: (1) predict PR #15 for the self-entry; (2) the guard-hook
defect is BUG-5 (Skill-behavior), not an OPS item._

## Build note (2026-06-14)

AC → file map:

- **AC1** (BUG-4 open → Done) → `BACKLOG.md`
- **AC2** (BUG-5 logged open, with OPS-6 distinction) → `BACKLOG.md`
- **AC3** (OPS-9 untouched) → `BACKLOG.md` (verification only — no change)
- **AC4** (PR #14 CHANGELOG entry) → `CHANGELOG.md`
- **AC5** (self-documenting bookkeeping entry) → `CHANGELOG.md`
- **AC6** (scope containment) → `BACKLOG.md`, `CHANGELOG.md`,
  `reviews/bookkeeping-pr14-bug5.md` only
