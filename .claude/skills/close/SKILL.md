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
5. **Merge.** ONLY after Thomas's distinct "merge" instruction this session. The flow is **preflight → record → re-gate → merge**, in that order, so a known-preventable abort never leaves release records on the branch.

   **(a) Preflight — *early* fast-fail *before* writing any record.** This is an early abort so a known-preventable failure never leaves records on the branch; (d) re-checks authoritatively and is correct even if this step were skipped.
   - **Local-only:** none needed (a `git merge --no-ff` is immediate); go to (b).
   - **Remote + `gh`:** compute the merge strategy and, if there is genuinely something to wait for, **abort here — before any record commit**:
     ```bash
     autoMerge=$(gh api repos/{owner}/{repo} --jq .allow_auto_merge)
     # Capture the count only on success; on ANY gh failure (403/404/network) fall back to 0
     # via a SEPARATE statement — an inline `|| echo 0` would append 0 to the error body that
     # gh prints to stdout, yielding a non-integer. Then coerce empty/non-numeric to 0.
     # Required-check detection uses CLASSIC branch protection only. Any failure — incl. the 403
     # "Upgrade to GitHub Pro" on free-account private repos, or 404 when unprotected — counts as
     # zero required checks. GitHub *rulesets* are NOT consulted; enforce via rulesets ⇒ enable
     # auto-merge so GitHub gates the merge.
     reqChecks=$(gh api "repos/{owner}/{repo}/branches/<baseBranch>/protection/required_status_checks" \
                   --jq '(.checks // []) | length' 2>/dev/null) || reqChecks=0
     case "$reqChecks" in (''|*[!0-9]*) reqChecks=0 ;; esac
     if [ "$autoMerge" != "true" ] && [ "${reqChecks:-0}" -gt 0 ]; then
       echo "ABORT: auto-merge is disabled and '<baseBranch>' has required status checks — enable auto-merge (Settings → General → Pull Requests → Allow auto-merge) or merge manually once checks pass, then re-run /close"; exit 1
     fi
     ```

   **(b) Record the release on the feature branch** so it rides in on the merge commit — no separate base-branch write, and not speculative: this runs only *after* the merge instruction **and** after the preflight clears, so neither a re-review choice (step 4) nor a known-preventable abort (a) ever leaves release records on an unmerged branch. A record can sit on the PR branch only while a *handed-off* merge is still pending (e.g. auto-merge waiting on async checks); it reaches base solely via the merge commit, and the story header is never set to `merged`.
   - `CHANGELOG.md`: add a dated `## [<date>] — <slug> (PR #N)` entry **immediately below** `## [Unreleased]`, leaving the Unreleased section in place.
   - `BACKLOG.md`: **if** the story resolves a tracked `BUG-`/`OPS-` item, move that row to **Done**, referenced as `PR #N / merge: <slug>` — never a raw SHA (it's derivable: `git log <baseBranch> --oneline --grep "^merge: <slug>"`). A story with no tracked backlog item gets the CHANGELOG entry only.
   - Commit these on the feature branch. This record-keeping is **mechanical and rides post-review by design** — it does NOT need its own review round or a separate bookkeeping story (see doctrine: no bookkeeping-only stories).
   - **Do NOT touch the story header** — it stays `approved`. Declared state only; whether it shipped stays owned by git (the merge commit / PR-`MERGED`), never written into the header. The header is never set to `merged`.

   **(c) Re-gate the record commit.** Re-run `testCommand` against this HEAD; it must be green before push/merge, so the commit `--match-head-commit` ships is the gated one. (Mechanical record edits still get the gate; this needs no new *review* round.)

   **(d) Merge** the gated record HEAD. The **merge commit** (`merge: <slug>`, with a `Story:` trailer) / the PR's `MERGED` state is the atomic shipped fact and the only ship record — there is no separate tag to write or repair.
   - **Remote + `gh`:** this block is **self-contained and authoritative** — shell variables from (a) do NOT survive into this separate invocation, so recompute the strategy here, **decide the mode before pushing** (a backstop abort must never push the record commit), dispatch an explicit command, then poll for `MERGED`:
     ```bash
     localSha=$(git rev-parse HEAD)                            # the gated record HEAD (reviewed/fixed + release records)
     # Recompute the merge strategy authoritatively (do NOT rely on (a)'s vars).
     # reqChecks: capture on gh success only via a SEPARATE statement; an inline `|| echo 0`
     # would append 0 to the error body gh prints to stdout. Classic branch protection only;
     # any failure (403 "Upgrade to GitHub Pro" on free private repos, 404 unprotected) ⇒ 0.
     autoMerge=$(gh api repos/{owner}/{repo} --jq .allow_auto_merge)
     reqChecks=$(gh api "repos/{owner}/{repo}/branches/<baseBranch>/protection/required_status_checks" \
                   --jq '(.checks // []) | length' 2>/dev/null) || reqChecks=0
     case "$reqChecks" in (''|*[!0-9]*) reqChecks=0 ;; esac
     # Decide the mode BEFORE pushing. Explicit mode; abort on unknown — NEVER default to direct.
     case "$autoMerge" in
       true)  mode=auto ;;                                     # GitHub waits for any required checks
       false) if [ "${reqChecks:-0}" -gt 0 ]; then
                echo "ABORT: auto-merge is disabled and '<baseBranch>' has required status checks — enable auto-merge (Settings → General → Pull Requests → Allow auto-merge) or merge manually once checks pass, then re-run /close"; exit 1
              fi
              mode=direct ;;                                   # no required checks → direct merge ships now
       *)     echo "ABORT: could not determine allow_auto_merge (got '$autoMerge') — re-run /close"; exit 1 ;;
     esac
     git push origin HEAD                                      # PR head = approved fixes + records (only after the mode is decided)
     # --match-head-commit refuses if head has drifted from the gated SHA.
     case "$mode" in
       auto)   gh pr merge <PR#> --auto --merge --delete-branch --match-head-commit "$localSha" \
                 -t "merge: <slug>" -b "Story: reviews/<slug>.md" ;;
       direct) gh pr merge <PR#> --merge --delete-branch --match-head-commit "$localSha" \
                 -t "merge: <slug>" -b "Story: reviews/<slug>.md" ;;
     esac
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
