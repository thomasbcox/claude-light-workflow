# Backlog

Outstanding work for the light workflow skills (`frame`, `review`, `close`, plus the pre-loop
recon skill `dev-audit`) and their deployment tooling. One line per item with a stable id so story
files, commits, and `reviews/<slug>.md` trails can reference it.

**Inflows:** items reach this staging area two ways — **hand-authored** here, or **graduated from a
`/dev-audit` run** as `AUDIT-` findings (only on an explicit instruction). Either way, once a line
is here it flows out the same path. **Lifecycle:** a line here → `/frame` writes
`reviews/<slug>.md` (spec + audit trail) → `/review` → `/close`. As part of the merge, `/close` moves the item to **Done** here
*on the feature branch*, so it rides in on the merge commit. (This repo keeps **no `CHANGELOG.md`** —
the `merge: <slug>` commit + the story file are the ship record; a hand-maintained changelog would be
a third, drifting copy. `/close` writes a changelog only in repos that keep one.)
The backlog is the staging area in front of the loop; don't delete a landed item — move it
to **Done** and reference it as `PR #N / merge: <slug>` (never a raw SHA — derive it with
`git log <base> --oneline --grep "^merge: <slug>"`). **No bookkeeping-only stories:** records
land with the story they describe; open a follow-up only for a real defect or a new decision,
never solely to reconcile a previous story's records.

Three kinds of item, tracked separately:
- **BUG-** — skill-behavior / workflow-correctness defects (change what the skills *do*).
- **OPS-** — deployment, drift, and tooling ergonomics (change how the skills are *shipped*).
- **AUDIT-** — findings graduated from a `/dev-audit` run (missing safeguards, best-practice gaps).
  Added only on an explicit instruction; the item text carries its `from /dev-audit <date>` provenance.

---

## Skill-behavior bugs

BUG-D1/D2/D3 were storied in [`workflow-skill-defects.story.md`](workflow-skill-defects.story.md)
and shipped together via PR #2 / `5225bdb`; see [Done](#done). BUG-4 shipped via PR #14 /
`0504e31`; BUG-5 was obviated by `drop-shipped-tag` (the `shipped/<slug>` tag it depended on
was removed); both in [Done](#done).

_(all shipped — see [Done](#done))_

## Deployment & tooling improvements

Not yet storied — smaller, may not each warrant a full `reviews/<slug>.md` story.

OPS-8 is tracked separately as a spawned task chip. Everything else here has resolved:
OPS-1/2/3 shipped (see [Done](#done)); OPS-6 was [decided against](#decided-against).

OPS-9 — Evaluate whether the workflow skills (`frame`, `review`, `close`, and `dev-audit`) need
any YAML frontmatter beyond the current `name` + `description` — e.g. `allowed-tools` to scope tool
permissions, or other recognized skill keys. As of 2026-06-12 all carry only
`name` + `description` (`dev-audit` followed the same convention when added); nothing is strictly
missing, so this is an evaluate-and-decide item, not a known gap. (Logged 2026-06-12 alongside BUG-4.)

OPS-11 — **Evaluate** a dedicated anti-pattern / weak-error-handling review pass ("option B"). Like
OPS-9 this is an **evaluate-and-decide** item, not committed work: the `antipattern-lens` story
([reviews/antipattern-lens.md](reviews/antipattern-lens.md)) deliberately took the cheap half —
naming hidden failure in `AGENTS.md` at both altitudes — and **parked** the dedicated pass pending
evidence. Recorded so the analysis survives and whoever picks it up doesn't rebuild the wrong shape:

- **Shape (if built).** An optional **parallel anti-pattern critic pass** — one focused prompt whose
  sole job is hunting anti-patterns / weak error handling. **A pass is not a backend:** the
  `reviewer: {codex, llm}` seam selects which backend runs the *existing* design/approach and
  correctness passes; this would be an *additional* pass and must not redefine what the `llm`
  **backend** means (that would give `reviewer: llm` two meanings and make dispatch, config, and
  artifacts ambiguous). When built it may *use* an llm **provider** — non-agentic, inherently
  read-only, cheap, schema-valid JSON natively — reusing the eventual `llm` context/schema harness
  rather than inventing parallel orchestration. Run it as an **independent critic, not a third
  sequential stage**: the multi-agent evidence (≈87% fewer false positives, ≈3× more real bugs) is a
  *parallel independent-critic* result, while the same literature finds sequential **handoffs hurt
  reliability** (Azure SRE built toward multi-agent specialization, then reversed course) at 4–220×
  the tokens. A chained third stage would pay B's cost and collect little of its upside.
- **Trigger (what makes it worth building).** **Observed dilution** — the correctness pass
  demonstrably missing hidden failure *because* it is already carrying spec-drift + edge cases +
  security + data-loss + business logic. Build on evidence, not on a hunch; the `AGENTS.md` bullets
  landed first precisely so there is something to measure.
- **Boundary (why the contract is not a lint config).** Only the **judgment** half — *does this
  design/diff hide failure?* — is reviewer work. The **mechanical** offenders (bare `except`, `any`,
  dead code, unused imports/vars) are caught deterministically, free, and with zero false positives
  by linters (Ruff `BLE001`/`E722`/`TRY`, ESLint `no-explicit-any`), which `/dev-audit` Table A
  already recommends per-ecosystem — and per the estate standard linters belong in **CI**, not the
  local gate. Do **not** grow `AGENTS.md` into a lint config: it is a *prompt*, and every line costs
  reviewer context on every run in every repo.

(Logged 2026-07-15 alongside `antipattern-lens`. Filed as `OPS-11` per the `OPS-9` evaluate-and-decide
precedent rather than a new `RFC-` prefix — a new prefix is a one-way door for a single parked idea,
while renaming one line is two-way. If a *second* parked enhancement appears, that is the signal to
revisit the taxonomy.)

OPS-12 — Run the external reviewers **independently in parallel** — **BEGUN (not done): first build
shipped, layer continuing.** Logged 2026-07-16 as a parked evaluate-and-decide idea (kin to
OPS-9 / OPS-11); on **2026-07-17** Thomas decided the shape (divided, not redundant) and the **first
lens shipped** — the hidden-failure critic, `merge: parallel-critic` (PR #32),
[reviews/parallel-critic.md](reviews/parallel-critic.md). **Still open** (why this stays out of Done):
further lenses (e.g. security, test-adequacy) and `llm`-backend source diversity remain unbuilt. It
**generalizes OPS-11's** "independent critic, not a sequential stage" from the single anti-pattern
pass to the whole reviewer layer, and OPS-11's parked anti-pattern critic becomes the **first
citizen** of the layer this stands up. Recorded so whoever builds it doesn't rebuild the wrong shape:

- **The fork — redundant vs divided (decided: divided).** Two ways to run critics in parallel on the
  same diff. *Redundant* = N critics asking the **same** question (correctness), reconciled by
  consensus — the reliability play (the ≈87%-fewer-false-positives / ≈3×-more-real-bugs multi-agent
  result). *Divided* = N critics each asking a **different** question (correctness ∥ hidden-failure ∥
  security ∥ test-adequacy) — the coverage play. Thomas chose **divided**: "reviewers that do
  *different* things." Both review the same diff; they differ in whether the critics **duplicate** or
  **partition** the question.
- **Divided dissolves the reconciliation problem** (this supersedes the original "needs a
  reconciliation design" worry, which was a *redundant*-shape problem). Under divided, findings
  **partition by concern**, so the decision menu just grows **sections** — one per lens — with no
  consensus vote. The only residual is **drop-near-duplicates by `file:line`+claim** when two lenses
  touch the same spot: a merge, not a vote. Provenance is **structural** — each critic owns its own
  schema and its own artifact (the standing rule below), so the artifact + labelled section already
  identify the lens; **no `lens`/`source` field** is needed (a field nothing outside those artifacts
  would read).
- **Does NOT depend on the `llm` backend** (correction to the original filing's "depends on ≥2 wired
  backends"). Divided parallelism rides on the **already-wired codex backend**: run `codex exec`
  **twice concurrently** with different prompts + different `--output-schema`. Different *roles*, same
  *backend* — buildable on what exists today. Wiring `llm` (OPS: the designated-second-source stub)
  is a **separate enhancement** that buys **source diversity** — a genuinely different model catching
  codex's blind spots — not a **precondition**.
- **Critics live *within* the correctness altitude — never across the approach→correctness gate.**
  That gate stays deliberately sequential (the short-circuit that stops the loop reviewing the lines
  of a doomed shape). Parallelize the critics *on* the correctness pass, not the two altitudes.
  Bonus: specialized critics fire only *after* the shape is blessed, so you never pay their tokens on
  a shape headed for redesign — the short-circuit economics survive.
- **The lenses** (the "different questions"), grounded in what the workflow already cares about
  (AGENTS.md guardrails, the anti-pattern lens, `/dev-audit` Table A): **correctness vs spec**
  (exists today), **hidden failure / weak error handling** (= OPS-11's parked pass — start here),
  **security / data-loss**, **test adequacy vs the ACs**. *Not* "simplicity / reinvention" — that is
  already the **approach** pass's job; do not duplicate it at the correctness altitude.
- **Minimal first build.** One specialized critic running concurrently with the existing correctness
  pass: same codex backend, its **own** prompt + **own** schema + **own** artifact
  (`reviews/<slug>.<lens>.json` beside `.codex.json`), surfaced as its **own section** in the step-9
  menu. **Standing rule (Thomas, 2026-07-17): every parallel critic henceforth creates its own finding
  json — its own schema and its own artifact** (no shared `finding-schema.json`, no `lens`/`source`
  field — separation is structural). Concurrency is **fail-closed**: each critic writes a fresh temp
  promoted only on {clean exit AND valid JSON}; either critic failing stops the round (no menu, no
  merge) — the added critic is *required*, never silently optional. Start the lens at **hidden-failure**
  (OPS-11 already did that design and named its trigger).
  **Build:** `reviews/parallel-critic.md` — hidden-failure lens, first citizen (branch
  `claude/parallel-critic`).
- **Cost vs. identity.** Divided is **N× tokens but ~1× wall-clock** (critics run concurrently) — so
  the cost to the loop's lightweight identity is **spend, not latency**. Weigh N× spend before
  growing the lens set; one lens at a time.
- **Trigger discipline (noted, and being consciously front-run).** OPS-11's rule was: build the
  dedicated pass on **observed dilution**, not a hunch. Thomas is choosing to stand up the
  **plumbing** ahead of that trigger — a deliberate product-owner call to de-risk the wiring and buy
  the capability early, accepting the N× spend against lightweight identity. The *which-lens-when*
  decision can still follow evidence once the seam exists.

(Logged 2026-07-16; shape decided + intent-to-build recorded 2026-07-17; **first build shipped
2026-07-17** — `merge: parallel-critic`, PR #32 — item marked **begun, not done**. Originally parked
at Thomas's request while `consult-presentation` was mid-flight; filed on clean `main`. **Taxonomy
note:** OPS-12 is the "second parked enhancement" whose arrival OPS-11 named as the signal to revisit
whether these enhancements deserve their own prefix — `OPS-` nominally means shipping/tooling
ergonomics, and both OPS-11/OPS-12 are reviewer-architecture ideas. That revisit is a **one-way
door** left for Thomas; both stay `OPS-` until he decides — and with OPS-12 now heading toward a
build, that call comes due sooner.)

OPS-13 — **Whole-app multi-lens audit** ("deep audit") — **shape decided (plan-then-execute fleet);
first slice in frame.** Logged 2026-07-19 from Thomas's concern that the review loop is
**diff-scoped**: both parallel critics judge only the newest changes, so judgment-level lenses never
sweep the whole app. Linters in CI cover the *mechanical* hidden-failure cases estate-wide; the
*judgment* cases in old/cold code have no coverage anywhere. Evaluate-and-decide kin of
OPS-9/11/12, with the engine chosen (2026-07-19) after a research pass on mid-2026 multi-agent
practice. Recorded so whoever builds it doesn't rebuild the wrong shape:

- **Complement, don't replace.** The review loop stays the cheap per-change gate (diff-scoped by
  design); this is the occasional deep sweep. Cadence is a **trigger table, not a calendar**:
  adopt/inherit a repo → full sweep; pre-major-release → L2/L3 + security; post-large-refactor →
  L2/L3; post-incident → the lens matching the incident class; otherwise a light periodic pass.
- **Steering interface (the told/suggest seam).** A declarative **audit-plan artifact** compiled by
  recon and approved at a consult before anything runs (the frame-consult pattern applied to audits).
  **Altitude ladder:** L0 lines · L1 units (per-file) · L2 subsystems (cross-file patterns) · L3
  application (systemic: authz coverage, data-flow, can-the-app-surface-its-own-failures).
  **Lens catalog:** each lens = prompt + **its own schema** (the OPS-12 standing per-critic rule,
  generalized) + the altitudes it applies at. **Suggestion matrix** (the Table-B pattern): detected
  profile signals → proposed lenses × altitudes × depth, each row carrying its *why*. "Told" =
  Thomas edits/overrides plan lines; "suggested" = the matrix output. Cost estimate shown before
  approval — the plan is the one-page thing he decides on, priced before it runs.
- **Engine: A-chassis with B/C growth paths.** Three engines weighed: **A** compiled-plan fleet
  (recon → approved plan → deterministic execution), **B** budgeted recursive descent (risk-weighted
  adaptive depth, spend-where-scary), **C** differential ledger (fingerprint-diff re-audits, durable
  dispositions). **Decision: build A**, borrowing B's risk-weighted depth *at plan time* (adaptive
  allocation without runtime nondeterminism) and stubbing C's artifact layout from day one (a
  two-way door). Revisit triggers: runs feel wasteful on boring code → add B's descent; re-run cost
  hurts at the chosen cadence → activate C on the stubbed ledger. **Rejected:** a single
  mega-context read (recreates at repo scale the dilution disease the parallel critics cure; one
  point of judgment, no independence) and flat swarms (see next bullet).
- **Verification is adversarial or it is theater (mid-2026 evidence).** Documented: 80+ agents
  *including dedicated adversarial reviewers* unanimously endorsed a **nonexistent** OpenSSL
  vulnerability — same-model panels echo-chamber (shared training distributions validate each
  other's hallucinations); consensus is not verification. And the human triage budget is the scarce
  resource: curl closed its bug bounty (confirmed rate <5% under AI submissions); HackerOne paused a
  program (2026-03). Therefore, regardless of engine: **kill-mandate verifiers** (their job is to
  destroy the finding), **context asymmetry** (the verifier reads the code fresh, never the finder's
  argument), **mechanical confirmation** wherever a claim is mechanically checkable, **small nested
  teams** (3–4 per team; hierarchical summarization as the repo-scale context substrate),
  **precision-first reporting** with explicit **coverage accounting** ("what was NOT covered").
  (Evidence: arXiv:2604.19049 Refute-or-Promote; arXiv:2607.01425 Agent4cs; arXiv:2501.18160
  RepoAudit.)
- **Upgrades the `llm`-backend rationale.** Cross-model critics are now an evidence-backed defense
  against echo-chamber false positives — wiring the `llm` backend (`review/SKILL.md`'s designated
  second source, still a loud stop; no standalone backlog item, noted here) graduates from
  nice-to-have source diversity to best practice once the audit's verify stage exists.
- **Posture invariants** (inherited from `/dev-audit` + OPS-12): read-only against the target,
  report-first, `AUDIT-` hand-off only on explicit instruction, fail-closed orchestration (the
  OPS-12 temp→validate→promote template), per-critic schema + artifact.
- **Build note.** The orchestration runtime (parallel fan-out, budgets, adversarial verify,
  completeness critic) already exists in the session harness's workflow engine — the build is the
  recon/plan compiler, the lens catalog, and prompts/schemas, not orchestration infrastructure.
  **First slice:** the recon → plan-artifact consult, standalone-valuable ("what would a
  comprehensive audit cost on this repo" as a one-page decision) — story `deep-audit-plan`, in frame.

(Logged 2026-07-19. **Taxonomy note:** a *third* reviewer-architecture evaluate-and-decide item under
`OPS-` — strengthens the OPS-11/OPS-12 signal that these may deserve their own prefix; that revisit
stays a **one-way door** left for Thomas.)

_(OPS-10 shipped — see [Done](#done).)_

---

## Done

| id | Summary | Shipped |
|---|---|---|
| OPS-4 | `/close`'s merge step raced GitHub's async mergeability computation (5×5s `mergeStateStatus` poll loop). Fixed: replaced with `gh pr merge --auto`, delegating merge timing to GitHub; added `allow_auto_merge` pre-flight and MERGED-state poll. | PR #6 / `499d6b6` |
| OPS-5 | `/close`'s auto-merge pre-flight aborted whenever `allow_auto_merge` was `false`, even with no required checks. Fixed: three-way merge strategy — auto-merge path when enabled, direct `gh pr merge` when disabled with no required checks, abort only when disabled *and* ≥1 required status check (detected via classic branch protection, degrading to zero on 403/404; rulesets out of scope). | PR #8 / `0406185` |
| OPS-5-fix | Follow-up to OPS-5: the new pre-flight's required-check detection didn't degrade to zero on a 403/404 — an inline `\|\| echo 0` appended to gh's error body, yielding a non-integer that broke the `-gt` test. Fixed: capture on gh success only via a separate-statement fallback, then sanitise to an integer. Surfaced by dogfooding the PR #8 merge. | PR #9 / `1278814` |
| OPS-10 | `/dev-audit` Table A had no Shell/Bash row, so shell-heavy repos (incl. this one) didn't get `shellcheck`/`shfmt` auto-selected. Fixed: added a Shell row (marker `*.sh`/shebang) with read-only invocations (`shellcheck`, `shfmt -d`). Surfaced by dogfooding `/dev-audit`; shipped with the `install.sh` SC2034 dead-var fix. Gate-wiring deferred to CI. | PR #23 / merge: shell-tooling |
| OPS-7 | `/frame` spec template had no guidance against counting files in test notes. Fixed: the `## Test notes` template now warns against restating file counts for scope-containment ACs and directs `git diff --name-only` against the AC's enumerated file list. | PR #8 / `0406185` |
| OPS-1 | No drift detection between repo `.claude` and the `~/.claude` deployment. Fixed: `install.sh --check` is a read-only per-artifact IN SYNC/DRIFT report across the deployed set, exits non-zero on drift. | PR #11 / `b18993e` |
| OPS-2 | No provenance stamp on deployed skills. Fixed: every install writes `~/.claude/workflow-manifest.json` (source commit, dirty flag, timestamp, artifact list); `--check` compares it to repo HEAD and classifies drift as STALE vs HAND-EDITED. | PR #11 / `b18993e` |
| OPS-3 | `install.sh` hard-overwrite was silent. Fixed: a normal install prints a pre-overwrite drift summary (warning when hand-edited artifacts are about to be lost) before clobbering; the hard-overwrite model is unchanged by design. | PR #11 / `b18993e` |
| review-codex-stdin | `/review`'s documented `codex exec` command had no stdin redirect, so codex blocked on stdin and hung the review. Fixed: appended `</dev/null` (+ a keep-it note). Same-session tooling fix, no OPS number. | PR #12 / `706171d` |
| BUG-D1 | `/close` pre-set `Status: merged` speculatively. Fixed (SSOT): header records declared state only (`approved` terminal, never `merged`); shipped state owned by git — authoritatively the merge commit / PR-MERGED, with a best-effort `shipped/<slug>` convenience tag, read back by deriving. | PR #2 / `5225bdb` |
| BUG-D2 | Merge-approval gate was squishy. Fixed: `/close` now states unambiguously that *invoking `/close` is NOT merge authorization* — a distinct in-session "merge" instruction is required after the fork. | PR #2 / `5225bdb` |
| BUG-D3 | Merge could fire without a distinct "merge" instruction (fork skipped). Fixed: the "re-review or merge?" fork is mandatory and non-skippable, even on a clean review with zero fixes. | PR #2 / `5225bdb` |
| BUG-4 | `/review`'s `codex exec` referenced the finding schema by a repo-relative path (`.claude/skills/review/finding-schema.json`) that only resolved from this repo, so `/review` aborted ("Failed to read output schema file … No such file or directory") from every other project repo. Fixed: absolute user-level `"$HOME/.claude/skills/review/finding-schema.json"`; `-o reviews/<slug>.codex.json` kept repo-relative, with a step-5 note on the asymmetry. Also logged OPS-9. | PR #14 / `0504e31` |
| BUG-5 | The guard hook blocked the `shipped/<slug>` **tag** push during `/close` (it keys on "on a base branch?" not "is the refspec a base branch?"), since `gh pr merge --delete-branch` leaves HEAD on `main`. **Obviated by design** rather than fixed: `drop-shipped-tag` removed the tag entirely (the merge commit / PR-`MERGED` is the single ship record), so nothing pushes from `main` and the guard is never engaged — no guard change. The earlier smarter-guard fix (`guard-allow-tag-push`) was abandoned (PR #16 closed unmerged). | PR #17 / `merge: drop-shipped-tag` |

Shipped together as the `close-gate-and-backlog` story ([reviews/close-gate-and-backlog.md](reviews/close-gate-and-backlog.md)); also added the declared-vs-observed doctrine, the `shipped/<slug>` tag convention, and the `/review` decision-menu consistency tweak.

OPS-5 and OPS-7 shipped together as the `ops5-ops7-ergonomics` story ([reviews/ops5-ops7-ergonomics.md](reviews/ops5-ops7-ergonomics.md)); the OPS-5-fix follow-up as `ops5-reqchecks-fallback` ([reviews/ops5-reqchecks-fallback.md](reviews/ops5-reqchecks-fallback.md)) — a same-session bug surfaced by dogfooding the PR #8 merge.

OPS-1/2/3 shipped together as the `install-drift-check` story ([reviews/install-drift-check.md](reviews/install-drift-check.md)); the `review-codex-stdin` fix ([reviews/review-codex-stdin.md](reviews/review-codex-stdin.md)) — a same-session fix to a `/review` codex stdin hang surfaced while reviewing `install-drift-check`.

BUG-4 shipped as the `review-schema-abs-path` story ([reviews/review-schema-abs-path.md](reviews/review-schema-abs-path.md)) — the next defect in the same `codex exec` block as `review-codex-stdin`; also logged OPS-9. Closing its PR surfaced BUG-5 (open above).

---

## Decided against

Items considered and deliberately not done (kept here, not deleted, so the reasoning survives).

| id | Summary | Decided |
|---|---|---|
| OPS-6 | Harden the guard hook (read `baseBranch` from `workflow.json` + catch push refspecs; catch `env git` / `nice git` wrapper-prefix bypasses; soften docs). | 2026-06-08 |

**Why not (OPS-6):**
- The guard hook is a **cooperative** client-side guardrail, not an adversarial sandbox — it's bypassable by editing `settings.json` regardless. Chasing exotic bypasses (`env git` / `nice git` wrapper prefixes) is a category error: you can't harden a cooperative guard into a server-side wall.
- It does **not** duplicate GitHub branch protection — different layer (local/pre-emptive vs server/authoritative), and branch protection is unavailable on a free private repo anyway, so there's nothing to "step on."
- The one genuinely real sub-bug — base branch hardcoded to `main`/`master`, so a repo on a non-`main` base gets no protection even though `workflow.json` already declares `baseBranch` — is **not load-bearing** for this solo, `main`-based setup. **Deferred-until-needed:** revisit only if a non-`main` base is ever adopted.
- **Docs sub-part shipped** (PR #20 / `merge: honest-system-docs`): the "soften docs" half of OPS-6 was delivered separately — the README, hook comment, live protocol, and skill parentheticals now honestly describe the guard as a cooperative `main`/`master` tripwire and name the categories it doesn't catch. The **hardening** half (read `baseBranch`, catch refspecs/`env`/nested-shell) remains decided-against per the reasoning above.
