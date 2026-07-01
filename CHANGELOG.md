# Changelog

All notable changes to this workflow are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2026-07-01] — shell-tooling (PR #23)

### Fixed
- `install.sh`: removed a dead `status` local variable (shellcheck SC2034).

### Added
- **`/dev-audit` Table A now has a Shell row** (marker `*.sh` / shebang → `shellcheck`, `shfmt -d`
  read-only) so shell-heavy repos get first-class tool selection instead of falling through to the
  generic cross-cutting row (**OPS-10**). Surfaced by dogfooding `/dev-audit` on this repo.
  Wiring `shellcheck` into the gate was deferred to a CI follow-up to preserve the minimal gate
  contract (`bash`/`git`/`python3`/`jq`).

## [2026-06-30] — dev-audit (PR #22)

### Added
- **`/dev-audit` — a pre-loop repo-recon skill** (standalone from `frame`/`review`/`close`).
  Pointed at a repo, it detects type + maturity and selects analysis tools that fit *that* repo,
  with rationale, then reports findings + risk + prioritized next steps. Key shapes:
  - **Declarative tool selection** — one ecosystem→toolset table (Table A) with a **read-only /
    check mode** column that pins the non-destructive invocation per tool (the AC7 invariant lives
    in the table, not per-run judgment; `--check`/`--dry-run`/omit-`--fix`, never a write mode).
  - **Declarative classification** — one matrix (Table B) maps safeguard conditions → maturity tier
    (`prototype`/`developing`/`mature`) · risk level · safeguard flags (no CI / weak tests /
    unpinned deps / weak secret handling).
  - **Hybrid execution** — a zero-dependency core always runs; heavier tools are `command -v`-gated
    (run if present, else *recommended (not installed)*). Installs nothing.
  - **Secret-redaction invariant** — secret hits report detector/type · path:line · count ·
    remediation, never the value, so the audit artifact never becomes a second leak.
  - **Report-first, human-gated hand-off** — graduates findings into `BACKLOG.md` as `AUDIT-`
    items only on an explicit instruction; honors the `docs/ai-protocol.md` stand-down.
- Wired into `install.sh`, the gate (`tests/dev_audit_test.sh`, a drift-only linter), and the
  system-map docs (`README.md`, `ARCHITECTURE.md`, `BACKLOG.md`).

### Changed
- **`/close` is now generic over any tracked backlog item** (`BUG-`/`OPS-`/`AUDIT-`/future), so
  audit-sourced findings complete the loop instead of being stranded at close.

## [2026-06-27] — pluggable-reviewer (PR #21)

### Added
- **Selectable independent-reviewer backend.** New `reviewer` field in `.claude/workflow.json`
  (default `codex`) plus a per-invocation `/review` override (`/review llm`, order-independent with
  `approach`/`correctness`). The canonical resolution rule + per-backend dispatch live in
  `review/SKILL.md` → *Reviewer backend*; the value set `{codex, llm}` is extensible. **Codex remains
  the only wired backend** — its `codex exec` envelope is unchanged; selecting `llm` (the designated
  second source) stops with a "not yet wired" message rather than falling back.
- **`tests/reviewer_test.sh`** — a labeled documentation-consistency linter for the seam (drift
  detection only; explicitly *not* a behavioral gate — the seam is Markdown instructions, so real
  verification is the independent diff review + a human read).

### Changed
- **Reviewer role language is now tool-neutral** ("the independent reviewer") across the skills and
  docs; `AGENTS.md` is the tool-neutral reviewer contract. Literal `codex` is retained only where the
  concrete CLI / `codexModel` key / `.codex.json` artifact is meant; the "Claude↔Codex" brand stays.

### Notes
- Google's Antigravity (`agy`) was evaluated as the second backend and **abandoned**: no read-only
  sandbox, no schema output, fragile non-TTY capture; the headless Gemini CLI has since folded into
  Antigravity. `llm` is the designated second source — wiring it (non-agentic adapter + executable
  tests) is a deferred follow-up. See `reviews/pluggable-reviewer.md` for the trail.

## [2026-06-25] — honest-system-docs (PR #20)

### Added
- **`ARCHITECTURE.md`** — a live requirements → approach → intended-implementation narrative for the
  light workflow, linked from the README. Distinct from the historical parent doc.

### Changed
- **Guard docs now match the hook's real behavior** (docs-only; no enforcement logic changed). The
  README Guardrail section, the `block-main-writes.sh` header comment, `workflow-protocol.md` rule 5,
  and the `/frame` + `/close` parentheticals describe the hook as a cooperative **current-branch
  `main`/`master` tripwire** — not base-branch enforcement — and name what it does **not** catch
  (configured `baseBranch`, `HEAD:main` refspec, `env`-wrapped / nested-shell git). The "never commit
  to base directly" rule stays; only the false enforcement attribution was softened. This delivers the
  "soften docs" sub-part of the decided-against OPS-6; hardening remains decided-against.
- **`ai-dev-workflow-architecture.md` reframed as historical** — a prominent parent banner and inline
  claims re-pointed at the parent AI Protocol v3, so it can no longer be mistaken for this repo's live
  doctrine.

### Note
- The hook/skill/protocol edits put the deployed `~/.claude` copy behind this branch; run `./install.sh`
  to resync (`--check` will report drift until then).

## [2026-06-25] — design-review-loop (PR #19)

### Added
- **A design-review altitude + a one-way-door consult model**, replacing "decide twice." The human is
  consulted at three altitudes — requirements, high-level design, implementation tradeoffs — plus the
  merge. Two decoupled dials: *blocking* by reversibility (only one-way doors — architecture, data
  model, a new dependency, or a cross-cutting pattern future code will copy — stop Claude; two-way
  calls default and are logged for veto), and *assessment* always-on against modern best practice
  (Codex flags nonstandard/dated/kludgy choices even when reversible; guardrails: a concrete win not
  novelty, weigh internal consistency, repo conventions are the local standard).
- **`/frame` gains a design sketch + a Codex design review** of it (new shared `design-review-schema.json`),
  decided in one combined frame consult (scope + one-way-door ratification + best-practice flags).
- **`/review` gains an approach pass that gates the correctness pass** — round-keyed default (approach
  on first review + post-redesign rounds; correctness-only on fix-verification re-reviews), bare-arg
  overrides `/review approach|correctness`, and a decision-gated short-circuit (an accepted redesign
  skips correctness and re-reviews; a blessed/clean shape runs correctness in the same round).
  Invariant: correctness only runs on a shape that cleared approach review.

### Changed
- `AGENTS.md` splits grounding (correctness = diff; design/approach = spec + surroundings, may cite
  absent code) and adds the always-on best-practices mandate, guardrails, and reversibility/standing tags.
- `/close` step 4 is now conditional — an accepted approach/redesign fix routes to re-review, never a
  straight merge.
- `README.md` documents the new loop and the override args.

### Notes
- Independent review (Codex) caught a self-inflicted merge-fork contradiction across rounds 1–2 (the
  AC11 "redesign ⇒ re-review only" rule was contradicted first in `/close` step 4, then in its hard
  constraint + `/review` step 9); resolved at the source and verified clean in round 3.
- `ai-dev-workflow-architecture.md` (which documents the parent AI Protocol v3, not this system) is
  intentionally untouched; de-parenting it is a follow-up story.

## [2026-06-18] — close-folds-in-records (PR #18)

### Changed
- **`/close` folds release records into the pre-merge branch.** After the distinct merge
  instruction (and after the merge-strategy preflight), `/close` writes the `CHANGELOG.md` entry
  and the `BACKLOG.md` Done-move *on the feature branch*, so they ride in on the merge commit —
  no separate post-merge base write, and not speculative (a re-review choice never reaches them;
  the story header is never set to `merged`). Step 5 is ordered **preflight → record → re-gate →
  merge**, with a **single** merge-strategy decision in 5(a) (prints `MODE=auto`/`MODE=direct` or
  aborts) that 5(d) merely dispatches — no duplicated policy. Retires the per-story
  `bookkeeping-*` follow-up pattern.
- **Doctrine.** `.claude/workflow-protocol.md` and `BACKLOG.md` add the **no bookkeeping-only
  stories** rule and the `PR #N / merge: <slug>` reference convention (Done items no longer store a
  derivable raw merge SHA).
- **Books squared (one-time).** Fixed the BUG-5 Done-row placeholder (`<merge>` →
  `merge: drop-shipped-tag`) and added the missing `drop-shipped-tag (PR #17)` entry above.
- Independent review (Codex) caught three BLOCKERs on the merge path across rounds 1–3 (stranded
  records on abort; shell-var scope; (a)/(d) policy divergence); resolved by the single-decision
  Option B and verified clean in round 4.

## [2026-06-14] — drop-shipped-tag (PR #17)

### Removed
- **`shipped/<slug>` tag convention**: the merge commit (`merge: <slug>`) / PR-`MERGED` state is
  now the single ship record. `/close` no longer creates, pushes, or verifies a tag; doctrine,
  `/frame` header guidance, and the README drop the tag as a convenience marker. This obviates
  **BUG-5** (the guard blocked the post-merge tag push from `main`) by design — nothing pushes
  from `main`, so the guard is never engaged — and retires the abandoned `guard-allow-tag-push`
  fix (PR #16, closed unmerged). The 13 existing `shipped/*` tags (local + remote) were deleted.

## [2026-06-14] — bookkeeping-pr14-bug5 (PR #15)

### Changed
- **`BACKLOG.md`**: BUG-4 moved to Done (PR #14 / `0504e31`); **BUG-5** logged as a new open
  skill-behavior bug (guard hook blocks the sanctioned `shipped/<slug>` tag push during
  `/close`). **`CHANGELOG.md`**: backfilled the dated entry for PR #14. OPS-9 left open.

## [2026-06-14] — review-schema-abs-path (PR #14)

### Fixed
- **`/review` schema path (BUG-4)**: the documented `codex exec` command passed
  `--output-schema` as a repo-relative path (`.claude/skills/review/finding-schema.json`),
  which only resolves from this repo — so `/review` aborted ("Failed to read output schema
  file … No such file or directory") from every other project repo, before doing any review.
  Changed to the absolute user-level `"$HOME/.claude/skills/review/finding-schema.json"`
  (where `install.sh` deploys it); `-o reviews/<slug>.codex.json` stays repo-relative, with a
  step-5 note on the intentional asymmetry. The next defect in the same command block as
  `review-codex-stdin` (PR #12).

### Changed
- **`BACKLOG.md`**: logged **OPS-9** — evaluate whether the three skills need any YAML
  frontmatter beyond `name` + `description` (e.g. `allowed-tools`); not a known gap.

## [2026-06-08] — review-codex-stdin (PR #12)

### Fixed
- **`/review` codex hang**: the documented `codex exec` command had no stdin redirect, so codex
  blocked reading stdin (`Reading additional input from stdin…`) on non-interactive runs and hung
  the review. Appended `</dev/null` (binds to `codex exec`, before any `2>&1 | tail` a runner
  adds) plus a note to keep it. Surfaced while reviewing `install-drift-check`.

## [2026-06-08] — install-drift-check (PR #11)

### Added
- **Deployment-drift observability (OPS-1/2/3)** in `install.sh`:
  - **OPS-2 — provenance manifest**: every install stamps `~/.claude/workflow-manifest.json`
    (source commit, dirty flag, timestamp, deployed-artifact list).
  - **OPS-1 — `install.sh --check`**: read-only per-artifact IN SYNC/DRIFT report across the
    deployed set; compares the recorded commit to repo HEAD; exits non-zero on file drift.
    Classifies drift as **STALE** (repo moved forward) vs **HAND-EDITED** (local edits a
    re-install would clobber) vs **UNCLASSIFIED** (recorded commit unavailable).
  - **OPS-3 — observable clobber**: a normal install prints a pre-overwrite drift summary,
    warning when hand-edited artifacts are about to be lost, before the hard-overwrite proceeds.
  - Deploy target overridable via `CLAUDE_WORKFLOW_DEST` for isolated testing.

## [2026-06-07] — bookkeeping-pr8-pr9 (PR #10)

### Changed
- **`BACKLOG.md`**: OPS-4 confirmed in Done; OPS-5/OPS-7 moved to Done and the OPS-5-fix
  follow-up recorded. **`CHANGELOG.md`**: backfilled dated entries for PRs #8 and #9.

## [2026-06-07] — ops5-reqchecks-fallback (PR #9)

### Fixed
- **`/close` required-check detection (OPS-5 follow-up)**: the OPS-5 pre-flight's `reqChecks`
  count did not degrade to zero on a `403`/`404`. An inline `|| echo 0` inside the command
  substitution appended `0` to the error body `gh api` prints to stdout on failure, yielding a
  non-integer (e.g. `{"message":…}0`) that broke the `[ -gt 0 ]` test. Fixed: capture the count
  on `gh` success only via a separate-statement fallback (`… ) || reqChecks=0`), then coerce
  empty/non-numeric to `0` with a `case` guard. Surfaced by dogfooding the PR #8 merge.

## [2026-06-07] — ops5-ops7-ergonomics (PR #8)

### Fixed
- **`/close` auto-merge pre-flight too strict (OPS-5)**: it aborted whenever `allow_auto_merge`
  was `false`, even with no required checks. Replaced with a three-way strategy — auto-merge
  path when enabled, direct `gh pr merge` when disabled with no required checks, abort only when
  disabled *and* the base branch has ≥1 required status check. Required-check detection uses
  classic branch protection, degrading to zero on `403`/`404`; rulesets are out of scope
  (documented in the skill comment).

### Changed
- **`/frame` test-notes guidance (OPS-7)**: the `## Test notes` template now warns against
  restating file counts ("must show only N files") for scope-containment ACs — a DRY violation
  that goes stale on scope change — and directs `git diff --name-only` against the AC's
  enumerated file list instead.

## [2026-06-06] — auto-merge-close (PR #6)

### Fixed
- **`/close` remote merge race (OPS-4)**: replaced the hand-rolled `mergeStateStatus` 5×5s poll
  loop with `gh pr merge --auto`, delegating merge timing to GitHub. Added `autoMergeAllowed`
  pre-flight check (via `gh api repos/{owner}/{repo} --jq .allow_auto_merge`) and a MERGED-state
  poll (30×10s, 5-min timeout) for synchronous confirmation. Retains `--match-head-commit` for
  drift safety.

## [2026-06-06] — harden-merge-and-guard (PR #5)

### Fixed
- **`/close` stale-head risk**: remote recipe now captures the local fix SHA, pushes HEAD before
  merging, asserts `headRefOid == localSha`, and merges with `--match-head-commit <sha>`.
- **Guard hook bypass forms**: rewrote `block-main-writes.sh` to tokenize argv and walk global git
  options (`-C`, `-c`, `--git-dir`, etc.) to the true subcommand, catching `git -C <repo> commit`,
  `git -c k=v commit`, `+refspec` force pushes, `--force-with-lease=<ref>` value forms, and
  `--mirror`. False-positive on benign commands (e.g. `grep 'git push'`) eliminated.
- **Docs**: README and `workflow-protocol.md` no longer advertise the retired `codex exec review`
  subcommand; updated to `codex exec -s read-only --output-schema …`.

### Added
- **Guard test harness** (`tests/guard_test.sh`): 19 JSON-payload cases covering bypass forms
  (denied) and false-positive forms (allowed), wired as the repo's `testCommand`.

## [2026-06-05] — backlog-bookkeeping (PR #4)

### Changed
- **`BACKLOG.md`**: BUG-D1/D2/D3 moved to Done (shipped PR #2); open bugs section cleared.
- **`CHANGELOG.md`**: `[Unreleased]` section populated with the `close-gate-and-backlog` fixes.

## [2026-06-03] — close-gate-and-backlog (PR #2)

### Fixed
- **`/close` merge gate & status lifecycle**:
  - The story header no longer asserts `Status: merged` before a merge happens. It records only
    *declared* state (`proposed → approved`, terminal); whether it shipped is *observed* state owned
    by git — authoritatively the merge commit / PR-`MERGED` state — read back by deriving, never
    hand-written into the header (single source of truth; declared-vs-observed).
  - `/close` now states unambiguously that **invoking `/close` is NOT merge authorization**; a
    distinct, in-session "merge" instruction is required *after* the re-review fork, every time.
  - The "re-review or merge?" fork is **mandatory and non-skippable**, even on a clean review with
    zero fixes.

### Added
- **`shipped/<slug>` tag convention** — a best-effort, out-of-tree "this shipped" marker created at
  merge time (the merge commit / PR-`MERGED` state remains the authority).
- **`BACKLOG.md`** — staging area in front of the loop (`BUG-`/`OPS-` items) + README pointer.

### Changed
- **`/review`** decision menu/routing wording clarified: deciding fix/defer/reject is not a merge
  decision, and routing to `/close` does not authorize a merge.
- **Doctrine** (`workflow-protocol.md`, `frame`) documents the declared-vs-observed status lifecycle.

## [2026-06-03] — Bootstrap

### Added
- **Three skills** driving the Claude↔Codex review loop: `frame` (intake → spec → implement),
  `review` (gate → read-only `codex exec` with a structured-output schema → decision menu), and
  `close` (apply approved fixes → merge).
- **Guard hook** (`.claude/hooks/block-main-writes.sh`): blocks commits/pushes to the base branch and
  `--force` / `--no-verify`, wired as a `PreToolUse` hook.
- **Reviewer contract** (`AGENTS.md`): Codex's standing instructions — critique and classify, never
  fix or merge.
- **Protocol doc** (`.claude/workflow-protocol.md`): the doctrine and the loop.
- **Structured findings schema** (`.claude/skills/review/finding-schema.json`) for the Codex review handoff.
- **Per-repo config** (`.claude/workflow.json`) and the `reviews/` audit trail.
- **Installer** (`install.sh`) to promote the skills and hook to `~/.claude` for use across all apps.
