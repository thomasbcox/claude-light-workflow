Date: 2026-06-07 · Branch: claude/bookkeeping-pr8-pr9 · Status: approved
Approved: Thomas approved scope as written, 2026-06-07 ("approved").

## Problem

Two ship cycles landed without their records being updated, the same drift the
`backlog-bookkeeping` (PR #4) and `backlog-ops5-ops6-bookkeeping` stories existed to fix:

- `BACKLOG.md` still lists **OPS-5** (auto-merge pre-flight too strict) and **OPS-7** (frame
  spec template counts files in test notes) in the open table, though both shipped via
  PR #8 / merge `0406185`.
- A same-session follow-up — the `reqChecks` 403-degradation bug, discovered by dogfooding
  the PR #8 merge — shipped via PR #9 / merge `1278814` but is recorded nowhere in `BACKLOG.md`.
- `CHANGELOG.md` `[Unreleased]` is empty; neither PR #8 nor PR #9 has a dated entry.

## In scope

1. `BACKLOG.md` — move OPS-5 and OPS-7 from the open table to Done, each citing its shipped
   PR/commit; record the `reqChecks`-fallback follow-up (PR #9 / `1278814`) so the audit
   trail is complete.
2. `CHANGELOG.md` — add dated entries for PR #8 (`ops5-ops7-ergonomics`, covering OPS-5 +
   OPS-7) and PR #9 (`ops5-reqchecks-fallback`), in the existing Keep-a-Changelog format.

## Non-goals

- No changes to the remaining open items OPS-1, OPS-2, OPS-3, OPS-6 (they stay in the open
  table, untouched). OPS-4 is already in Done — leave it.
- Do **not** add OPS-8 (optional CI) — it is a separately-flagged chip the user will spin off
  on its own.
- No changes to any skill, hook, config, test, or doc file — this story only updates records.
- Not re-describing or re-litigating what shipped; just record it accurately.

## Acceptance criteria

1. `BACKLOG.md`: OPS-5 no longer appears in the open table and has a Done row citing
   PR #8 / `0406185`.
2. `BACKLOG.md`: OPS-7 no longer appears in the open table and has a Done row citing
   PR #8 / `0406185`.
3. `BACKLOG.md`: the `reqChecks`-fallback follow-up is recorded as shipped via PR #9 /
   `1278814`, noted as a same-session bugfix discovered dogfooding PR #8.
4. `BACKLOG.md`: the open table still contains OPS-1, OPS-2, OPS-3, and OPS-6, unchanged.
5. `CHANGELOG.md`: a dated entry for PR #8 (`ops5-ops7-ergonomics`) records the OPS-5
   pre-flight loosening and the OPS-7 frame test-notes guidance.
6. `CHANGELOG.md`: a dated entry for PR #9 (`ops5-reqchecks-fallback`) records the `reqChecks`
   403-degradation fix.

## Test notes

- AC1–4: read `BACKLOG.md`; confirm the OPS-5/OPS-7 rows are in Done with the cited
  PRs/commits, the reqChecks follow-up is recorded, and OPS-1/2/3/6 remain in the open table.
- AC5–6: read `CHANGELOG.md`; confirm both dated entries exist with the correct PR numbers,
  slugs, and a faithful one-line description of each change.
- Gate: `bash tests/guard_test.sh` must still pass (records-only change; expected unaffected).
- Scope containment: run `git diff --name-only main...HEAD`; verify no files appear beyond
  those enumerated in the In-scope section (`BACKLOG.md`, `CHANGELOG.md`) plus this story file.

## Open questions

None.

## Build note (2026-06-07)

AC→file map:
- AC1–4 (OPS-5 + OPS-7 moved to Done with PR #8 / `0406185`; OPS-5-fix reqChecks-fallback
  recorded with PR #9 / `1278814`; OPS-1/2/3/6 untouched in the open table): `BACKLOG.md`
- AC5–6 (dated entries for PR #8 `ops5-ops7-ergonomics` and PR #9 `ops5-reqchecks-fallback`):
  `CHANGELOG.md`

## Codex review (2026-06-07, base main, HEAD bb16644)

**Summary:** Reviewed `git diff main...HEAD`, `git log --oneline main..HEAD`, and the spec.
The branch is scoped to `BACKLOG.md`, `CHANGELOG.md`, and the story file; OPS-5/OPS-7 moved
out of Open into Done with the required PR/commit citations, the PR #9 reqChecks follow-up is
recorded, and the changelog has dated PR #8 and PR #9 entries matching the spec. (Codex noted
it could not run `guard_test.sh` in its read-only sandbox — `mktemp` failed with
`Operation not permitted` — and did not treat that environmental failure as a finding. The
gate was run green outside the sandbox: 19/19.)

**Findings:** none — empty findings array.
