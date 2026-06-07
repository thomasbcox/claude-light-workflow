Date: 2026-06-06 · Branch: claude/auto-merge-close · Status: approved
Approved: Thomas approved scope as written, 2026-06-06.

## Problem

`/close`'s remote merge step (step 5) hand-rolls what GitHub provides natively as auto-merge. It pushes, polls `mergeStateStatus` in a 5×5s loop waiting for `UNKNOWN` to clear, proves `headRefOid == localSha`, then calls `gh pr merge --merge --match-head-commit`. This fails intermittently (OPS-4) because GitHub computes mergeability asynchronously and the poll loop can exhaust its retries before the computation settles.

The root cause is misplaced responsibility: the client is doing merge-timing orchestration that GitHub owns. `gh pr merge --auto` exists precisely for this — it delegates merge timing to GitHub, which performs the merge once all requirements pass, eliminating the client-side race entirely. The `mergeStateStatus` poll loop is the anti-pattern; auto-merge is the correct abstraction.

This needs to work across any repo, including repos with existing branch protection and required CI checks.

## In scope

- Replace the `mergeStateStatus` 5×5s poll loop with `gh pr merge --auto`.
- After enabling auto-merge, poll `gh pr view --json state` until the PR reaches `MERGED` (or timeout/abort on failure), so `/close` gives synchronous confirmation of ship.
- Add a pre-flight check: if "Allow auto-merge" is not enabled in the repo settings, abort early with a clear message telling the user to enable it, rather than silently misbehaving (closing the cli/cli#8792 footgun).
- Update the instructional prose and bash block in `/close` step 5 (remote path) to reflect the new pattern.
- Keep `--match-head-commit "$localSha"` — it remains the correct drift-safety guard.
- Keep the local-only path (step 5, local) unchanged — auto-merge is a GitHub concept and doesn't apply there.

## Non-goals

- Adding or requiring a GitHub Actions workflow file in this repo or any target repo. The `/close` skill assumes CI is already configured wherever branch protection is used; it does not provision it.
- Changing the local-only merge path.
- Changing the `mergeStateStatus` values used in the Codex review schema or any other part of the workflow.
- Adding auto-retry or fallback logic — if auto-merge fails, the correct response is a loud abort, not a retry loop.

## Acceptance criteria

1. **Poll loop removed.** The `mergeStateStatus` 5×5s retry loop no longer appears in the `/close` step 5 remote bash block.
2. **Auto-merge invoked.** The merge command in step 5 (remote) is `gh pr merge <PR#> --auto --merge --delete-branch --match-head-commit "$localSha" -t "merge: <slug>" -b "Story: reviews/<slug>.md"`.
3. **MERGED poll present.** After calling `--auto`, `/close` polls `gh pr view <PR#> --json state -q .state` until the value is `MERGED`, with a finite timeout (suggested: up to 30 polls at 10s intervals = 5 minutes) and a clear abort message on timeout.
4. **Pre-flight check present.** Before the push, `/close` checks whether auto-merge is available on the repo (`gh repo view --json autoMergeAllowed -q .autoMergeAllowed`). If `false`, it aborts with: `ABORT: auto-merge is not enabled for this repo — enable it under Settings → General → Pull Requests → Allow auto-merge, then re-run /close`.
5. **`--match-head-commit` retained.** The flag and its `$localSha` argument remain in the merge command.
6. **Headless/unattended safe.** The new flow does not depend on the client being present during CI execution — `/close` exits cleanly (or aborts cleanly) without requiring the user to interact mid-wait.
7. **Test gate passes.** `bash tests/guard_test.sh` is green after the change.

## Test notes

- AC1–5: verified by reading the updated SKILL.md bash block directly.
- AC6: verified by inspecting the poll loop — it must have a hard timeout and not require stdin or interactive input.
- AC7: run `bash tests/guard_test.sh`; must exit 0.

## Open questions

None — scope is settled by the research findings and Thomas's decision to use Option A.

## Build note (2026-06-06)

AC→file map:
- AC1–6 (poll loop removal, --auto, MERGED poll, pre-flight, --match-head-commit, headless-safe): `.claude/skills/close/SKILL.md`
- AC7 (test gate): `tests/guard_test.sh` (unchanged — existing tests cover guard hook, not skill prose)

```
 .claude/skills/close/SKILL.md | 25 ++++++++++++-----------
 reviews/auto-merge-close.md   | 46 +++++++++++++++++++++++++++++++++++++++++++
 2 files changed, 59 insertions(+), 12 deletions(-)
```

Gate: `bash tests/guard_test.sh` → 19/19 passed.

## Codex review (2026-06-06, base main, HEAD 1a222cc)

**Summary:** The branch makes the requested prose/bash-block changes, but the new pre-flight command uses a JSON field that the local `gh repo view` command does not support, so the remote `/close` path would abort even on correctly configured repositories.

### BLOCKER

**B1 — Auto-merge preflight uses unsupported gh field**
- File: `.claude/skills/close/SKILL.md` line 29
- Claim: `gh repo view --json autoMergeAllowed` rejects `autoMergeAllowed` as an unknown JSON field. The remote merge path can fail before push/merge regardless of the repository's actual auto-merge setting — AC4 is not reliably implemented.
- Suggestion: Replace with a supported API query — e.g. `gh api repos/{owner}/{repo} --jq .allow_auto_merge` (REST, confirmed working) — then abort only when the returned value is actually `false`.
