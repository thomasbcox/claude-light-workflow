Date: 2026-06-05 · Branch: claude/backlog-bookkeeping · Status: approved

# backlog-bookkeeping — record the shipped merge-gate fix in BACKLOG + CHANGELOG

## Problem

`close-gate-and-backlog` shipped (PR #2, merge `5225bdb`), fixing BUG-D1/D2/D3. The trail isn't yet reconciled: `BACKLOG.md` still lists those three as **Open**, and `CHANGELOG.md`'s `[Unreleased]` section is empty. This is pure bookkeeping so the backlog reflects reality.

## In scope

1. `BACKLOG.md` — move BUG-D1/D2/D3 from the open "Skill-behavior bugs" table to the **Done** section, each annotated as shipped via PR #2 / `5225bdb`. Resolve the trailing "Related acceptance criteria" note (it described the same now-shipped story).
2. `CHANGELOG.md` — add an `[Unreleased]` entry describing the `/close` merge-gate + status-lifecycle fix.

## Non-goals

- OPS-1/2/3 stay **Open** — untouched.
- No changes to any skill behavior: `.claude/skills/*`, hooks, `workflow.json`, `AGENTS.md`, `workflow-protocol.md` are not touched. Docs/trail only.
- Not deploying (`install.sh` already run for the shipped fix).

## Acceptance criteria

1. **BUG-D1/D2/D3 are in `BACKLOG.md`'s Done section**, each with a one-line shipped annotation citing PR #2 / `5225bdb`. They no longer appear in the open Skill-behavior-bugs table.
2. **The open Skill-behavior-bugs section reads cleanly** with its bugs gone — either emptied with a "(all shipped — see Done)" note or the rows removed — and the trailing "Related acceptance criteria" note is moved/folded into the Done entry or removed, not left dangling referencing open work.
3. **`CHANGELOG.md` `[Unreleased]` has a `### Fixed` entry** describing the fix: declared-vs-observed header (never `Status: merged`), merge commit / PR-MERGED as the authoritative shipped signal, best-effort `shipped/<slug>` tag, mandatory non-skippable merge fork, and "invoking `/close` is not merge authorization."
4. **OPS-1/2/3 remain Open** and unchanged.
5. **Diff is docs-only** — only `BACKLOG.md`, `CHANGELOG.md`, and `reviews/backlog-bookkeeping.*` change. No skill/hook/config files touched.

## Test notes

- AC1: grep `BACKLOG.md` Done section for `BUG-D1`/`D2`/`D3` + `#2`; confirm the open bugs table no longer lists them.
- AC2: read the Skill-behavior-bugs section — no dangling open-work references.
- AC3: confirm `[Unreleased]` is non-empty with the described `### Fixed` bullet(s).
- AC4: confirm OPS rows unchanged.
- AC5: `git diff --stat main...HEAD` shows only the two docs files + the story file.

## Decisions (2026-06-05)

Thomas, this session: **scope approved** — "implement and review". Open question 1 → default kept (Skill-behavior-bugs header retained with an "(all shipped — see Done)" note). Not merge authorization.
