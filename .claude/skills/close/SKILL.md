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
- **The story header records only declared state (`proposed` → `approved`) — never observed state.** `approved` is terminal. Whether the branch shipped is *observed* state owned by git (the merge commit + the `shipped/<slug>` tag); it is read back from them, never hand-written into the header. The header cannot drift from reality because it never stores the merge fact (single source of truth). The header must never say `merged`.
- Never commit/push to the base branch directly (the guard hook enforces this). The only writes to base are the merge commit itself and the `shipped/<slug>` tag created with it (a ref, not a tree commit).

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native close skill (e.g. `/close-story`) instead of this one, and do nothing else.
1. **Load** config + the latest `## Decisions` from `reviews/<slug>.md`.
2. **Apply approved fixes**, finding by finding. Append a `## Fixes (<date>)` note: what changed, per approved finding. Leave the header at `Status: approved` — do NOT set `merged` here; whether this round merges is unknown until step 4. If there were zero approved fixes (clean review), skip the edits but still continue — a clean review does not fast-path to merge.
3. **Gate.** Re-run `testCommand`; must be green. Commit on the feature branch.
4. **Re-review fork (mandatory — never skip).** Present exactly this choice and **STOP** for Thomas's answer: **re-review** (→ `/review`, base = last-reviewed SHA, diff-only) or **merge**? Ask this **every** time, including on a clean review with zero fixes — the human still chooses. Do not proceed to step 5 until Thomas gives a distinct merge instruction this session (see hard constraints).
   - If any approved fix touched money / security / auth / business logic / data-loss, recommend a re-review before merge.
5. **Merge.** ONLY after Thomas's distinct "merge" instruction this session. **Do NOT touch the header** — it stays `approved`. Record the merge in git, not in the file. The annotated `shipped/<slug>` tag is the honest, self-contained "this shipped" marker: it is created by the merge, so its mere existence means the merge happened (no tag ⇒ not shipped), and it is a ref (not a base-tree commit), so it respects "no writes to base beyond the merge."
   - **Remote + `gh`:**
     ```bash
     gh pr merge --merge --delete-branch -t "merge: <slug>" -b "Story: reviews/<slug>.md"
     sha=$(gh pr view <PR#> --json mergeCommit -q .mergeCommit.oid)
     git fetch origin                  # ensure the merge commit is in the local object store
     git tag -a "shipped/<slug>" "$sha" -m "Shipped <slug> (PR #<PR#>)"
     git push origin "shipped/<slug>"
     ```
   - **Local-only:**
     ```bash
     git checkout <baseBranch>
     git merge --no-ff <branch> -m "merge: <slug>" -m "Story: reviews/<slug>.md"
     git tag -a "shipped/<slug>" -m "Shipped <slug>"
     git branch -d <branch>
     ```
6. **Sync + cleanup.** If a remote exists: `git fetch --prune && git checkout <baseBranch> && git merge --ff-only`. Nothing else is written — the merge commit and the `shipped/<slug>` tag are the whole record.
7. **Report.** State that it shipped and cite the marker. "Did it ship?" is always *derived* from git, never read from the header: `git tag -l "shipped/<slug>"` (local) or `git ls-remote --tags origin "shipped/<slug>"` (remote) — non-empty ⇒ shipped. Beyond the merge commit and that tag, write nothing to the base branch.
