Date: 2026-06-08 · Branch: claude/review-codex-stdin · Status: approved
Approved: Thomas approved scope as written, 2026-06-08 ("yes").

## Problem

The `/review` skill's documented Codex command ([.claude/skills/review/SKILL.md:23-27](../.claude/skills/review/SKILL.md))
has no stdin redirect. When run, `codex exec` prints `Reading additional input from stdin...`
and **blocks waiting for stdin EOF that never arrives**, hanging the review indefinitely.
Observed firsthand during the `install-drift-check` story (PR #11): rounds 2–3 of the Codex
re-review hung for many minutes until killed. Appending `</dev/null` made the identical command
complete immediately (exit 0). The fix is to give `codex exec` an immediate stdin EOF in the
documented command so reviews can't stall.

## In scope

- `.claude/skills/review/SKILL.md` — append a `</dev/null` stdin redirect to the documented
  `codex exec` command (step 5), placed so it attaches to the `codex exec` invocation itself
  (before any pipe a runner may add), and add a short note explaining why.

## Non-goals

- No change to the prose mentions of `codex exec` in `workflow-protocol.md`, `README.md`,
  `CHANGELOG.md`, or `ai-dev-workflow-architecture.md` — those are descriptive, not runnable
  command blocks, and don't show the full invocation.
- No change to the codex flags, schema, prompt text, or any other review step.
- No new codex run wired into the gate; the redirect is proven by the existing session evidence
  plus a minimal local smoke check (see Test notes).

## Acceptance criteria

1. The `codex exec` command block in `.claude/skills/review/SKILL.md` step 5 includes a
   `</dev/null` stdin redirect on the `codex exec` invocation, so codex receives an immediate
   EOF and cannot block reading stdin.
2. The redirect is positioned so it remains correct when the runner appends `2>&1 | tail …`
   (i.e. it binds to the `codex exec` simple-command, before any pipe — there is no pipe inside
   the documented block).
3. A brief inline note records *why* the redirect is there (codex exec otherwise blocks on
   stdin), so the rationale isn't lost to a future edit.
4. No other skill file contains a runnable `codex exec` invocation needing the same fix —
   confirmed, scope stays limited to `review/SKILL.md`.

## Test notes

- AC1, AC3: read `review/SKILL.md`; confirm `</dev/null` is in the command block and the
  explanatory note is present.
- AC2: trace by inspection — the documented block contains no pipe, and `</dev/null` sits at the
  end of the `codex exec` invocation, so a runner appending `2>&1 | tail` yields
  `codex exec … </dev/null 2>&1 | tail` (redirect binds to codex, not the pipe).
- AC4: `grep -rn "codex exec" .claude/skills` shows only `review/SKILL.md` has a runnable block
  (others are prose).
- Functional proof: the live session already demonstrated it — the round-2 re-review hung
  without the redirect and completed exit 0 with `</dev/null` appended (`reviews/install-drift-check.md`
  process note). Optionally re-confirm with a minimal `printf '' | codex … </dev/null` style
  smoke check that the command returns rather than blocking.
- Gate: `bash tests/guard_test.sh` must still pass (no hook/test changes).
- Scope containment: run `git diff --name-only main...HEAD`; verify no files appear beyond
  `.claude/skills/review/SKILL.md` plus this story file.

## Open questions

None.

## Build note (2026-06-08)

AC→file map — single-file change:
- AC1–4 (`</dev/null` redirect appended to the `codex exec` block; rationale note; redirect
  binds to `codex exec` with no in-block pipe; scope limited to the one runnable invocation):
  `.claude/skills/review/SKILL.md`
