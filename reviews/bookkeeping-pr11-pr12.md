Date: 2026-06-08 · Branch: claude/bookkeeping-pr11-pr12 · Status: approved
Approved: Thomas approved scope as written, 2026-06-08 ("yes").

## Problem

Three ship cycles and one scope decision are unrecorded, the same drift earlier bookkeeping
stories existed to clear:

- `BACKLOG.md` still lists **OPS-1, OPS-2, OPS-3** in the open table, though all three shipped
  together as the `install-drift-check` story (PR #11 / merge `b18993e`).
- The `review-codex-stdin` fix (PR #12 / merge `706171d`) — a same-session fix to the `/review`
  skill's `codex exec` stdin hang, with no OPS number — is recorded nowhere.
- **OPS-6** (guard-hook hardening) was **deliberately decided against** (2026-06-08) but still
  sits in the open table with no record of the decision or its rationale.
- `CHANGELOG.md` has dated entries only through PR #9; PR #10 (`bookkeeping-pr8-pr9`),
  PR #11 (`install-drift-check`), and PR #12 (`review-codex-stdin`) are missing.

## In scope

1. `BACKLOG.md` — move OPS-1/2/3 from the open table to Done, citing PR #11 / `b18993e`; add a
   Done entry for the `review-codex-stdin` tooling fix (PR #12 / `706171d`).
2. `BACKLOG.md` — add a new **"Decided against"** section and move OPS-6 into it with a concise
   rationale (see AC4 for the required points).
3. `CHANGELOG.md` — add dated entries for PR #10, PR #11, and PR #12 in the existing
   Keep-a-Changelog format.

## Non-goals

- No change to OPS-8 (the separately-flagged CI chip) — it stays as-is.
- No change to any skill, hook, config, test, or other doc file — records only.
- Not re-opening or re-arguing OPS-6; this only *records* the decision already made.
- Not deleting OPS-6 — it moves to "Decided against" (the backlog's rule is to move, not delete).

## Acceptance criteria

1. `BACKLOG.md`: OPS-1, OPS-2, OPS-3 no longer appear in the open table and each has a Done row
   citing PR #11 / `b18993e` (the `install-drift-check` story).
2. `BACKLOG.md`: the Done table records the `review-codex-stdin` fix (PR #12 / `706171d`), noted
   as a same-session fix to the `/review` codex stdin hang.
3. `BACKLOG.md`: the open table no longer contains OPS-6 (it is the only remaining open OPS item
   before this change; afterward the open "Deployment & tooling" table is empty or removed).
4. `BACKLOG.md`: a new **"Decided against"** section contains OPS-6 with a rationale covering:
   (a) the guard hook is a *cooperative* client-side guardrail, not an adversarial sandbox, so
   chasing exotic bypasses (`env git` / `nice git` wrapper prefixes) is a category error — it's
   bypassable by editing `settings.json` regardless; (b) it does not duplicate GitHub branch
   protection (different layer; and unavailable on a free private repo anyway); (c) the one real
   sub-bug — base branch hardcoded to `main`/`master`, so a non-`main` base gets no protection
   despite `workflow.json` declaring `baseBranch` — is not load-bearing for this solo, `main`-based
   setup and is **deferred-until-needed** (revisit only if a non-`main` base is adopted). Dated
   2026-06-08.
5. `CHANGELOG.md`: dated entries exist for PR #10 (`bookkeeping-pr8-pr9`), PR #11
   (`install-drift-check`, OPS-1/2/3), and PR #12 (`review-codex-stdin`), each with a faithful
   one-line description.

## Test notes

- AC1–4: read `BACKLOG.md`; confirm OPS-1/2/3 are in Done with PR #11, the review-codex-stdin
  fix is recorded, OPS-6 is gone from the open table and present under "Decided against" with all
  three rationale points, dated 2026-06-08.
- AC5: read `CHANGELOG.md`; confirm the three dated entries exist with correct PR numbers, slugs,
  and faithful descriptions.
- Gate: `bash tests/guard_test.sh` must still pass (records-only change; expected unaffected).
- Scope containment: run `git diff --name-only main...HEAD`; verify no files appear beyond
  `BACKLOG.md`, `CHANGELOG.md`, plus this story file.

## Open questions

None.
