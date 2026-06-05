---
name: close
description: Step 3 of the lightweight Claude↔Codex review loop. Apply only Thomas-approved fixes, re-run the gate, then on his explicit current-session approval merge the feature branch and clean up. Use after Thomas has decided on Codex's findings.
---

# /close — apply approved fixes → merge

Step 3 of the loop. Doctrine: `~/.claude/workflow-protocol.md`.

## Hard constraints
- Implement ONLY the findings Thomas approved. Deferred/rejected findings are untouchable without new explicit approval.
- Re-review is Thomas's call, not automatic. After fixes, ask "re-review or merge?" — and STOP for his answer, even when there were zero fixes to apply (a clean review still stops here).
- **Invoking `/close` is NOT merge authorization.** A merge requires a distinct, affirmative human instruction — the word "merge" or equivalent — given **after** the step-4 fork is presented, **in the current session, every time**. The command invocation does not count; a prior or general "yes" does not count.
- **Never assert `Status: merged` before the merge has actually happened.** The story header stays `approved` through the rounds and flips to `merged` only in the same atomic step that issues the merge (step 5). Status and reality must agree at every point a reader could observe the branch.
- Never commit/push to the base branch directly (the guard hook enforces this; the merge is the only write to base).

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native close skill (e.g. `/close-story`) instead of this one, and do nothing else.
1. **Load** config + the latest `## Decisions` from `reviews/<slug>.md`.
2. **Apply approved fixes**, finding by finding. Append a `## Fixes (<date>)` note: what changed, per approved finding. Leave the header at `Status: approved` — do NOT set `merged` here; whether this round merges is unknown until step 4. If there were zero approved fixes (clean review), skip the edits but still continue — a clean review does not fast-path to merge.
3. **Gate.** Re-run `testCommand`; must be green. Commit on the feature branch.
4. **Re-review fork (mandatory — never skip).** Present exactly this choice and **STOP** for Thomas's answer: **re-review** (→ `/review`, base = last-reviewed SHA, diff-only) or **merge**? Ask this **every** time, including on a clean review with zero fixes — the human still chooses. Do not proceed to step 5 until Thomas gives a distinct merge instruction this session (see hard constraints).
   - If any approved fix touched money / security / auth / business logic / data-loss, recommend a re-review before merge.
5. **Merge gate + atomic status flip.** ONLY after Thomas's distinct "merge" instruction this session. In one unbroken sequence, on the feature branch:
   1. Set the header to `Status: merged` and commit it: `git commit -am "close: mark <slug> merged"`. This is the flip — it happens here, in the same step as the merge, so the header is true within this atomic action and the `merged` line lands on the feature branch (no separate base-branch commit).
   2. Immediately issue the merge:
      - With remote + `gh`: `gh pr merge --merge --delete-branch`.
      - Local-only: `git checkout <baseBranch> && git merge --no-ff <branch> -m "merge: <slug>" && git branch -d <branch>`.
   If the merge cannot complete, do not leave the branch asserting `merged` — revert the status commit before stopping.
6. **Sync + cleanup.** If a remote exists: `git fetch --prune && git checkout <baseBranch> && git merge --ff-only`. The `Status: merged` line was committed on the feature branch in step 5, so it arrives with the merge — no separate base-branch commit.
7. Report done. Beyond the merge itself, write nothing to the base branch.
