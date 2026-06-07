Date: 2026-06-07 · Branch: claude/ops5-reqchecks-fallback · Status: approved
Approved: Thomas approved scope as written, 2026-06-07 ("approve and implement").

## Problem

The OPS-5 merge pre-flight shipped in PR #8 (merge commit `0406185`) does not actually
degrade required-check detection to zero on a `403`/`404`, contrary to its AC2 and its own
code comment. In [.claude/skills/close/SKILL.md:39-40](../.claude/skills/close/SKILL.md):

```
reqChecks=$(gh api "repos/{owner}/{repo}/branches/<baseBranch>/protection/required_status_checks" \
              --jq '(.checks // []) | length' 2>/dev/null || echo 0)
```

On a `403` (e.g. "Upgrade to GitHub Pro" on a free-account private repo), `gh api` writes the
raw error JSON to **stdout** *and* exits non-zero. The inline `|| echo 0` therefore appends
`0` to the captured JSON body rather than replacing it, so `reqChecks` becomes a non-integer
like `{"message":...}0`. The downstream `[ "${reqChecks:-0}" -gt 0 ]` test then throws
`integer expression expected`. In PR #8's own merge this happened to fall through to the
correct direct-merge (`else`) branch only because the failed test evaluates false — the
outcome was right by luck, not by logic. Discovered by dogfooding the PR #8 merge.

## In scope

- `.claude/skills/close/SKILL.md` — make required-check detection robust:
  1. Capture the jq length **only on `gh` success**; on any `gh` failure set `reqChecks=0`
     via a separate statement (`... ) || reqChecks=0`), not an inline `|| echo 0` inside the
     command substitution.
  2. Sanitise `reqChecks` to a non-negative integer (empty or non-numeric → `0`) before the
     numeric comparison.

## Non-goals

- No change to the three-way merge strategy itself (auto-merge / direct-merge / abort), only
  to how `reqChecks` is computed and guarded.
- Not hardening the `autoMerge` capture (the `repos/{owner}/{repo}` endpoint works on
  free-account private repos; out of scope here).
- No changes to the guard hook, `workflow.json`, tests, `/frame`, `/review`, README, or
  `workflow-protocol.md`.
- Not consulting GitHub *rulesets* for required checks (still a documented limitation, not
  this story's concern).

## Acceptance criteria

1. The `reqChecks` assignment no longer uses an inline `|| echo 0` inside the command
   substitution; the fallback to `0` is a separate statement that runs only when `gh` fails.
2. A sanitising step coerces an empty or non-numeric `reqChecks` to `0` before the numeric
   comparison, so the `-gt` test always receives a clean integer.
3. Against this repo's live `403` response, the fixed snippet yields `reqChecks=0` (no
   non-integer string, no `integer expression expected` error).
4. The auto-merge-enabled branch and the abort branch (`reqChecks > 0`) retain their existing
   behavior — the fix changes only the *value* of `reqChecks`, not the branch logic.

## Test notes

- AC1, AC2: verified by reading `.claude/skills/close/SKILL.md` — confirm the separate-statement
  fallback and the integer-sanitising line are present, and the inline `|| echo 0` is gone.
- AC3: extract the fixed two/three-line snippet and run it against the live endpoint on this
  repo; assert it prints `0`. (Demonstrated pre-fix: the broken form prints `{"message":...}0`;
  the fixed form prints `0`.)
- AC4: trace by inspection — the `if`/`elif`/`else` structure and the two `gh pr merge`
  invocations are unchanged; only the `reqChecks` computation above them changes.
- Gate: `bash tests/guard_test.sh` must still pass (no hook/test changes).
- Scope containment: run `git diff --name-only main...HEAD`; verify no files appear beyond
  those enumerated in the In-scope section (`.claude/skills/close/SKILL.md`) plus this story
  file.

## Open questions

None.
