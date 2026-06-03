---
name: close
description: Step 3 of the lightweight Claude↔Codex review loop. Apply only Thomas-approved fixes, re-run the gate, then on his explicit current-session approval merge the feature branch and clean up. Use after Thomas has decided on Codex's findings.
---

# /close — apply approved fixes → merge

Step 3 of the loop. Doctrine: `~/.claude/workflow-protocol.md`.

## Hard constraints
- Implement ONLY the findings Thomas approved. Deferred/rejected findings are untouchable without new explicit approval.
- Re-review is Thomas's call, not automatic. After fixes, ask "re-review or merge?".
- Never merge without Thomas's explicit approval **in the current session**. A prior general "yes" does not count.
- Never commit/push to the base branch directly (the guard hook enforces this; the merge is the only write to base).

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native close skill (e.g. `/close-story`) instead of this one, and do nothing else.
1. **Load** config + the latest `## Decisions` from `reviews/<slug>.md`.
2. **Apply approved fixes**, finding by finding. Append a `## Fixes (<date>)` note: what changed, per approved finding. (If this is the round that will merge, also set the story-file header to `Status: merged` now, so the trail lands on the feature branch before the merge — never via a separate base-branch commit.)
3. **Gate.** Re-run `testCommand`; must be green. Commit on the feature branch.
4. **Re-review fork.** Ask Thomas: **re-review** (→ `/review`, base = last-reviewed SHA, diff-only) or **merge**?
   - If any approved fix touched money / security / auth / business logic / data-loss, recommend a re-review before merge.
5. **Merge gate.** ONLY on Thomas's explicit approval this session:
   - With remote + `gh`: `gh pr merge --merge --delete-branch`.
   - Local-only: `git checkout <baseBranch> && git merge --no-ff <branch> -m "merge: <slug>" && git branch -d <branch>`.
6. **Sync + cleanup.** If a remote exists: `git fetch --prune && git checkout <baseBranch> && git merge --ff-only`. The `Status: merged` line was already committed on the feature branch in step 2, so it arrives with the merge — no separate base-branch commit.
7. Report done. Beyond the merge itself, write nothing to the base branch.
