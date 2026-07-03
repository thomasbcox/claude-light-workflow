# markdown-row

Date: 2026-07-02 · Branch: claude/markdown-row · Status: approved

## Problem
`/dev-audit`'s Table A (ecosystem → toolset) has no **Markdown/docs** row — the optional secondary
row noted when the Shell row landed (OPS-10). Doc-heavy repos (this one included) therefore get no
first-class tool selection for their `*.md`, so a markdown linter / link checker isn't auto-suggested.
Small completeness addition to the declarative table.

## In scope
- Add one **Markdown / docs** row to Table A in `.claude/skills/dev-audit/SKILL.md`, matching the
  existing 6-column shape and the F1 read-only-column convention:
  - marker: `*.md`
  - linter/format: `markdownlint`; link check: `lychee`
  - read-only / check mode: `markdownlint` (no `--fix`), `lychee` (read-only) — with the honest
    caveat that **link-checking is network-dependent → advisory, prefer scheduled over a blocking
    gate** (the reasoning we used deferring link-check from CI).
  - dependency scan / SAST / test runner: `—` (n/a for docs).
- Anchor the new row in the drift linter `tests/dev_audit_test.sh`, same pattern as the Shell-row
  anchor.

## Non-goals
- **Not** wiring markdownlint / link-check into this repo's CI or gate — `/dev-audit` *recommends*
  tools; it does not gate on them, and link-check is deliberately advisory.
- No change to any other Table A row, to the classification matrix, or to any behavior beyond the
  one new row + its linter anchor. No new dependency (markdownlint/lychee are recommendations,
  `command -v`-gated like the rest).

## Acceptance criteria
1. **Markdown row present.** Table A has a `Markdown / docs — *.md` row listing `markdownlint`
   (+ `lychee` for links) with read-only invocations in the read-only column, including the
   link-check-is-advisory/network caveat. Columns align with the existing rows (dep-scan / SAST /
   test-runner are `—`).
2. **Linter anchors it.** `tests/dev_audit_test.sh` asserts the Markdown row exists (same `has …`
   pattern as the Shell-row anchor); the full gate is green.

## Test notes
- **AC1:** read Table A — the Markdown row matches the column shape; `grep` confirms the marker +
  `markdownlint` + the advisory caveat are present.
- **AC2:** `bash tests/dev_audit_test.sh` green with the new anchor.
- **Scope containment:** `git diff --name-only main...HEAD` shows only
  `.claude/skills/dev-audit/SKILL.md`, `tests/dev_audit_test.sh`, and this story file.

## Open questions
1. **Link-checker choice** — `lychee` (fast, Rust, actively maintained) vs `markdown-link-check`.
   **Recommend `lychee`.** Either way it's a *recommendation*, not a hard dependency.
2. **Caveat placement** — inline in the read-only cell (recommended, keeps it in the table) vs a
   note under the table (like the architecture-review note). **Recommend inline.**

## Decisions (2026-07-02, base main, HEAD b034ba5)
**Both passes clean — nothing to decide.** Approach: 0 findings; correctness: 0 findings (row columns,
marker, tools, advisory caveat, and linter anchors all verified). → `/close` re-review-or-merge fork.

## Codex review (2026-07-02, base main, HEAD b034ba5) — correctness pass — CLEAN
Summary: **clean.** The Markdown/docs row has the expected 6 columns, `*.md` marker,
`markdownlint` + `lychee`, inline advisory/network caveat in the read-only cell, and `—` for
dep-scan / SAST / test-runner; the drift linter anchors the row + caveat with the Shell-row `has`
pattern. **Zero findings.**

## Codex approach review (2026-07-02, base main, HEAD b034ba5) — CLEAN
Verdict: **sound.** Minimal declarative shape — one Markdown/docs row + drift-linter anchors matching
the Shell-row convention; the lychee caveat stays inline where the read-only invocation lives; no
dependency, CI gate, behavioral branch, or docs-specific mechanism introduced. **Zero findings** —
correctness proceeds. *(Live: PR #28 `gate` passed in 9s.)*

## Build note (2026-07-02)
AC → file map:
- AC1 (Markdown/docs Table A row) → `.claude/skills/dev-audit/SKILL.md`
- AC2 (drift-linter anchor for the row + advisory caveat) → `tests/dev_audit_test.sh`

## Scope decision (2026-07-02)
Thomas: **approve with recommended defaults** — scope as written; link checker = `lychee`; caveat
inline in the read-only cell. Clean design pass (no findings, no one-way doors) — scope nod only.

## Codex design review (2026-07-02)
Verdict: **sound — no findings.** Adding Markdown/docs as one more Table A row + a drift-linter anchor
is the minimal shape and matches the ratified Shell-row convention. `markdownlint` + `lychee` are
appropriate recommendations (no new dependency — `command -v`-gated). Marking link-checking advisory/
network-dependent and keeping it out of the local gate is consistent with the Shell decision and avoids
flaky enforcement. **Empty findings.**

## Design sketch — HOW
- One new row inserted in Table A after the `Shell` row (grouping the non-application ecosystems),
  following the exact 6-column format and the read-only-invocation convention. The network/advisory
  caveat for link-check goes **inline** in the read-only cell so the constraint travels with the
  tool. No new structure — it's the declarative table doing what it's designed for (a new ecosystem
  = a new row).
- One `has "…" "$SKILL" "<Markdown-row anchor>"` line in `tests/dev_audit_test.sh`, mirroring the
  Shell-row anchor.
- Purely a table-row + linter-anchor addition — no new dependency, no behavior change, consistent
  with OPS-10's Shell row.
