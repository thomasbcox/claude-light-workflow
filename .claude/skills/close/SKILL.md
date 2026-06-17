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
- **The story header records only declared state (`proposed` → `approved`) — never observed state.** `approved` is terminal. Whether the branch shipped is *observed* state owned by git; it is read back, never hand-written into the header. The shipped signal is the merge commit (`merge: <slug>`) / the PR's `MERGED` state — atomic, it either exists or it doesn't, and it is the **single** source of truth. The header must never say `merged`.
- Never commit/push to the base branch directly (the guard hook enforces this). The only write to base is the merge commit itself.

## Steps
0. **Defer to native workflow.** If `docs/ai-protocol.md` exists at the repo root (resolve via `git rev-parse --show-toplevel`), STOP immediately — this repo runs its own heavier workflow. Tell the user to use its native close skill (e.g. `/close-story`) instead of this one, and do nothing else.
1. **Load** config + the latest `## Decisions` from `reviews/<slug>.md`.
2. **Apply approved fixes**, finding by finding. Append a `## Fixes (<date>)` note: what changed, per approved finding. Leave the header at `Status: approved` — do NOT set `merged` here; whether this round merges is unknown until step 4. If there were zero approved fixes (clean review), skip the edits but still continue — a clean review does not fast-path to merge.
3. **Gate.** Re-run `testCommand`; must be green. Commit on the feature branch.
4. **Re-review fork (mandatory — never skip).** Present exactly this choice and **STOP** for Thomas's answer: **re-review** (→ `/review`, base = last-reviewed SHA, diff-only) or **merge**? Ask this **every** time, including on a clean review with zero fixes — the human still chooses. Do not proceed to step 5 until Thomas gives a distinct merge instruction this session (see hard constraints).
   - If any approved fix touched money / security / auth / business logic / data-loss, recommend a re-review before merge.
5. **Merge.** ONLY after Thomas's distinct "merge" instruction this session.
   - **First, record the release on the feature branch** so it rides in on the merge commit — no separate base-branch write, and not speculative: this runs only *after* the merge instruction, so choosing re-review at step 4 never reaches it and never leaves release records on an unmerged branch.
     - `CHANGELOG.md`: turn `[Unreleased]` into a dated `## [<date>] — <slug> (PR #N)` entry describing what shipped.
     - `BACKLOG.md`: **if** the story resolves a tracked `BUG-`/`OPS-` item, move that row to **Done**, referenced as `PR #N / merge: <slug>` — never a raw SHA (it's derivable: `git log <baseBranch> --oneline --grep "^merge: <slug>"`). A story with no tracked backlog item gets the CHANGELOG entry only.
     - Commit these on the feature branch. This record-keeping is **mechanical and rides post-review by design** — it does NOT need its own review round or a separate bookkeeping story (see doctrine: no bookkeeping-only stories).
     - **Do NOT touch the story header** — it stays `approved`. Declared state only; whether it shipped stays owned by git (the merge commit / PR-`MERGED`), never written into the header. The header is never set to `merged`.
   - Then **merge**. The **merge commit** (`merge: <slug>`, with a `Story:` trailer) / the PR's `MERGED` state is the atomic shipped fact and the only ship record — there is no separate tag to write or repair.
   - **Remote + `gh`:** the merge must ship *exactly* the reviewed/fixed HEAD. When auto-merge is enabled, merge timing is delegated to GitHub via `--auto` — GitHub performs the merge once all requirements pass, eliminating the client-side mergeability race. When auto-merge is disabled, a direct merge ships immediately *unless* the base branch has required status checks (then abort — there is something to wait for). Either way: push the local HEAD, run the appropriate `gh pr merge` (with `--match-head-commit` for drift safety), then poll for `MERGED`.
     ```bash
     localSha=$(git rev-parse HEAD)                            # reviewed/fixed HEAD + the step-5 release-record commit
     git push origin HEAD                                      # the PR head must contain the approved fixes
     # Pre-flight: pick a merge strategy.
     #   - Auto-merge ENABLED  → delegate merge timing to GitHub (waits for any required checks).
     #   - Auto-merge DISABLED + NO required checks → a direct merge succeeds immediately; do that.
     #   - Auto-merge DISABLED + ≥1 required check  → there is genuinely something to wait for;
     #     abort and let the human enable auto-merge or merge manually once checks pass.
     # Required-check detection uses CLASSIC branch protection only. Any failure — including the
     # 403 "Upgrade to GitHub Pro" returned for free-account private repos, or 404 when the branch
     # is unprotected — is treated as zero required checks. GitHub *rulesets* are NOT consulted; if
     # you enforce required checks via rulesets, enable auto-merge so GitHub gates the merge.
     autoMerge=$(gh api repos/{owner}/{repo} --jq .allow_auto_merge)
     # Capture the count only on success; on ANY gh failure (403/404/network) fall back to 0
     # via a SEPARATE statement — an inline `|| echo 0` would append 0 to the error body that
     # gh prints to stdout, yielding a non-integer. Then coerce empty/non-numeric to 0 so the
     # numeric test below always gets a clean integer.
     reqChecks=$(gh api "repos/{owner}/{repo}/branches/<baseBranch>/protection/required_status_checks" \
                   --jq '(.checks // []) | length' 2>/dev/null) || reqChecks=0
     case "$reqChecks" in (''|*[!0-9]*) reqChecks=0 ;; esac
     if [ "$autoMerge" = "true" ]; then
       # --match-head-commit refuses if head has drifted from the reviewed SHA.
       gh pr merge <PR#> --auto --merge --delete-branch --match-head-commit "$localSha" \
         -t "merge: <slug>" -b "Story: reviews/<slug>.md"
     elif [ "${reqChecks:-0}" -gt 0 ]; then
       echo "ABORT: auto-merge is disabled and '<baseBranch>' has required status checks — enable auto-merge (Settings → General → Pull Requests → Allow auto-merge) or merge manually once checks pass, then re-run /close"; exit 1
     else
       # Auto-merge off and no required checks: ship the reviewed HEAD immediately.
       gh pr merge <PR#> --merge --delete-branch --match-head-commit "$localSha" \
         -t "merge: <slug>" -b "Story: reviews/<slug>.md"
     fi
     # Wait for GitHub to perform the merge (auto-merge is async). Timeout after 5 minutes.
     for i in $(seq 1 30); do
       prState=$(gh pr view <PR#> --json state -q .state)
       [ "$prState" = "MERGED" ] && break
       [ "$i" = "30" ] && { echo "ABORT: timed out waiting for PR to merge (5 min) — check PR status on GitHub"; exit 1; }
       sleep 10
     done
     git fetch origin                                          # ensure the merge commit is local
     ```
   - **Local-only:**
     ```bash
     git checkout <baseBranch>
     git merge --no-ff <branch> -m "merge: <slug>" -m "Story: reviews/<slug>.md"   # authoritative ship
     git branch -d <branch>
     ```
6. **Sync + cleanup.** If a remote exists: `git fetch --prune && git checkout <baseBranch> && git merge --ff-only`. No *further* base-branch write — the release records (CHANGELOG / BACKLOG-Done) already rode in on the merge commit, which is the shipped fact.
7. **Report.** State that it shipped and cite the merge commit / PR. "Did it ship?" is *derived* from git, never read from the header:
   - Remote: `gh pr view <PR#> --json state -q .state` → `MERGED`.
   - Either: the merge commit is in base history — `git log <baseBranch> --oneline --grep "^merge: <slug>"` (non-empty ⇒ shipped). For a list of everything shipped, drop the `<slug>`: `git log <baseBranch> --oneline --grep "^merge: "`.
   - Beyond the merge commit, write nothing to the base branch.
