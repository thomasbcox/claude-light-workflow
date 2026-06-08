Date: 2026-06-07 · Branch: claude/install-drift-check · Status: approved
Approved: Thomas approved scope as written, 2026-06-07 ("full manifest please, json"). Resolved
both open questions: JSON manifest at `~/.claude/workflow-manifest.json`; `--check` classifies
drift as stale-vs-hand-edited via the recorded commit; exit code — file drift → non-zero,
commit-moved-but-files-still-match → informational (exit 0).

## Problem

`install.sh` is a manual, one-way, hard-overwrite push from the repo to `~/.claude`. Three
related gaps make deployment drift and staleness invisible — felt firsthand this session, when
"are the deployed skills current?" was only answerable by running an ad-hoc `diff -rq` by hand:

- **OPS-1** — no drift detection between repo `.claude/skills` (+ hook, protocol, AGENTS
  template) and their deployed copies. Nothing warns when they diverge.
- **OPS-2** — no provenance stamp: you can't tell which repo commit a deployed copy came from,
  so staleness is invisible even when files happen to differ.
- **OPS-3** — propagation is hard-overwrite with no record: a hand-edit to a global copy is
  silently clobbered. Acceptable *by design*, but it should be observable before the clobber.

OPS-3 explicitly depends on OPS-1/OPS-2, so the three ship as one coherent story: add a
provenance manifest (OPS-2), a read-only drift/staleness check (OPS-1), and a pre-overwrite
drift summary on normal installs (OPS-3) — while keeping the hard-overwrite behavior unchanged.

## In scope

- `install.sh` only:
  1. Define the deployed-artifact set **once** (single source of truth shared by install and
     check): `skills/{frame,review,close}`, `hooks/block-main-writes.sh`, `workflow-protocol.md`
     (← `.claude/workflow-protocol.md`), `workflow-AGENTS-template.md` (← `AGENTS.md`).
  2. **OPS-2 — manifest.** On a normal install, write a provenance manifest into the deployment
     recording the source commit SHA (or `unknown` outside a git checkout), a dirty-tree flag,
     an install timestamp, and the deployed-artifact list.
  3. **OPS-1 — `--check`.** Add an `install.sh --check` mode that writes nothing and reports,
     per artifact, IN SYNC vs DRIFT (repo source vs deployed copy); reports the deployment's
     recorded source commit and compares it to the repo's current HEAD; exits non-zero on file
     drift, zero when all artifacts are in sync.
  4. **OPS-3 — observable clobber.** On a normal install, when a prior deployment + manifest
     exist, print a pre-overwrite summary of what currently diverges (drifted files + recorded
     provenance) before overwriting. The overwrite still proceeds unchanged.
  5. Make the deployment target overridable via an env var (default `$HOME/.claude`) so install
     and `--check` can be pointed at a temp dir for isolated testing.

## Non-goals

- Do **not** change the hard-overwrite propagation model (OPS-3 is observability, not a softer
  merge or an interactive confirm). Install stays idempotent and non-interactive.
- Do **not** alter the `settings.json` hook-wiring merge or its idempotence/back-up behavior.
- No new dependencies beyond what `install.sh` already requires (`bash` + `git` + `diff` +
  `jq`). The manifest is JSON, written and read with the `jq` the script already depends on.
- No changes to skills, hook, protocol, AGENTS contract, tests, or docs.
- Not consulting GitHub or any network; drift/provenance are computed locally.
- Not adding a dedicated install test to the gate (the project gates only the guard hook;
  `--check` is itself the standing verification tool). Verification here is by running
  `install.sh` / `install.sh --check` against a temp target — see Test notes.

## Acceptance criteria

1. **(OPS-2)** A normal `install.sh` run writes a provenance manifest into the deployment
   containing: source commit SHA (or `unknown`), a dirty-tree indicator, an install timestamp,
   and the list of deployed artifacts.
2. **(OPS-1)** `install.sh --check` writes nothing to the deployment (read-only) and prints a
   per-artifact IN SYNC / DRIFT report comparing repo source to deployed copy, using the same
   artifact set as the install path.
3. **(OPS-1)** `install.sh --check` exits non-zero when at least one artifact has drifted, and
   zero when every artifact is in sync.
4. **(OPS-2)** `install.sh --check` reports the deployment's recorded source commit and compares
   it to the repo's current HEAD — flagging staleness when they differ, and noting the absence
   of a manifest for a pre-OPS-2 deployment.
5. **(OPS-2/OPS-3) Drift classification.** When an artifact has drifted, `--check` classifies it
   using the recorded commit: **STALE** if the deployed copy matches the repo content *at the
   manifest commit* (repo moved forward → safe to re-install) vs **HAND-EDITED** if it matches
   neither current repo nor the manifest commit (local edits a re-install would clobber). If the
   manifest commit is `unknown`/absent, `--check` says it cannot classify and falls back to a
   plain differs/matches report.
6. **(OPS-3)** A normal `install.sh` run, when a prior deployment + manifest exist, prints a
   pre-overwrite summary of what diverges — including any **HAND-EDITED** artifacts whose local
   changes the overwrite will destroy — before clobbering; the hard-overwrite then proceeds
   (behavior otherwise unchanged).
7. The deployment target is overridable via an env var (default `$HOME/.claude`); install and
   `--check` both honor it.
8. Existing behavior preserved: install remains idempotent, and `settings.json` is never
   clobbered — the hook-wiring merge stays guarded against duplicate entries and backs up once.

## Test notes

- AC1: run `install.sh` against a temp target (env override); `jq .` the manifest — assert it
  parses as JSON and contains a commit field, dirty indicator, timestamp, and the artifact list.
- AC2, AC3: with the temp target in sync, run `--check` → all IN SYNC, exit 0; perturb one
  deployed file, re-run `--check` → that artifact reports DRIFT, exit non-zero; confirm the
  deployment was not modified by `--check`.
- AC4: with the manifest's commit set to an older/`unknown` value, `--check` reports the
  recorded commit and flags staleness vs HEAD; remove the manifest → `--check` notes its
  absence.
- AC5 (classification): (a) check out the repo to an older commit's content for one artifact so
  the deployed copy matches the manifest commit but not current HEAD → `--check` reports
  **STALE**; (b) hand-edit a deployed copy to content matching neither → `--check` reports
  **HAND-EDITED**; (c) set manifest commit `unknown` → `--check` reports it cannot classify.
- AC6: in a temp target with a manifest and a HAND-EDITED deployed file, re-run `install.sh` →
  output includes a pre-overwrite summary naming the hand-edited file and warning its changes
  will be lost; afterward the file matches the repo source again.
- AC7: demonstrate both install and `--check` operating against the temp target via the env
  override, leaving the real `$HOME/.claude` untouched.
- AC8: re-running install against a temp target with an existing `settings.json` preserves it
  and does not add a duplicate hook entry.
- Gate: `bash tests/guard_test.sh` must still pass (no hook/test changes).
- Scope containment: run `git diff --name-only main...HEAD`; verify no files appear beyond
  those enumerated in the In-scope section (`install.sh`) plus this story file.

## Open questions

None. (Resolved 2026-06-07: (1) exit code — file drift → non-zero, commit-moved-but-files-match
→ informational/exit 0; (2) manifest = JSON at `~/.claude/workflow-manifest.json`, written/read
with the `jq` the script already depends on.)

## Build note (2026-06-08)

AC→file map — all eight ACs are implemented in `install.sh` (single-file change):
- AC1 (provenance manifest write): `write_manifest()`
- AC2–AC3 (`--check` read-only per-artifact report; exit codes): `do_check()` + `scan()`
- AC4 (recorded commit vs HEAD; missing-manifest note): `scan()` provenance block
- AC5 (STALE / HAND-EDITED / UNCLASSIFIED classification): `classify_drift()`
- AC6 (pre-overwrite drift summary + hand-edit warning): `do_install()` pre-overwrite block
- AC7 (deploy target override): `DEST="${CLAUDE_WORKFLOW_DEST:-$HOME/.claude}"`
- AC8 (idempotent; settings.json preserved): unchanged `jq` hook-merge block
- Shared artifact set (single source of truth for install + check): `ARTIFACTS` array

Note: a `set -e` trap surfaced and was fixed during build — `scan()` returned the status of its
last short-circuited `[ … ] && echo` test, which under `set -e` aborted the install path before
deploying; fixed with an explicit `return 0` (status is owned by `DRIFT_COUNT`).
