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
- **The story header records only declared state (`proposed` → `approved`) — never observed state.** `approved` is terminal. Whether the branch shipped is *observed* state owned by git; it is read back, never hand-written into the header. The **authoritative** shipped signal is the merge commit (`merge: <slug>`) / the PR's `MERGED` state — atomic, it either exists or it doesn't. The `shipped/<slug>` tag is a **best-effort convenience label** on top of that, not the authority. The header must never say `merged`.
- Never commit/push to the base branch directly (the guard hook enforces this). The only writes to base are the merge commit itself and the `shipped/<slug>` tag (a ref, not a tree commit).

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native close skill (e.g. `/close-story`) instead of this one, and do nothing else.
1. **Load** config + the latest `## Decisions` from `reviews/<slug>.md`.
2. **Apply approved fixes**, finding by finding. Append a `## Fixes (<date>)` note: what changed, per approved finding. Leave the header at `Status: approved` — do NOT set `merged` here; whether this round merges is unknown until step 4. If there were zero approved fixes (clean review), skip the edits but still continue — a clean review does not fast-path to merge.
3. **Gate.** Re-run `testCommand`; must be green. Commit on the feature branch.
4. **Re-review fork (mandatory — never skip).** Present exactly this choice and **STOP** for Thomas's answer: **re-review** (→ `/review`, base = last-reviewed SHA, diff-only) or **merge**? Ask this **every** time, including on a clean review with zero fixes — the human still chooses. Do not proceed to step 5 until Thomas gives a distinct merge instruction this session (see hard constraints).
   - If any approved fix touched money / security / auth / business logic / data-loss, recommend a re-review before merge.
5. **Merge.** ONLY after Thomas's distinct "merge" instruction this session. **Do NOT touch the header** — it stays `approved`. The **merge commit** (`merge: <slug>`, with a `Story:` trailer) / the PR's `MERGED` state is the authoritative, atomic shipped fact — that is what makes it shipped, not the tag. Then add `shipped/<slug>` as a **best-effort convenience label** and verify the push; a merged PR with a missing tag is still shipped — re-run the tag step to repair, never read its absence as "not shipped."
   - **Remote + `gh`:** the merge must ship *exactly* the reviewed/fixed HEAD — never whatever stale commit the remote PR happens to point at. So: push the local HEAD, prove the PR points at it, wait for mergeability to settle, then merge that exact SHA.
     ```bash
     localSha=$(git rev-parse HEAD)                            # the reviewed/fixed commit
     git push origin HEAD                                      # the PR head must contain the approved fixes
     # Let GitHub settle mergeability/checks (it computes them async); stop unless actually mergeable.
     for i in 1 2 3 4 5; do
       state=$(gh pr view <PR#> --json mergeStateStatus -q .mergeStateStatus)
       [ "$state" = "UNKNOWN" ] || break
       sleep 5
     done
     case "$state" in CLEAN|UNSTABLE|HAS_HOOKS) : ;; *) echo "ABORT: PR not mergeable (mergeStateStatus=$state)"; exit 1 ;; esac
     # Prove the PR head equals the reviewed SHA before merging (loud abort on drift).
     prHead=$(gh pr view <PR#> --json headRefOid -q .headRefOid)
     [ "$prHead" = "$localSha" ] || { echo "ABORT: PR head $prHead != reviewed $localSha — push/refresh, do not merge"; exit 1; }
     gh pr merge <PR#> --merge --delete-branch --match-head-commit "$localSha" \
       -t "merge: <slug>" -b "Story: reviews/<slug>.md"       # authoritative ship; --match-head-commit refuses on head drift
     sha=$(gh pr view <PR#> --json mergeCommit -q .mergeCommit.oid)
     git fetch origin                                          # ensure the merge commit is local
     git tag -a "shipped/<slug>" "$sha" -m "Shipped <slug> (PR #<PR#>)" && git push origin "shipped/<slug>"
     git ls-remote --tags origin "shipped/<slug>" | grep -q . || echo "WARN: tag push failed — repair by re-running the tag+push (the PR is already merged)"
     ```
   - **Local-only:**
     ```bash
     git checkout <baseBranch>
     git merge --no-ff <branch> -m "merge: <slug>" -m "Story: reviews/<slug>.md"   # authoritative ship
     git tag -a "shipped/<slug>" -m "Shipped <slug>"          # convenience label; repair by re-tagging if it fails
     git branch -d <branch>
     ```
6. **Sync + cleanup.** If a remote exists: `git fetch --prune && git checkout <baseBranch> && git merge --ff-only`. Nothing else is written — the merge commit (authoritative) and the `shipped/<slug>` tag (convenience) are the whole record.
7. **Report.** State that it shipped and cite the merge commit / PR. "Did it ship?" is *derived* from git, never read from the header — prefer the **authoritative** signal, fall back to the convenience tag:
   - Remote: `gh pr view <PR#> --json state -q .state` → `MERGED`.
   - Local: the merge commit is in base history — `git log <baseBranch> --oneline --grep "^merge: <slug>"`.
   - Fast secondary lookup only: `git tag -l "shipped/<slug>"` / `git ls-remote --tags origin "shipped/<slug>"` — non-empty ⇒ shipped, but its *absence* is not authoritative (could be an un-repaired tag). Beyond the merge commit and that tag, write nothing to the base branch.
