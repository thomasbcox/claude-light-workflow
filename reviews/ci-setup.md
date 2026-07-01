# ci-setup

Date: 2026-07-01 · Branch: claude/ci-setup · Status: approved

## Problem
The repo just went public but has **no CI** (`.github/` absent), `main` is **unprotected**, all
native GitHub security features are **disabled**, and `allow_auto_merge` is **false**. Its own docs
already say "the real backstop is server-side branch protection" — as a *future* thing. Now that the
repo is public (free Actions + free native security), we can make that backstop real and enforce the
existing gate server-side, per the CI-layering analysis (2026-07-01): **minimal local gate + rich CI
+ native security + a weekly drift scan, with branch protection as the enforcement point.**

Critical interaction: adding required status checks while `allow_auto_merge=false` would make
`/close`'s merge preflight **abort** (its OPS-5 three-way logic: auto-merge disabled + ≥1 required
check ⇒ abort). So enabling auto-merge is part of this story — and it finally exercises `/close`'s
**`MODE=auto`** path (built in OPS-4/5, never used because we've always merged `MODE=direct`).

## In scope
Two workflow files + three GitHub-settings operations + a docs refresh:
- **PR CI workflow** (`.github/workflows/ci.yml`) — on `pull_request` + `push` to `main`: run the
  **gate** (the `testCommand` suites), **shellcheck** on tracked `*.sh`, and a **gitleaks** secret
  scan of the PR. Pinned action versions, `ubuntu-latest`. Nonzero exit fails the check.
- **Scheduled workflow** (`.github/workflows/scheduled.yml`) — weekly cron: **gitleaks
  full-history** re-scan (drift check — catches secrets/rules that a per-PR diff scan wouldn't).
  Advisory (a failed run alerts; blocks nothing).
- **Native security** (via `gh api`, not a file): enable **secret scanning** + **push protection**
  + **Dependabot alerts**.
- **Branch protection on `main`** (via `gh api`): require the CI check to pass + require a PR before
  merge.
- **Enable `allow_auto_merge`** (via `gh api`): so `/close` uses `MODE=auto` under required checks.
- **Docs refresh:** update the README "Guardrail"/"Requirements" and `ARCHITECTURE.md` (§3.4 hook,
  §3.6 deploy/requirements) so the system map reflects that CI + branch protection now exist and the
  `/close` auto-merge path is now active.

## Non-goals
- **shfmt in CI** — the 4 shell files currently drift from shfmt style; gating on `shfmt -d` needs a
  reformat first (deferred OQ2). See Open Question 1.
- **semgrep / markdown-lint / external link-check** — low yield for a shell/markdown repo and/or
  network-flaky; deferred (Open Question 3).
- **CodeQL** — doesn't support bash; semgrep is the only SAST option and it's deferred anyway.
- **Dependabot version-update PRs** — no dependency manifest to update (alerts only, which are free).
- **pre-commit hooks** — deliberately skipped: the `/review` gate already fills the enforced
  inner-loop slot for this Claude-driven workflow (per the layering analysis).
- No change to the local gate / `testCommand` — the minimal-deps local contract stays untouched.

## Acceptance criteria
1. **PR CI runs the gate + shellcheck + gitleaks.** `.github/workflows/ci.yml` triggers on
   `pull_request` and `push` to `main`; it runs the `testCommand` gate, `shellcheck` on tracked
   `*.sh`, and a **gitleaks diff** scan; any failure fails the check. External actions pinned to
   **full commit SHAs** (comment naming the release); workflow sets minimal `permissions: contents: read`.
2. **Scheduled full-history secret scan.** `.github/workflows/scheduled.yml` runs weekly (cron) and
   executes a gitleaks **full-history** scan.
3. **Native security enabled.** `gh api repos/{owner}/{repo}` read-back shows `secret_scanning` and
   `secret_scanning_push_protection` = `enabled`, and Dependabot alerts on.
4. **`main` branch-protected (two-phase, admin-enforced).** After the CI check's real context name is
   observed on this story's PR, `gh api …/branches/main/protection` sets: the observed check as a
   required status check, **`enforce_admins=true`** (no operator bypass), and a required PR with
   **`required_approving_review_count=0`** (approval stays in the `/close` loop, not a GitHub review).
   Read-back confirms all three.
5. **Auto-merge enabled.** `allow_auto_merge = true` (read-back), so `/close`'s `MODE=auto` path
   handles the new required checks instead of aborting.
6. **Docs reflect reality.** README + `ARCHITECTURE.md` state that CI enforces the gate server-side,
   branch protection is now active (no longer "future"), and `/close` now merges via auto-merge.

## Test notes
- **AC1/AC2:** workflow YAML is valid and the trigger/steps are present (inspect; optionally
  `actionlint` if available). Real proof is the check running on **this story's own PR** — the story
  is self-validating (its CI must go green for it to merge under AC4).
- **AC3/AC4/AC5:** `gh api` read-backs (security_and_analysis; branch protection object;
  `allow_auto_merge`) show the target state.
- **AC6:** `grep` README/ARCHITECTURE for the updated CI/branch-protection wording; no stale "future
  backstop" phrasing left.
- **Local gate unaffected:** `bash tests/guard_test.sh && … && … dev_audit_test.sh` still green.
- **Scope containment:** `git diff --name-only main...HEAD` shows only `.github/workflows/ci.yml`,
  `.github/workflows/scheduled.yml`, `README.md`, `ARCHITECTURE.md`, and this story file. *(AC3–AC5
  are GitHub-settings operations, not file diffs — verified by `gh api` read-back, not the diff.)*

## Open questions
_All resolved at the frame consult (2026-07-01) — see Scope + Design decisions._
1. **shfmt in CI?** → **Deferred** (shellcheck only); no reformat in this story.
2. **gitleaks on PR — diff or full?** → **diff-on-PR + full-on-weekly-schedule.**
3. **semgrep / link-check in scheduled job?** → **No** — gitleaks-full only for now.
4. **Branch protection now or later?** → **Now, but two-phase** (Codex finding 2): observe the check
   name on this PR, then wire protection with that exact context. This story's PR is the first merge
   under protection.

## Scope decision (2026-07-01)
Thomas: **approve as one story · `enforce_admins=true` · fix both hardening findings (two-phase
rollout + SHA-pin actions) · defer shfmt.** Binding scope = 2 workflows + native security +
branch protection (admin-enforced, two-phase) + auto-merge + docs refresh.

## Design decisions (2026-07-01)
Disposition per Codex design finding (now binding):
- **BLOCKER (admin bypass) → FIX.** `enforce_admins=true`; required PR with
  `required_approving_review_count=0`. The backstop is real for the operator too; `/close` MODE=auto
  still merges when checks pass.
- **IMPORTANT (unobserved check) → FIX (two-phase).** Implement = push workflows + set the
  check-independent settings (native security, `allow_auto_merge`). **Phase 2** (at `/review`/`/close`
  time, once the PR's CI has emitted its check-run): read the *actual* context name, then set branch
  protection with it + `enforce_admins` + 0-review PR, and verify this PR's required check is green.
- **IMPORTANT (action pinning) → FIX.** All external actions pinned to full commit SHAs (comment
  naming the release); `permissions: contents: read` at workflow top.

## Design sketch — HOW
- **`.github/workflows/ci.yml`** — top-level `permissions: contents: read`; one `gate` job on
  `ubuntu-latest`: `actions/checkout` **pinned to a full SHA**, then steps: run the `testCommand`
  (bash/git/python3/jq — all present; `jq`/`shellcheck` preinstalled on ubuntu images), run
  `shellcheck --severity=warning` on `git ls-files '*.sh'`, and a **gitleaks diff scan** (pinned-SHA
  action or checksum-verified binary). Triggers: `pull_request` + `push: branches: [main]`. The
  emitted check name becomes the required context (observed in phase 2).
- **`.github/workflows/scheduled.yml`** — `on: schedule: - cron` (weekly) + `workflow_dispatch`;
  `permissions: contents: read`; one job running **gitleaks full-history** (whole log). Advisory.
  Actions SHA-pinned.
- **Settings via `gh api`** (verified by read-back, not committed files):
  - *Implement-time (check-independent):* `allow_auto_merge=true`; `security_and_analysis`
    (secret_scanning + push_protection); Dependabot alerts.
  - *Phase 2 (after observing the PR check name):* `PUT …/branches/main/protection` with
    `required_status_checks` = the observed context, **`enforce_admins=true`**, and
    `required_pull_request_reviews.required_approving_review_count=0`. No admin bypass; `/close`
    MODE=auto still merges on green checks.
- **Central interaction:** required checks + `allow_auto_merge=true` ⇒ `/close` preflight resolves to
  `MODE=auto` (GitHub waits for the check, then merges). This is the first real use of the OPS-4/5
  auto-merge path. No `/close` change needed — it already branches on exactly this.
- **Docs:** flip the README "Guardrail" note and `ARCHITECTURE.md` §3.4/§3.6 from "branch protection
  is the *future* real backstop" to "CI enforces the gate; `main` is branch-protected; `/close`
  merges via auto-merge." Small, keeps the system map honest (the lesson from the dev-audit story).

## Codex design review (2026-07-01)
Verdict: **sound as one story, not a split** — the workflows, branch protection, `allow_auto_merge`,
and docs are coupled by `/close`'s MODE logic, and `gh api` read-back is a reasonable way to verify
non-file settings here. Three findings tighten the rollout + security posture before it's a *real*
backstop.

**BLOCKER — Admin bypass leaves the promised backstop cooperative** · one-way · nonstandard
- *Claim:* Keeping `enforce_admins=off` means the admin token driving `gh` can still bypass required
  PR/checks (incl. the documented destination-refspec hook gap) — so the docs' "real backstop" claim
  stays false. `/close`'s auto-merge path does **not** need admin bypass when checks pass.
- *Alternative:* Set `enforce_admins=true`; require a PR with
  `required_approving_review_count=0` (Thomas's approval stays in-loop, not a GitHub review); if an
  emergency bypass is ever wanted, document it as a manual owner action outside the light workflow.
- *Win:* Makes the stated invariant true for the actual operator and closes the local-hook gaps
  server-side, while preserving the normal `/close` MODE=auto path.

**IMPORTANT — Required check is assumed before it is observed** · one-way · dated
- *Claim:* Assuming a job named `gate` is the required context and proving it via protection
  read-back is brittle — required checks bind to the exact emitted check name; a mismatch reads back
  as "configured" while leaving auto-merge stuck / the first PR blocked.
- *Alternative:* **Two-phase rollout** (still one story): (1) add + push the workflows, observe the
  *actual* PR check-run name; (2) configure branch protection with a literal payload using that
  exact context (checks/app_id where available), an explicit `strict` choice, and
  `required_approving_review_count=0`; verify both the protection read-back *and* that this PR's
  required check is green.
- *Win:* Removes the chicken-and-egg failure mode and proves `/close` waits on the same check
  protection requires.

**IMPORTANT — Action pinning is under-specified for a security boundary** · two-way · nonstandard
- *Claim:* "version-pinned" still permits mutable tag pins (`@v4`); for a new security backstop —
  especially the third-party gitleaks action — a moved tag / compromised publisher is a supply-chain
  path.
- *Alternative:* **Full commit-SHA pins** for all external actions (comment naming the release), set
  minimal workflow `permissions: contents: read`, and verify release checksums if using binaries.
- *Win:* Hardens the new trust boundary with no added local deps or complexity.
