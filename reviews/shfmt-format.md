# shfmt-format

Date: 2026-07-01 · Branch: claude/shfmt-format · Status: approved

## Problem
The tracked shell files drift from `shfmt` style (surfaced by dogfooding `/dev-audit`; deferred as
OQ2 in `shell-tooling`, deferred again in `ci-setup`). Nothing keeps them consistently formatted.
This story finally closes it: reformat the shell files once, and add a `shfmt` check to CI so they
stay formatted — mirroring how `shellcheck` lives in CI (not the minimal local gate).

Measured: under `shfmt -i 2 -ci` (2-space indent matching the files + case-indent), the four files
change by whitespace only — install.sh 154, guard_test 99, reviewer_test 79, dev_audit_test 129 diff
lines. The hook `.claude/hooks/block-main-writes.sh` is **already** `-i 2 -ci`-clean, so it needs no
change and a CI check over all `*.sh` passes once the four are reformatted.

## In scope
- **Reformat** the four tracked shell files with `shfmt -w -i 2 -ci` (canonical shfmt layout —
  semantics-preserving, includes reflowing compact one-liners; see amendment):
  `install.sh`, `tests/guard_test.sh`, `tests/reviewer_test.sh`, `tests/dev_audit_test.sh`.
- **CI check:** add a `shfmt -d -i 2 -ci` step to `.github/workflows/ci.yml` over
  `git ls-files '*.sh'`, so drift fails the `gate` check. shfmt installed on the runner as a
  **pinned, checksum-verified binary** (mirroring the gitleaks install pattern).

## Non-goals
- **Not** adding shfmt to the local gate (`testCommand`) — stays minimal (`bash/git/python3/jq`),
  consistent with `shellcheck` living in CI only.
- **No** reformat of the hook (already conformant) and **no** logic changes anywhere — whitespace only.
- Not changing `shellcheck`/gitleaks steps or any other workflow behavior.

## Acceptance criteria
1. **Files are shfmt-clean.** `shfmt -d -i 2 -ci $(git ls-files '*.sh')` produces **no output**
   (exit 0) on the branch.
2. **Semantics-preserving reformat.** The `.sh` changes are produced **solely** by
   `shfmt -w -i 2 -ci` (a formatter — layout only, **including reflowing compact one-liners** like
   `if x; then y; fi` into shfmt's canonical multi-line form). No logic changed: `bash -n` is clean on
   each file and the gate passes. *(Amended — this is NOT whitespace-only; see the amendment below.)*
3. **CI enforces it.** `ci.yml` has a `shfmt -d -i 2 -ci` step over tracked `*.sh` (shfmt installed
   pinned + checksum-verified); the step fails on drift. Validated by PR #N's `gate` check passing.
4. **Local gate still green + untouched.** `bash tests/guard_test.sh && … && … dev_audit_test.sh`
   passes; `.claude/workflow.json` `testCommand` is unchanged.

## Test notes
- **AC1:** run `shfmt -d -i 2 -ci $(git ls-files '*.sh')` → empty.
- **AC2:** the reformat is `shfmt -w -i 2 -ci` output only (no hand edits); `bash -n` clean on each
  `.sh`; gate green. (`git diff -w` is **not** empty — shfmt reflows compound statements — so
  "semantics-preserving" is verified by bash -n + gate + reviewer, not by an empty whitespace diff.)
- **AC3:** inspect the new `ci.yml` step (pinned shfmt + `-i 2 -ci`); the real proof is the PR's
  `gate` check going green with the step present.
- **AC4:** run the gate locally; `git diff main...HEAD -- .claude/workflow.json` is empty.
- **Scope containment:** `git diff --name-only main...HEAD` shows only the four `*.sh` files,
  `.github/workflows/ci.yml`, and this story file.

## Open questions
1. **Flag set** — `-i 2 -ci` (2-space + case-indent) is recommended: matches the files' existing
   2-space style and slightly lowers churn vs `-i 2` alone. Alternatives add opinion/churn
   (`-sr` space-after-redirect, `-bn` binary-op-at-line-start). **Recommend `-i 2 -ci`.**
2. **shfmt install in CI** — pinned checksum-verified **binary** (mirrors gitleaks; smallest trust
   surface) vs a pinned third-party action. **Recommend the binary.**

## Scope decision (2026-07-01)
Thomas: **approve with recommended defaults** — scope as written; flags **`-i 2 -ci`**; shfmt in CI
as a **pinned, checksum-verified binary** (mirrors gitleaks). Clean design pass (no Codex findings,
no one-way doors) — scope nod only.

**Amendment (2026-07-01, mid-implementation):** the reformat is **not whitespace-only** as the spec
originally claimed — `shfmt` reflows this repo's deliberate compact one-liners (`if x; then y; fi`)
into canonical multi-line form (~83 structural lines of the ~275-line diff; `bash -n` clean, gate
green — semantics preserved). Surfaced to Thomas as a genuine style decision (adopt shfmt's canonical
style vs keep the compact style, which shfmt cannot preserve). **Thomas ratified full shfmt adoption**
— *"commit to shfmt everywhere"* — making it an **estate-wide standard** (recorded in global memory):
`shellcheck` for correctness + `shfmt -i 2 -ci` for format, both CI-enforced, across all his repos.
AC2 corrected from "whitespace-only / `git diff -w` empty" to "semantics-preserving (shfmt output only,
`bash -n` clean, gate green)."

## Codex design review (2026-07-01)
Verdict: **sound shape — no design findings.** Reformatting the four files with `shfmt -i 2 -ci` and
enforcing `shfmt -d -i 2 -ci` across tracked `*.sh` in CI fits the repo's conventions (minimal local
gate; tool-heavy checks in CI next to ShellCheck + gitleaks). Pinned checksum-verified binary matches
the gitleaks trust model without a third-party action. Running on PRs **and** pushes is correct
(formatting is cheap + meaningful on every `gate` event; gitleaks is PR-scoped for commit-range
scanning, not a general rule). `git ls-files '*.sh'` isn't NUL-safe but matches the existing ShellCheck
convention with no concrete payoff to change. The whitespace-only claim stays backed by the explicit
`git diff -w` acceptance check (already in the spec). **Empty findings.**

## Design sketch — HOW
- **Reformat:** `shfmt -w -i 2 -ci <the four files>`. shfmt rewrites layout only — indent
  normalization, collapsing manual double-spaces (`foo()  {` → `foo() {`), **and reflowing
  `;`-compound one-liners into multi-line** (the ~83 structural lines). It never changes tokens
  (semantics preserved), but the diff is therefore *not* whitespace-only — AC2 verifies
  semantics-preservation via `bash -n` + gate, not an empty `git diff -w`.
- **CI step** in `ci.yml`, alongside `shellcheck`, running on the same events (PR + push): install
  shfmt from its GitHub release (pinned version, `sha256sum -c` verified, into `$RUNNER_TEMP`), then
  `"$RUNNER_TEMP/shfmt" -d -i 2 -ci $(git ls-files '*.sh')`. Unlike the gitleaks step there is no
  PR-only scoping — a format check is meaningful on every event (same as `shellcheck`), so
  install+check runs unconditionally.
- **Flag single-sourcing:** the exact flags (`-i 2 -ci`) appear in the reformat commit and the CI
  step; a comment in `ci.yml` notes they must match the reformat. (No config file — shfmt is invoked
  with explicit flags, the repo's minimal-tooling style; a `.editorconfig` is a possible future
  alternative, out of scope here.)
