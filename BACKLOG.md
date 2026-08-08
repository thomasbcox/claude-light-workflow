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

Four kinds of item, tracked separately:
- **BUG-** — skill-behavior / workflow-correctness defects (change what the skills *do*).
- **OPS-** — deployment, drift, and tooling ergonomics (change how the skills are *shipped*).
- **AUDIT-** — findings graduated from a `/dev-audit` run (missing safeguards, best-practice gaps).
  Added only on an explicit instruction; the item text carries its `from /dev-audit <date>` provenance.
- **AAR-** — *After Action Review*: a workflow lesson proposed by `/close` after a safeguard
  activation and **approved by Thomas**. Added only through that path — never hand-filed, never
  self-approved. An unapproved proposal is not an item; a rejected one goes to
  `.aar/rejected-lessons.md` with its reason, not here. Prefix decided 2026-08-06 (`lesson-proposals`)
  as a one-way door: every future lesson item copies it.

---

## Skill-behavior bugs

BUG-D1/D2/D3 were storied in [`workflow-skill-defects.story.md`](workflow-skill-defects.story.md)
and shipped together via PR #2 / `5225bdb`; see [Done](#done). BUG-4 shipped via PR #14 /
`0504e31`; BUG-5 was obviated by `drop-shipped-tag` (the `shipped/<slug>` tag it depended on
was removed); both in [Done](#done).

BUG-6 and BUG-7 were both filed 2026-08-04 from `fireworks-reviewer-backend`'s two
flagged-but-unfixed items — one observed during implementation and deliberately not carried, one an
approach-review BLOCKER accepted with the claim corrected rather than the window closed.
**BUG-6 shipped** via PR #49 / `merge: route-design-hidden-failure`; see [Done](#done). **BUG-7
remains open.** The original BUG-6 analysis is retained below as the design record — the shipped fix
took candidates (a) and (b) together, and (c)'s open question (whether the codex path, which
schema-checks nothing locally, needs gate-time structural pins) was **not** closed by it.

BUG-6 *(SHIPPED — retained as the design record)* — **Schema validation is vacuous if the schema
file is well-formed JSON but not a real schema.** From that story's "Observed, not fixed" note
([reviews/fireworks-reviewer-backend.md](reviews/fireworks-reviewer-backend.md)). JSON Schema treats
unrecognised keywords as **no-ops**, so a file that parses as JSON but declares no real constraints
validates **anything** — including the empty object — and the runner promotes the result as a clean
review.

- **How it surfaced (not theory).** Writing the AC-2 schema test: substituting one valid JSON file for
  another **did not fail**. The check meant to prove validation is live passed against a schema that
  constrains nothing.
- **Both enforcement layers share one input, so they fail together.** The runner's defense reads as
  two independent layers — the API-side `response_format: json_schema` grammar constraint and the
  local `jsonschema.validate` — but `run_pass` reads the schema file once and hands the *same dict* to
  both. A meaningless schema disables both at once.
- **The codex path has less defense and shares the same files.** `review/SKILL.md`'s `promote()` gates
  on {clean exit AND `jq -e .`} — **parseable**, never schema-checked — relying entirely on
  `codex exec --output-schema` fed from the same skill-local schema files. A fix has to decide whether
  it covers that path or only the runner.
- **It is the failure shape that motivated the whole backend.** An abnormal condition yielding a
  schema-valid artifact that reads as a clean review — same shape as the `{}` promotion and the
  `content_filter` gap, both fixed in that story. This is the instance left standing.
- **Candidate fixes (evaluate) — and the trap in the obvious one.** (a) **Meta-validate at load** —
  the library's `check_schema` on each schema before use. Cheap and worth having, but **necessary,
  not sufficient**: it catches a file that is illegal *as a schema*, and misses the case actually
  observed, because a foreign JSON document (say the routing table) is a *legal* schema whose
  keywords are simply unrecognised. (b) **Prove the schema bites** — validate a known-bad instance
  against it at load or in the gate and fail closed if that instance *passes*; the empty object is the
  natural probe, since all three schemas carry a non-empty `required` and must reject it. This is the
  check that closes the observed hole. (c) **Gate-time structural pins** per schema file, which also
  covers the codex path — nothing there validates locally at all. Lean: (b) first, (a) alongside it,
  (c) if the codex path is in scope.
- **Reach.** Every schema the runner loads (design, approach, correctness, hidden-failure), and every
  future critic added to the altitude.

(Logged 2026-08-04. Filed `BUG-` per the taxonomy above: it changes what `/review` *does* — its
fail-closed guarantee has a hole — not how the skills are shipped.)

BUG-7 — **A review round is not published atomically: per-file renames, no round transaction.** The
deferred half of the approach BLOCKER Thomas accepted 2026-08-03
([reviews/fireworks-reviewer-backend.md](reviews/fireworks-reviewer-backend.md)). **Accepted meant
the overclaim was corrected, not that the window was closed** — AC-5, `review/SKILL.md` step 8, and
the runner's `promote()` docstring now state the true guarantee and name the residual window. This
item owns closing it.

- **The window.** Publication is a sequence of same-directory renames, one per artifact — atomic *per
  file*, so no reader ever sees a partial artifact, but not one transaction across files. A process
  killed between two renames leaves one artifact new and one stale, and nothing ties a round's files
  together, so step 9's decision menu reads the mixed set as a single round. Narrow (the interval
  between two renames) and silent when it happens.
- **What is already guaranteed, and stays.** A failed review publishes nothing: every pass must
  validate, then every payload is written and fsynced to a temp beside its destination, and only then
  are renames performed; staging failures clean up and promote nothing. The gap is only the
  killed-between-renames case.
- **It spans both backends — fixing one leaves the invariant half-true.** The `codex` path's two
  sequential `mv`s share the identical window; the runner's `os.replace` loop is the same shape in
  Python. That shared exposure is why it was deferred out of a fireworks-only change.
- **The shape codex proposed.** Write every result into one immutable, round-specific directory,
  fsync it, then publish with a single atomic directory rename or a current-round pointer; consumers
  resolve artifacts only through that committed reference — one commit point instead of a
  probabilistic sequence.
- **What it costs (why it is a story, not a patch).** It changes the **artifact contract**
  (`reviews/<slug>.<pass>.json`) and therefore every consumer: both backends' invocations, the step-9
  menu, the drift-linted command blocks pinned in `reviewer_test.sh`, and the story trail's naming
  convention. Anything reading those files by stable name has to learn the pointer.
- **It grows with the critic layer.** OPS-12's standing rule — every parallel critic gets its own
  schema and its own artifact — means more files per round, so more renames per commit point and more
  consumers to migrate. Every critic added before this is fixed copies the pattern.

(Logged 2026-08-04. Filed `BUG-` rather than `OPS-`: a workflow-correctness defect in what `/review`
publishes, not shipping ergonomics — though it is kin to the OPS-11…OPS-18 reviewer-architecture
line, whose prefix question stays a one-way door left for Thomas.)

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
  <!-- Terminology note (2026-08-03): the `llm` backend name was retired and replaced by
  `fireworks` when the second source was actually wired — see reviews/fireworks-reviewer-backend.md.
  Read `llm` below as "the non-agentic second backend". The distinction this bullet draws (a pass is
  not a backend) is unaffected. -->
  
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
- **Upgrades the second-backend rationale — SINCE DELIVERED, see note below.** Cross-model critics
  are now an evidence-backed defense against echo-chamber false positives — wiring the second
  backend (`review/SKILL.md`'s designated second source, then a loud stop; no standalone backlog
  item, noted here) graduates from
  nice-to-have source diversity to best practice once the audit's verify stage exists.
  **Delivered 2026-08-03, independently of that condition** — the audit engine was retired (above)
  while the second backend shipped anyway, as `fireworks`, wired at the correctness altitude:
  story [reviews/fireworks-reviewer-backend.md](reviews/fireworks-reviewer-backend.md). The `llm`
  name was retired with it. The cross-model rationale in this bullet is what justified it; the
  audit-engine precondition turned out not to be one. Design and approach altitudes remain on
  `codex` pending a follow-up story.
- **Posture invariants** (inherited from `/dev-audit` + OPS-12): read-only against the target,
  report-first, `AUDIT-` hand-off only on explicit instruction, fail-closed orchestration (the
  OPS-12 temp→validate→promote template), per-critic schema + artifact.
- **Build note.** The orchestration runtime (parallel fan-out, budgets, adversarial verify,
  completeness critic) already exists in the session harness's workflow engine — the build is the
  recon/plan compiler, the lens catalog, and prompts/schemas, not orchestration infrastructure.
  **First slice: SHIPPED** — the recon → plan-artifact consult (`/deep-audit`, plan stage only),
  standalone-valuable ("what would a comprehensive audit cost on this repo" as a one-page decision) —
  story [reviews/deep-audit-plan.md](reviews/deep-audit-plan.md), `PR #35 / merge: deep-audit-plan`.
  **Engine slice: RETIRED 2026-08-03.** The execution-engine work and its supporting library were
  stood down rather than finished. Nothing is lost — both are preserved as annotated tags and can be
  read or resurrected at any time: `retired/deep-audit-engine` (`a0131b1`, parked 2026-07-27 when the
  work was re-sequenced lib-first) and `retired/deep-audit-lib` (`7574a05`, the stdlib-only Python
  port, 2026-07-31). Recover with `git show retired/deep-audit-engine` or branch from either tag.

  **Plan slice: RETIRED 2026-08-04** (superseding the "what survives and still ships" position held
  for one day). The plan stage — the `/deep-audit` skill, its `plan-schema.json`, and
  `tests/deep_audit_plan_test.sh` — is stood down by the `thin-the-loop` story
  ([reviews/thin-the-loop.md](reviews/thin-the-loop.md)). It had been kept on the argument that it
  was standalone-valuable ("what would a comprehensive audit cost on this repo" as a one-page
  decision). With the engine retired the day before, that value did not survive contact: a priced
  plan for an audit nothing can run is a costed quote for a service that no longer exists, and it
  cost 258 skill lines (the largest in the repo) plus 97 gate checks to keep. Preserved as annotated
  tag `retired/deep-audit-plan`. Recover with `git show retired/deep-audit-plan` or branch from it.

  **All three tags, one place:** `retired/deep-audit-engine` (`a0131b1`), `retired/deep-audit-lib`
  (`7574a05`), `retired/deep-audit-plan` (`6606b88`). Nothing about OPS-13 is lost; it is unbuilt,
  not unrecorded. The ROADMAP's core/plugin/park question is answered by this: **parked**.

  **OPS-13 status: closed, retired in full.** Every slice is now stood down and tagged. It is recorded here rather than moved to Done because Done means shipped,
  and half of this did not. Reopening means a fresh story — the deferred ACs below are the
  starting point, not a live commitment.

  **Engine-slice opening ACs — historical, deferred to a retired slice** (from the first slice's
  round-3 review, Thomas 2026-07-19). Retained as the design record for anyone resurrecting the
  tags; no longer owed by any open item: (a) patch-phase structural ops — dedicated `exclude-files`/`only-files` union
  branches, selector `remove`/`restrict` reserved for compiled rows; (b) the full executability
  semantic gate — a scope registry incl. L2/L3 membership, structural pricing constants, and
  full-arithmetic checks (`unitIds` ≡ registry, `estTokens` = runs × constant, wall-clock formula) —
  the executor build decides which checks earn their place; and (c) **source-identity verification**
  (deferred from the first slice's round-4 review, Thomas 2026-07-19) — the plan records
  `source {revision, dirty, evaluatedAt}`, but the engine owns the *check*: recompute a content
  fingerprint of the audited file set **excluding generated plan/review artifacts** (so an in-repo
  plan commit doesn't self-invalidate the bound revision), uniquely identify a dirty tree, and
  fail closed on mismatch. `planVersion` 1 has no consumers yet, so the engine story may extend the
  contract in place.

(Logged 2026-07-19. **Taxonomy note:** a *third* reviewer-architecture evaluate-and-decide item under
`OPS-` — strengthens the OPS-11/OPS-12 signal that these may deserve their own prefix; that revisit
stays a **one-way door** left for Thomas.)

OPS-14 — **Make a user story the focus of every cycle.** Filed 2026-07-21 at Thomas's request as a
**future need**; evaluate-and-decide (kin to OPS-9/11/12/13), not committed work. Today `/frame`
produces a spec whose `## Problem` and acceptance criteria are framed in **mechanism** — what gets
built — with no required statement of **who benefits and how**. The proposal: every cycle centers on
a **user story** (the "as a ⟨role⟩, I want ⟨capability⟩, so that ⟨benefit⟩" unit), and the technical
spec hangs off it rather than standing alone.

- **Why it may matter (evidence from this session, not theory).** `deep-audit-plan` took **five
  approach rounds**, three of which were scope arguments about how deep the plan-stage contract
  should go before the engine exists. Each round's finding was individually valid; what was missing
  was a **shared yardstick** for "is this needed *yet*." A user story supplies one: a finding either
  blocks the stated user benefit or it does not. Thomas resolved those rounds by hand, ruling
  fix-vs-defer four separate times — exactly the adjudication a user story would make cheaper and
  more consistent.
- **Likely shape (if built).** `/frame` step 5 requires a user-story line before the ACs; each AC
  traces to it; the `/review` consult weighs findings against the stated benefit (a finding that
  doesn't threaten it is a candidate defer); `/close` records whether the benefit shipped. The
  reviewer contract (`AGENTS.md`) may need a line so the approach pass judges shape **against the
  user story**, not against an unbounded notion of completeness.
- **Tensions to resolve before building.** (1) Much of this repo's work is **tooling for Thomas
  himself** — the "role" is often *him*, which can make the ceremony feel hollow; the item should
  decide whether user stories apply to all cycles or only user-facing ones. (2) A user story is a
  *prompt*, and every required line costs context on every run (the OPS-11 every-line-costs lesson).
  (3) It changes the story-file template, which every past `reviews/*.md` follows — decide whether
  existing stories stay as-is (they should; no retro-fitting).

(Logged 2026-07-21. **Taxonomy note:** a *fourth* evaluate-and-decide workflow/architecture item
under `OPS-`, and the first that is about the loop's **unit of work** rather than its reviewer layer
— `OPS-` nominally means shipping/tooling ergonomics. The prefix revisit OPS-11 first flagged, and
OPS-12/OPS-13 each strengthened, now has a fourth data point. Still a **one-way door** left for
Thomas.)

OPS-15 — **Treat skill/prompt instructions as a first-class "code" ecosystem for auditing.** Filed
2026-07-23 at Thomas's request during `deep-audit-plan`'s round-7 review; evaluate-and-decide (kin to
OPS-9/11/12/13/14), not committed work. Today `/dev-audit` detection (and, by reference,
`/deep-audit`) treats Markdown as **docs**, not code. That is fine for most repos but **wrong for
this estate**, whose real product is Markdown **skill instructions** (`.claude/skills/*/SKILL.md`,
`AGENTS.md`, `workflow-protocol.md`) — the thing seven rounds of this very review spent their effort
scrutinising. Under `/deep-audit`'s unit-granularity classification (R7-F1), those files sort as
non-code and drop out of L1 critic scheduling, so a deep-audit of *this* repo would examine its shell
files and skip its actual logic.

- **The tension to resolve.** "Prompt instructions are code" is true **here** but not universally — a
  random repo's `README.md` is genuinely docs. So this is not "reclassify Markdown globally"; it is
  "**a repo may declare that certain prompt/instruction files are auditable code**." Likely shapes:
  (a) a per-repo config marker (e.g. a `deep-audit`/`dev-audit` setting listing prompt-code globs);
  (b) a new detection signal keyed on `.claude/skills/**` + agent-instruction filenames; (c) rely on
  the existing `only=<glob>` override each run (cheapest, but re-typed every time and easy to forget).
- **Interacts with OPS-11's boundary.** A prompt-code lens is *judgment* work (does this instruction
  hide failure, contradict itself, drift from the contract?), not mechanical lint — consistent with
  OPS-11's judgment/mechanical split. It also composes with OPS-13's lens catalog: "prompt-coherence"
  could be a lens, or hidden-failure/test-adequacy could simply apply to prompt-code units once they
  classify as code.
- **Provenance.** Surfaced concretely: `deep-audit-plan`'s smoke plan, after R7-F1, prices this repo
  at ~18 L1 runs over its 3 shell files — correct by the rule, but it skips every `SKILL.md`. That
  gap is the evidence this item exists to close.

(Logged 2026-07-23. A **fifth** evaluate-and-decide item under `OPS-`; the prefix-revisit question
OPS-11 opened keeps accruing data points — still a one-way door left for Thomas.)

OPS-16 — **SHIPPED** via PR #49 / `merge: route-design-hidden-failure` (see [Done](#done)); the
analysis below is retained as the design record, and the shipped fix took candidate **(a)**, the
doctrine exemption, as the item leaned. **Scope-containment ACs keep breaking on the loop's own
review-trail artifacts.** Filed
2026-07-23 at Thomas's request as a recurring, estate-wide papercut; evaluate-and-decide. **The
bug:** `/frame` step 6 writes `reviews/<slug>.design.json` and step 8 commits it *with the spec* —
before implementation starts; `/review` then writes `.approach.json` and `.codex.json`. But frame's
scope-AC guidance (step 5 test-notes) only warns against file **counts** and says "enumerate the
allowed files" — it **never tells the author to include the workflow's own review-trail artifacts**
in that enumeration. So an author enumerates their *product* files, and the loop's own `.design.json`
becomes the **N+1** that fails the scope-containment AC — a defect the workflow inflicts on itself.

- **Not hypothetical — documented recurrence.** `antipattern-lens` had to **amend its AC7 "to exempt
  the workflow-generated review" artifacts** (see that story's round-2 review). `deep-audit-plan`
  pre-empted it by writing AC10 as "…and files under `reviews/`". Thomas reports hitting it
  **across individual projects** — and since `/frame` is deployed estate-wide by `install.sh`, the
  gap ships to every repo.
- **Why `.design.json` is the worst offender.** It is created and committed at **frame time**, long
  before the author is thinking about the eventual diff — so it is the artifact most reliably
  forgotten when the scope AC is written. `.approach.json` / `.codex.json` compound it each review
  round.
- **Candidate fixes (evaluate).** (a) **Doctrine exemption** — codify in `workflow-protocol.md` +
  frame's step-5 guidance that scope-containment ACs **categorically exempt** the review trail
  (`reviews/<slug>.*` is workflow bookkeeping, never the change's product), so the scope check reads
  "no *non-review-trail* file beyond those enumerated" and **no story ever enumerates them**.
  (b) **Guidance-only** — frame prompts the author to always append "and files under `reviews/`" to
  the enumeration (lighter; relies on memory each time). (c) **A canned scope-check incantation**
  that excludes `reviews/` (e.g. `git diff --name-only <base>...HEAD -- . ':(exclude)reviews/'`).
  Lean: (a) — the review trail is *definitionally* not the product, so the exemption belongs in
  doctrine once, not in every story's AC.
- **Boundary.** Scope-containment ACs exist to catch **unintended product-file sprawl**; the fix must
  exempt only the workflow's **own** artifacts, not weaken the check for product files. `reviews/`
  holds only workflow artifacts, so exempting the whole directory is safe.

(Logged 2026-07-23. A concrete **recurring defect** in frame's guidance rather than a parked
enhancement — filed `OPS-` as workflow-tooling ergonomics, estate-wide via `install.sh`. A **sixth**
`OPS-` workflow item; the prefix-revisit question OPS-11 opened keeps accruing data points.)

OPS-18 — **/review-side falsification companion**: the reviewer proposes mutations for test-bearing
stories at review time, complementing the frame-side plan (spec-time, criterion-derived, executed as
step-9 demonstrate-red — shipped via `reviews/frame-falsification-plan.md`). Filed 2026-08-02 as
that story's declared non-goal; not committed work.

  **The amendment-log duty attached here is DISCHARGED, not owed** (2026-08-04). OPS-18 formerly
  also owned review of the `## Falsification-plan amendments` log, handed over by
  `falsification-surface-rows` (2026-08-03) because retractions exist only after step 9 and no
  frame-time review can see them. `thin-the-loop` deleted the log itself
  ([reviews/thin-the-loop.md](reviews/thin-the-loop.md)), so there is nothing left to review. What
  remains of OPS-18 is only its original idea: reviewer-proposed mutations at review time. The
  frame-side discipline it complements is now just demonstrate-red.

OPS-19 — **SHIPPED** via PR #49 / `merge: route-design-hidden-failure` (see [Done](#done)) — taken
while the runner was open for BUG-6, exactly as this item directed. Retained as the design record.
**`fireworks_runner.py` writes artifacts without a trailing newline.** Cosmetic and
runner-wide: every `reviews/<slug>.{approach,codex,hidden-failure}.json` the fireworks backend
promotes ends at `}` with no final newline, unlike the repo's hand-maintained JSON
(`workflow.json`, the schemas). Logged 2026-08-04 from a `thin-the-loop` correctness NIT, rejected
there for two reasons that still hold for any story that isn't about the runner: `/review`'s hard
constraint forbids editing reviewer output, so the artifact cannot be fixed after the fact, and the
fix belongs in the writer. Pre-existing, not introduced by that story. **Fix when the runner is next
open** — one `write` call — rather than as a story of its own; a bookkeeping-only story is against
doctrine. Recorded so it stops being re-raised as a NIT every round.

OPS-20 — **Break the single-head coupling between a change and the tests that judge it.**
**Priority: HIGH (Thomas, 2026-08-04.)** Filed from an analysis Thomas lifted from another repo (a
TypeScript/React codebase) and asked to be *interpreted* for this one, not transplanted. **The root
cause as stated there holds verbatim here:** the regression list and the tests come from the same
head at the same time, so a test can be confidently wrong in exactly the way the change is wrong,
and nothing in the loop notices.

- **Evidence from this repo, not theory — three instances, two of them from the session that filed
  this.** (1) `tests/reviewer_test.sh`'s `resolve()` is a **test-local Python reimplementation** of
  the reviewer-resolution rule whose only authoritative statement is **prose** in
  `review/SKILL.md` (→ *Reviewer backend*). The check proves the shim agrees with the expectations
  beside it; **nothing ties either to the skill**, because nothing executes prose. Shim and
  expectations were written together, by one head. (2) During `route-design-hidden-failure`, two
  assertions were judged wrong and rewritten **by the same head that made the change they were
  failing** — `table model reaches the request` and `each pass binds a distinct schema`. Both
  rewrites look correct on inspection; that is precisely the problem, since the same inspection
  produced them. (3) BUG-6's fix was demonstrated red **against a mutation its own author chose**
  (disable the probe) — the strongest verification the loop currently offers, and still
  self-selected.
- **Scope this ESTATE-WIDE, not to this repo (Thomas, 2026-08-04 — a correction to the first
  filing).** `/frame`, `/review`, `/close` and `/dev-audit` ship globally via `install.sh` to every
  project, across many languages and stacks. So the question is **not** "which of the four bite in
  `claude-light-workflow`" — that is a parochial test that would rank them by this repo's Python and
  Markdown mix and get the answer wrong. The question is **what the loop can mandate or support in
  an arbitrary repo whose language it does not know in advance.** That splits the four cleanly:
- **Tier 1 — loop-level, language-neutral, ships in the skills.** Options **3 and 4** are *process
  and doctrine*: they contain no tool, no dependency, and no syntax, so they behave identically in
  TypeScript, Go, Rust, Java, SQL or shell. They are stated once here and every repo inherits them.
  This is the tier that earns work first, because its cost is paid once and its reach is total.
- **Tier 2 — per-ecosystem, belongs in `/dev-audit` Table A.** Options **1 and 2** are *tool
  categories* with a mature implementation per ecosystem, exactly like the linters Table A already
  routes. They cannot be mandated globally (the loop cannot know the target's stack), but they can
  be **detected and recommended** by the existing recon step — the pattern Table A was built for.
- **Option 3 — adversarial-first falsification (Tier 1; the recommendation).** Invert who writes the
  regression list: the independent reviewer generates it **from the spec, at frame time, before any
  test is written**, and the author writes tests against *its* list. Attacks the root cause at the
  source rather than mitigating it downstream. **Why it is first under estate framing:** (a) the
  reviewer reads the **spec**, not the code's syntax, so it is the *only* one of the four that works
  unchanged in a language nobody anticipated — including repos with no test framework at all; (b) it
  is the only one that reaches product **no executable test can reach**, and every repo has some:
  config, IaC, SQL migrations, CI YAML, prompt files, docs-as-contract. A second reader is the only
  oracle prose has, in any language; (c) it is a re-sequenced, sharper **OPS-18**, which today
  proposes reviewer mutations at *review* time — too late, since the tests already exist by then and
  anchor the reviewer's thinking; (d) it answers the objection that **retired the frame-side
  falsification plan** in `thin-the-loop` ("an optional discipline in a solo repo is one you either
  always write from habit or never write") — that plan was cut because it came from the same head,
  and sourcing it from the reviewer is the version that survives its own critique; (e) the machinery
  **already exists** — the design review runs at `/frame` step 6, so this is one added schema and
  one added ask on a call already being made. **Cost:** one reviewer call's tokens at frame time, a
  new schema, and frame step 5 gains a dependency on step 6's output (ordering change) — paid in
  every repo, every story. **Risk:** it re-grows `/frame`, which `thin-the-loop` deliberately
  thinned, and that weight lands estate-wide; it must land as a **replacement** for author-written
  regression lists, not an addition alongside them, or every repo pays twice.
- **Option 4 — computed extents (Tier 1).** Where a criterion quantifies ("every deployed skill",
  "each pass", "both directions × both keys", "every user"), the test derives the cross-product **in
  code from the real source list** instead of the author retyping members. Language-neutral as a
  **doctrine line in `/frame`'s test-notes guidance** — every language can iterate a list, so the
  rule ships once and applies everywhere. **Cost:** near zero; no dependency, no runtime, available
  immediately; one more line of always-loaded `/frame` guidance (the OPS-11 every-line-costs
  lesson). **Risk:** an extent derived from the *same* source the code reads can be vacuously true —
  BUG-6's lesson applied to test construction, and the guidance must say so. **Precedent, not
  invention:** this repo already does it in two places (`docs_test.sh` parses `install.sh`'s
  `ARTIFACTS` block rather than listing skills; the BUG-6 suite loops `PASSES`/`ALTITUDES`), and
  violates it in one (`reviewer_test.sh` hand-enumerates resolver cases). That is local evidence the
  rule is followable and forgettable — the case for writing it down, not a reason to scope it here.
- **Option 2 — mutation testing (Tier 2).** The framing that earns it: it is **demonstrate-red,
  exhaustive and not chosen by the author** — a generalization of a discipline the loop *already
  mandates* (`frame` step 9), not a new idea to sell. Mature per ecosystem, so it routes through
  Table A like any linter: **Stryker** (JS/TS), **mutmut** / **cosmic-ray** (Python), **PIT** (JVM),
  **cargo-mutants** (Rust), **go-mutesting** (Go), **Stryker.NET** (C#), **infection** (PHP).
  **Cost:** reruns the whole suite once per mutant — hundreds of runs. Per the estate standard
  (dependencies belong in **CI**, never the local gate, which stays dependency-light) *and* its
  runtime, this is a **scheduled** CI job, not a PR gate — the pattern
  `.github/workflows/scheduled.yml` already establishes here. **Risk:** equivalent-mutant noise, and
  a green mutation score reading as "well tested" while the untestable fraction of the repo stays
  unmeasured — which is why it complements option 3 rather than substituting for it.
- **Option 1 — property-based testing (Tier 2, behind a detection signal).** Also mature per
  ecosystem — **fast-check** (JS/TS), **Hypothesis** (Python), **proptest**/**quickcheck** (Rust),
  **jqwik** (JVM), **gopter** (Go), **FsCheck** (.NET). Its payoff depends on something the loop
  cannot assume: whether the target repo **has a pure, total core** worth generating against. A
  roster/filter/sort layer is ideal; a thin I/O shell is not. That makes it a `/dev-audit`
  **detection signal → recommendation**, never a global mandate: recommend it where recon finds a
  substantial pure-function surface, stay quiet elsewhere. **Cost:** a dependency plus a genuinely
  different way of thinking, per repo that adopts it. **Risk (general, not local):** aiming a
  generator at a test that **reimplements** the rule it checks hardens the reimplementation and
  proves nothing about what ships — see the hazard below.
- **A cross-language hazard this repo happens to exemplify: tests that reimplement the rule they
  test.** `tests/reviewer_test.sh`'s `resolve()` is a test-local reimplementation of a rule stated
  authoritatively only as **prose** in `review/SKILL.md`. This is not a Python or a Markdown problem
  — it is the classic "test doubles the implementation" antipattern, reachable in every language,
  and it is *invisible* to options 1, 2 and 4 (all three would faithfully exercise the double).
  Option 3 catches it, because a reviewer working from the spec asks what proves the **shipped rule**
  says this. Worth stating in whatever guidance lands, and worth fixing here: giving that rule **one
  executable home** both the skill and the tests defer to is a prerequisite for ever pointing a
  generator at it — but it means the loop's most doctrinal rule stops being prose, a shape change to
  how skills express behavior. Named, not assumed.
- **Lean: 3 first, 4 alongside it (both Tier 1, both ship everywhere), then 2 and 1 as Table A
  recommendations gated on recon.** 3 is the only option that works in an unknown language and the
  only one that reaches untestable product; 4 is nearly free and pure doctrine; 2 and 1 are real but
  are per-repo tooling decisions the loop should *inform*, not impose.

(Logged 2026-08-04; **re-scoped estate-wide the same day** after Thomas corrected a first filing
that had ranked the four options by *this* repo's language mix — the tiering above replaces that
reasoning. An **eighth** evaluate-and-decide workflow/architecture item under `OPS-`, and the second
about the loop's **verification discipline** rather than its reviewer layer. The prefix-revisit
question OPS-11 opened keeps accruing data points — still a **one-way door** left for Thomas.
**Interacts with:** OPS-18 (option 3 re-sequences it — resolve them together, not separately),
OPS-15 (Tier 2 lands as Table A rows, the same table that item wants to teach about prompt-code),
OPS-17 (single-sourcing; the reimplementation hazard is the same disease), and `thin-the-loop`'s
retired falsification plan. **Estate note:** any Tier 1 change ships to every repo through
`install.sh`, so its instruction weight is paid on every invocation everywhere — the standing
tension the ROADMAP names as *reach* vs. the *lightweight* identity.)

OPS-21 — **SHIPPED** via PR #52 / `merge: user-level-contract` (see [Done](#done)) — **its premise
no longer exists**; the analysis below is retained as the design record. The one file
serving two jobs is gone: the shared contract was renamed to `workflow-AGENTS.md` and deploys to
`~/.claude/workflow-AGENTS.md`, so `AGENTS.md` in *every* repo — including this one — now means
repo-specific additions and nothing else. Both options this item weighed (B: decouple the template;
B′: an `AGENTS.local.md` addendum) were superseded: neither is needed once the shared contract is
never copied. Retained below as the design record.

**`AGENTS.md` is both this repo's reviewer contract and the template every other repo
starts from; give this repo a way to say something repo-specific.** Filed 2026-08-05 from
`estate-reach-guardrails`'s design review (Thomas: *"backlog B and B-prime for future
consideration"*). Evaluate-and-decide; **not** committed work.

- **The coupling.** `install.sh`'s ARTIFACTS maps `AGENTS.md::workflow-AGENTS-template.md`, so the
  file the reviewer reads when reviewing *this* repo is byte-identical to the template `/frame`
  copies into every new repo (`frame/SKILL.md` step 1). One file, two jobs. Anything written to
  sharpen review *here* becomes the starting contract *everywhere*, so this repo structurally
  **cannot** give its reviewer repo-specific guidance. `workflow-protocol.md` calls the contract
  "tunable per repo" — true of every repo except the one that ships it.
- **Why it surfaced.** `estate-reach-guardrails` wanted a strong, concrete directive ("every artifact
  in *this* repo's ARTIFACTS reaches every project; never rank from this repo's Python/Markdown
  mix"). It could not have one, and shipped the **generic conditional** form instead — true
  everywhere, therefore weaker here. That story's option **A**; these are the deferred alternatives.
- **Option B — decouple the template.** Add a `workflow-AGENTS-template.md` file holding the
  portable contract, repoint ARTIFACTS at it, and let `AGENTS.md` become repo-specific.
  **Cost:** a new file (~84 duplicated lines initially), the ARTIFACTS change, doc updates in at
  least four places (`README.md` ×2, `ARCHITECTURE.md`, `workflow-protocol.md`), and a gate check
  worth its place — ARTIFACTS must deploy the *template*, never `AGENTS.md`, since silent failure
  ships this repo's self-description to every project as their contract. **Risk — the real
  objection:** it *manufactures* a drift pair that does not exist today. Two contracts sharing most
  of their text, and whoever improves the contract edits the file in front of them — almost always
  `AGENTS.md`, being the one governing the repo they are in — so the template rots silently and
  every **new** repo bootstraps from the stale copy. That is OPS-17's disease, created rather than
  inherited, and inside a change meant to reduce drift failures. **The obvious mitigation fails:**
  making `AGENTS.md` reference the template instead of duplicating it does not work on the fireworks
  path, which reads the file's *contents* and pushes them as one blob — a pointer never reaches the
  reviewer.
- **Option B′ — an optional repo-local addendum (probably the better structural answer).** Leave
  `AGENTS.md` as the template source; add an optional repo-local file (e.g. `AGENTS.local.md`) as a
  **new optional context source** in `fireworks_runner.py`, pushed alongside the contract, following
  the existing `manifest` optional-input pattern (absent ⇒ stated as absent, never silently
  omitted). **No duplication, so no drift pair** — the addendum holds only what is repo-specific.
  Generalizes: any repo on the estate gains repo-specific reviewer guidance, a capability none has
  today. **Cost:** a runner change with its own review surface, plus a codex-path equivalent — codex
  does not auto-read arbitrary files, so that prompt must name the addendum explicitly, and the two
  backends must agree or the contract differs by backend. **Risk:** more machinery than the problem
  has yet earned; and an optional input that is silently empty is the fail-open shape BUG-6 and the
  fireworks context guard both exist to prevent — it must state absence, not omit it.
- **Trigger (what would make this worth building).** A second occasion where this repo needs to tell
  its reviewer something the template must not carry. One instance (`estate-reach-guardrails`) was
  absorbed by generic wording; a second would show the generic form is not enough.

(Logged 2026-08-05. A **ninth** evaluate-and-decide workflow/architecture item under `OPS-`. The
prefix-revisit question OPS-11 opened keeps accruing data points — still a **one-way door** left for
Thomas. **Interacts with:** OPS-17 — option B creates exactly the restatement-drift pattern that item
exists to eliminate, which is the strongest argument for B′ over B.)

OPS-22 — **Lookback: do reviewer-sourced regressions earn their place?** Filed 2026-08-05 by
`adversarial-falsification-extents`, which shipped OPS-20's Tier-1 items (3 and 4). **This is a
commitment to re-judge, not an open design question.**

- **What shipped, and why it needs re-judging.** The independent reviewer now proposes each
  acceptance criterion's regression list at `/frame` step 6, before any test exists, and the author
  writes tests against *that* list instead of one they authored themselves. It is **new and
  unproven**, and it adds instruction weight to every non-mechanical `/frame` in **every repo
  `install.sh` reaches** — the reach-vs-lightweight tension `ROADMAP.md` → *Direction* names.
- **The precedent that makes this necessary.** `frame-falsification-plan` (2026-08-02) built an
  author-written falsification plan; `thin-the-loop` (2026-08-04) measured it against one story's six
  real defects, found it caught **none** of them, and cut it back to demonstrate-red. That was a
  retrospective that happened **because Thomas noticed** — nothing scheduled it. This item is the
  attempt to not rely on noticing twice.
- **Trigger: after 5 or more full loops** (`/frame → /review → /close`) have run under the
  mechanism.
- **What to weigh.** (a) How many reviewer-proposed regressions the author plausibly would **not**
  have written; (b) how many actually **drove a gate red** at step 9; (c) how often the step-6
  coverage check found the reviewer returning **gaps** (an uncovered AC or an empty array) — a high
  rate means the mechanism is unreliable, not merely unhelpful.
- **The decision it feeds:** keep / amend / **cut back to demonstrate-red only** — the same bar
  `thin-the-loop` applied, stated in advance this time.
- **Judge OPS-18 on the same evidence, at the same time** (Thomas, 2026-08-05: *"fold OPS-18 into
  the lookback"*). OPS-18 proposes reviewer-generated mutations at **review** time, against the
  diff; this mechanism works at **frame** time, against the spec. They are different altitudes and
  could coexist, but committing to a second unproven ceremony before the first has evidence is the
  mistake this item exists to avoid. OPS-18 stays open and unchanged in substance until then.
- **Enforcement was considered and declined** (Thomas, 2026-08-05: *"don't build in the revisit
  trigger as software - just file it as a backlog item"*). Options weighed at that consult: this
  backlog item (**chosen**); a story-count expiry assertion in `tests/reviewer_test.sh` that goes red
  when the trigger comes due (**declined** — it adds gate machinery to police an anti-ceremony rule);
  and an SRE-style measured threshold with a pre-committed consequence (**ruled out on analysis** —
  its measurement is the author self-assessing whether they would have written a given regression
  anyway, which reproduces the single-head coupling OPS-20 exists to break). **Accepted cost:**
  nothing mechanically forces this lookback. It happens because someone reads this item. The
  documented failure mode of every sunset-style commitment is renewal without scrutiny, and a solo
  repo is where that risk is highest — named here rather than discovered later.

(Logged 2026-08-05. A **tenth** `OPS-` workflow item, and the first that exists purely to re-judge a
shipped mechanism rather than to decide an open one. **Interacts with:** OPS-20 — which stays open,
since its Tier-2 items 1 and 2 (property-based and mutation testing, routed via `/dev-audit` Table A)
are untouched by this — and OPS-18, folded in above.)

OPS-23 — **Documentation drift sweep: the remaining findings from the 2026-08-05 audit.** Filed
2026-08-05 from a full doc-drift audit Thomas commissioned during
`adversarial-falsification-extents`. **The four highest-severity findings were fixed in that story**
(see its AC11); everything below is the remainder, deliberately left out of it to keep a
doctrine-change diff from absorbing a documentation sweep.

- **Why the gate did not catch any of this.** `tests/docs_test.sh` enforces exactly one doc
  invariant in each direction: every skill in `install.sh`'s ARTIFACTS is named as a `/command` in
  `README.md` **and** `ARCHITECTURE.md`, and no doc names an undeployed one. It **cannot check
  whether a sentence is true**, and its reverse scan reads only those two files — `BACKLOG.md`,
  `ROADMAP.md`, `CLAUDE.md`, `AGENTS.md` and the `SKILL.md` files are never scanned. That is
  precisely how `/deep-audit` was retired in full with the suite green while an *open* backlog item
  went on reasoning from it in the present tense.
- **MEDIUM — claims that are stale rather than dangerous.** `AGENTS.md` says the reviewer works at
  "two altitudes" and documents two schemas; a third pass (hidden-failure) with its own schema has
  run since 2026-07-17, so the contract gives the reviewer no Output entry for a pass it is actually
  running. `README.md` and `ARCHITECTURE.md` omit `reviews/<slug>.hidden-failure.json` from their
  artifact lists and describe `/review`'s correctness stage without mentioning it runs **two
  concurrent critics**. Both skills instruct a `## Codex <pass> review` heading that no story has
  used since the second backend shipped — following it literally mislabels a fireworks review in the
  permanent trail. CI is described without `shfmt` (which runs on every event) and overstates
  gitleaks, which is pull-request-only. `BACKLOG.md` OPS-13 still says design and approach are
  pending a follow-up; both shipped. OPS-12 lists cross-model source diversity as unbuilt; it
  shipped with `fireworks-models.json`. OPS-15 reasons in the present tense from the retired
  `/deep-audit`. `ROADMAP.md` says one backend is wired. `ARCHITECTURE.md` calls a single script
  "the gate" when `testCommand` runs five suites.
- **LOW — mostly one systemic rename.** "Codex" is used as a synonym for "the reviewer" across at
  least eight files (`README.md`'s tagline, four `SKILL.md` frontmatters, `AGENTS.md`, the
  "Claude↔Codex" branding, `install.sh`'s header). This is **one decision, not eight bugs**, and it
  interacts with the deliberately-kept `.codex.json` filename misnomer that `workflow-protocol.md`
  already documents — so decide the naming question once. Also: "recon tools" plural after the second
  one retired; `ARCHITECTURE.md` citing charter text `thin-the-loop` deleted; dated retirement facts
  duplicated into `ROADMAP.md` against its own no-lifecycle-status rule; and Requirements sections
  that list the `codex` CLI as required while omitting the `fireworks` venv and `FIREWORKS_API_KEY`.
- **Correct today, but unguarded — worth knowing before trusting them.** Nothing anywhere greps for
  a `Status: merged` story header, so the declared-vs-observed doctrine holds only because no one has
  broken it — and `/close` writes that file, so one skill edit could reintroduce it estate-wide with
  the gate green. `workflow-protocol.md`'s "Global (installed once…)" list matches ARTIFACTS exactly
  but is hand-maintained and derives from nothing. The CI↔`testCommand` pin matches the **first**
  `run:` line starting `bash tests/`, so reordering CI would silently compare the wrong string. The
  guard-hook docs are accurate line-by-line but their *wording* is unguarded.
- **The obvious follow-on question, not answered here.** Several of these are cases where a doc
  restates something a machine could derive (the artifact lists, the Global list, the schema
  enumerations in `AGENTS.md`). That is OPS-17's disease, and OPS-20's **computed-extents** rule —
  shipped by the same story that filed this — is the doctrine that would apply. Whether any of it is
  worth mechanizing, versus simply corrected once by hand, is the decision this item exists to put to
  Thomas.

(Logged 2026-08-05. An **eleventh** `OPS-` item. **Interacts with:** OPS-17 — nearly every finding
here is a restatement that drifted from its source, which is that item's thesis with a fresh
evidence set; and OPS-21, since two findings are in `AGENTS.md`, the file that is both this repo's
contract and every other repo's template.)

OPS-24 — **`install.sh --check` reports HAND-EDITED for any deployment whose runner has been
imported.** Filed 2026-08-05 from `adversarial-falsification-extents` round 1, while verifying a
correctness NIT. A **false alarm in a warning that exists to prevent data loss**, so it degrades the
one signal telling you a re-install is unsafe.

- **The mechanism.** `classify_drift` compares the deployed artifact against `git archive <manifest
  commit>` of the same path. `git archive` emits **tracked files only**. But `.gitignore` line 14
  ignores `__pycache__/`, and Python writes exactly that beside `fireworks_runner.py` whenever the
  module is *imported* rather than executed. So the deployed tree carries a directory the archive
  can never contain, `diff -rq` always differs, and the classifier falls through to **HAND-EDITED**
  — whose printed meaning is *"local changes a re-install would destroy."*
- **Confirmed, not theorised.** On this machine, `./install.sh --check` reports `skills/review —
  HAND-EDITED` while the only difference from the manifest commit is `Only in
  <dest>/skills/review: __pycache__`. Every other artifact classified correctly (`STALE` /
  `IN SYNC`), which is why this reads as a real edit rather than an obvious bug.
- **Why it matters beyond cosmetics.** `do_install` counts hand-edits and prints `⚠ N hand-edited
  artifact(s) above will be OVERWRITTEN — local changes lost`. Once that warning fires on a
  deployment nobody edited, it becomes noise — and the next time it is *true*, it reads the same.
  This is the "cry wolf" failure mode, in the guard whose whole job is to be believed.
- **Candidate fixes (evaluate).** (a) **Compare tracked files only** — have `classify_drift` diff
  against the archive's file list rather than the whole directory, so untracked artifacts in the
  deployment are ignored by construction; (b) **exclude known-generated paths** (`__pycache__/`,
  `*.pyc`) from the comparison — narrower, but a hardcoded list that will need extending; (c) **stop
  deploying bytecode** by having the runner write none, which does not help, since the `__pycache__`
  appears at the *destination* from importing the deployed copy. Lean: (a) — it derives what to
  compare from the same source that decided what to deploy, instead of maintaining a second list.
  That is OPS-20's **computed-extents** rule applied to the installer, and this repo just shipped the
  doctrine.
- **Not a blocker for anything today.** The misclassification is conservative in the safe direction:
  it over-warns, never under-warns. Filed rather than fixed in the story that found it, which was
  scoped to `/frame`'s test-notes doctrine.

(Logged 2026-08-05. A **twelfth** `OPS-` item, filed here rather than as `AUDIT-` — that prefix means
*findings graduated from a `/dev-audit` run*, and this came from a review round, not a recon pass.
**Interacts with:** OPS-20's computed-extents rule, which candidate (a) is a direct application of.)

_(OPS-10 shipped — see [Done](#done).)_

---

OPS-27 — **The guard hook leaves no durable record, so a hook trip is invisible to a later
`/close`.** Filed 2026-08-06 by `lesson-proposals`, on Thomas's instruction, as that story's stated
limit rather than a defect discovered later.

- **What was verified.** `.claude/hooks/block-main-writes.sh` denies with a reason on **stderr** and
  exits 2. It writes no log, no file, no marker. Confirmed by reading the script, not assumed.
- **Why it matters now.** `lesson-proposals` triggers a workflow-lesson proposal on safeguard
  *activation*. Of its activation sources, only `install.sh --check` is re-derivable on demand; a
  hook trip and a runner fail-closed refusal are **session-observed only**. A `/close` run in a fresh
  or resumed session cannot see either. The mechanism therefore *reduces* reliance on someone
  noticing — it does not remove it, and the story says so in as many words.
- **The change, if taken.** Have the hook append one line (timestamp, repo, blocked subcommand,
  reason) to a durable path, and have `/close` read it for the current story's window.
- **Cost.** A change to the single load-bearing hook, deployed to **every** repo on this machine,
  with its own review surface and its own failure modes: where does it write; what if that path is
  unwritable; does a failed append block the commit (fail-closed) or pass it (fail-open)? A guard
  that can refuse a legitimate commit because a log write failed is worse than the gap it closes.
- **Risk of leaving it.** The primary detector works only in the originating session, which is the
  weaker half of the story's claim.
- **Interacts with:** OPS-6, [decided against](#decided-against) — that item established the hook is
  a **cooperative** tripwire, not an adversarial wall, and rejected hardening it. This is not
  hardening; it is observability. The distinction is real, but the same "don't grow the one hook
  everything depends on" caution applies, and OPS-6's reasoning should be read before taking this.

OPS-28 — **The runtime containment check for lesson handling has no branch it can run on yet.**
Filed 2026-08-06 by `lesson-proposals`, as the fix to that story's round-2 design finding — filed
rather than intended, because the story's own thesis is that unscheduled intentions fail.

- **What is missing.** `lesson-proposals` AC16 says that at runtime, proposing or approving a lesson
  modifies no file in `install.sh`'s `ARTIFACTS` array and no `.claude/workflow.json`. Its static half
  ships: a negative assertion that the `/close` text contains no instruction to write to those paths
  at proposal or approval time. Its **observational** half — `./install.sh --check` plus a restricted
  `git diff` on a branch where a lesson actually ran — could not run on the implementing branch,
  where that diff is non-empty by construction because the story edits those very files. Running it
  there would verify a fixture, not the behavior.
- **Trigger.** The first story *after* `lesson-proposals` in which `/close` actually proposes or
  approves a lesson.
- **What to do.** On that branch, run `./install.sh --check` and
  `git diff --name-only <base>...HEAD` restricted to the `ARTIFACTS` paths and `.claude/workflow.json`;
  both must come back clean. Then decide whether the check is worth landing as a permanent test or
  whether the one observation suffices.
- **Cost.** Two commands on a branch that will exist anyway.
- **Risk of leaving it.** The containment property the story calls load-bearing would rest
  permanently on an instruction lint — a check on what the text *says*, never on what the loop
  *does*.


OPS-29 — **The correctness critic's `severity` field carries no description at all.** Filed
2026-08-07 by `single-source-rules`, from an audit its approach review prompted. Thomas: *"backlog"*.

- **What was found.** Auditing `finding-schema.json` to answer whether it held restated contract
  rules (it does not — all seven descriptions are field-shape guidance), its `severity` property
  turned out to have an `enum` and **no `description`**. Every other severity-bearing schema now
  resolves `{{contract:Severity labels}}` into that field.
- **Why it may matter.** The correctness critic gets severity semantics only from the contract in
  its prompt, never inline at the field it is filling. The other critics get both. Whether that
  changes how severities are assigned is **unmeasured** — this is a filed observation, not a
  demonstrated defect.
- **Why it was not fixed in the story that found it.** `single-source-rules` migrates *existing*
  restatements to markers. Adding a description where none existed is **new payload**, pushed on
  every correctness review in every repo `install.sh` reaches — a different decision, and the
  opposite of that story's direction, which was to remove copies rather than add text.
- **The decision, if taken.** Add `"description": "{{contract:Severity labels}}"` to
  `finding-schema.json`'s severity. **Cost:** ~5 lines of contract text in the payload of every
  correctness review, forever. **Risk of leaving it:** the one critic whose whole job is grading
  severity is the only one not told inline what the grades mean.
- **Worth measuring first.** Compare severity distributions before and after on a few real reviews.
  If they do not move, the gap is cosmetic and this should be closed as decided-against rather than
  fixed — the cheaper outcome, and the one this item should prefer absent evidence.

OPS-30 — **Nothing detects a second session working in the same repo.** Filed 2026-08-08 by
`dependency-cost-rule`, from a failed attempt during the OPS-25 migration. Thomas: *"file the
concurrent-session item"*.

- **What happened.** While committing the `AGENTS.md` deletion in `sudoku-hints`, a **second session
  was running `/frame` in that same repo**. Mid-attempt it committed `spec: puzzle-bank-generator`
  — timestamped 23 seconds before the collision was noticed — and restored `AGENTS.md` to the
  working tree. The in-flight `git add AGENTS.md` then staged nothing and `git commit` reported
  *"nothing added to commit"*. That is git behaving correctly, and it is **indistinguishable from an
  ordinary no-op**. The attempt was abandoned; `master` was verified untouched and nothing was lost.
- **What has no guard.** Nothing in the loop detects this. The guard hook checks the branch and the
  flags, not concurrency. `/frame`, `/review` and `/close` each switch branches, stage files, and
  commit on the assumption that they are the only writer — no lock, no lease, no check for another
  process in the same worktree.
- **Why it is worse than the symptom suggests.** The dangerous half is not the empty commit, it is
  the **branch switching**. `/close` checks out the base branch to merge; `/frame` checks out a new
  feature branch. Doing either underneath another session's uncommitted work is how edits land on
  the wrong branch, or are reverted by a checkout their author never ran. Here it surfaced harmlessly
  only by luck of timing.
- **How it was caught, and why that is not a control.** By reading `git reflog` after a commit
  behaved oddly, and spotting a commit at `HEAD@{0}` that this session had not made. That is a reader
  noticing an anomaly, not a mechanism. A session that did not think to look would have reported the
  deletion as committed — and the OPS-25 table would have carried that claim, exactly the kind of
  stale-because-unverified entry that item already had to correct twice.
- **Blast radius: every repo.** The four skills deploy via `install.sh`'s ARTIFACTS to `~/.claude`
  and run everywhere. This is not specific to this repo's stack, layout, or test surface.
- **Options — costs stated, none yet chosen.**
  - *Advisory lease* — a `.claude/session.lock` written at skill entry carrying pid + timestamp,
    checked and refused on conflict. **Cost:** every skill grows an entry/exit step plus a staleness
    rule for crashed sessions. **Risk:** a stale lock blocks legitimate work — the classic failure of
    this design, and the reason to prefer a warning over a hard refusal.
  - *Detect rather than prevent* — record `HEAD` and worktree state before any checkout or commit,
    re-check immediately before acting, STOP loudly if either moved. **Cost:** small, and it fails in
    the right direction. **Risk:** narrows the window, does not close it.
  - *Document it and do nothing* — state in `workflow-protocol.md` that one repo takes one session.
    **Cost:** nothing. **Risk:** relies on the human remembering, which is what failed here.
- **Not yet established, and worth answering before building anything.** How often this happens, and
  whether running parallel sessions in one repo is normal practice or was a one-off. If it is rare,
  the third option is the correct and cheapest outcome; this item should prefer that absent evidence.

**Interacts with:** OPS-25, whose migration this interrupted; and OPS-27, since like an unrecorded
hook trip it left nothing durable — it was recoverable only from `git reflog`, and only within the
session that witnessed it.

## Done

| id | Summary | Shipped |
|---|---|---|
| OPS-25 | Five repos carried a stale whole-file copy of the reviewer contract, each a second competing rulebook the reviewer would silently reconcile against the real one. **All four in-scope repos are migrated.** `ruleset-sim` (`f93c0ab`, master) and `txl-assessment-collector` (`cf6a8cb`, main) were trimmed to local add-ons under the standard addendum header; `zoom-meeting-cost` and `sudoku-hints` had zero local content and were deleted outright — a repo needing no local guidance correctly has no `AGENTS.md`. `hw-biz-model` and `convo2article` were excluded by Thomas and are **not** covered. **Three corrections the item earned along the way:** its recorded line numbers were already stale when next picked up (99→88, 120→113), so boundaries must be re-derived from the files, never from a table; its "don't fold this into an unrelated story's diff" caution did not apply to `sudoku-hints` (that branch had no commits of its own) — what actually blocked it was a **concurrent session live in the repo**, a hazard the workflow has no guard for; and the deletions sat uncommitted for two days, which reads as migrated because `_contract_local` checks the **working tree**, while any `git checkout .` or fresh clone restores the file and fails reviews closed. Each deletion landed on the repo's base branch via its own `chore:`/`merge:` pair, and `sudoku-hints`' story branch merged base immediately after, so its review diff is unaffected. | `merge: drop the stale reviewer-contract copy` in each repo (local-only; no PR) |
| OPS-26 | A reviewer could reject an available library on "it would be a dependency" alone — a proxy standing in for costs nobody named. In `txl-assessment-collector` that reasoning blessed a hand-rolled URL-state module which shipped a user-visible bug (multi-word filter terms could not be typed) that **passed all four of that story's review passes**; `nuqs` covers ~70% of it declaratively. **Shipped as a fourth guardrail on the best-practice lens** in `workflow-AGENTS.md`, so every pass at both altitudes inherits it with no per-prompt edit: weigh libraries that *could* be added (not only those installed), name the candidate, give a **specific** cost to reject it (upgrade coupling, surface area, maintenance posture, licence — never dependency *count*), and say what would change the answer. **AC5 dissolved into sequencing** rather than distribution, as the item predicted: the contract is shared, not copied, so the amendment reaches every repo on the next `./install.sh`. Built after the OPS-25 migration per that ordering. **Carried by the same change:** the hardcoded "three guardrails" count was **dropped, not incremented**, at the four prompt sites that restated it — those readers receive the full contract and can follow a pointer, and incrementing would leave the identical trap for a fifth guardrail. | PR #56 / `merge: dependency-cost-rule` |
| OPS-17 | Rules restated across skill prose, schema `description` fields, ACs, drift pins and samples meant a fix landed on one copy and the siblings kept the old text, so a later round reported the un-fixed copy as the same defect returning. **Decided and shipped: remove the copy, do not police it.** Rule text now lives once in `workflow-AGENTS.md`; schema descriptions carry markers (`{{contract:Classify#reversibility}}`) that the runner resolves **into the request** and discards with it, so no derived copy is stored and none can drift. Fail-closed before any API spend; one resolver feeds both backends; the codex render goes to a temp the runner refuses to place inside a working tree. The item's own recommended fix — have descriptions *reference* the skill — was **verified impossible**: descriptions are the reviewer's live instructions and it cannot follow a pointer. **Deliberately excluded:** restatements sourced from a skill rather than the contract (`lesson-review-schema.json`'s `trigger_qualified`), and the AC / test-pin / sample copies — those readers *can* follow a pointer, so `workflow-protocol.md` → *Stated once, assembled per call* covers them by convention rather than machinery. A new item, not this one, if either later needs building. | PR #54 / `merge: single-source-rules` |
| OPS-21 | `AGENTS.md` served two jobs at once — this repo's reviewer contract *and* the template every other repo copied — so this repo structurally could not give its reviewer repo-specific guidance. Resolved by removing the premise rather than either option it weighed: the shared contract was renamed to `workflow-AGENTS.md` and deploys once to `~/.claude/`, so `AGENTS.md` in every repo now means repo-specific additions only. Options B (decouple the template) and B′ (an `AGENTS.local.md` addendum) are both moot — neither is needed once the contract is never copied. | PR #52 / `merge: user-level-contract` |
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
| BUG-6 | Schema validation was vacuous: JSON Schema treats unrecognised keywords as no-ops, so a file that merely parsed as JSON validated anything — including `{}` — and the round promoted an empty body as a clean review. Both enforcement layers (API-side grammar, local validator) read the same dict, so a meaningless schema disabled them together. Fixed with **both** candidate checks, because neither alone closes it: `check_schema` catches a file illegal *as* a schema, and an **empty-object probe** catches the case actually observed — a foreign JSON document, which is a *legal* schema whose keywords are simply unrecognised. The precondition ("every schema MUST reject `{}`") is stated in `load_schema`'s docstring as a contract, naming that the probe's test is narrower than its intent so a future author adds `required` rather than loosening the check. Gate pins it per shipped schema. | PR #49 / `merge: route-design-hidden-failure` |
| OPS-16 | Scope-containment ACs kept breaking on the loop's **own** review-trail artifacts — `.design.json` is written and committed at *frame* time, before implementation, so it became the N+1 file that failed the story's own scope AC. Fixed with candidate (a), the **doctrine exemption**: `workflow-protocol.md` states that `reviews/<slug>.*` is workflow bookkeeping and never the change's product, so scope ACs categorically exempt it and **no story enumerates those files**; `/frame`'s step-5 guidance now carries the canned check `git diff --name-only <base>...HEAD -- . ':(exclude)reviews/'`. Exempts only the workflow's own artifacts — product files stay fully in scope. Estate-wide via `install.sh`. | PR #49 / `merge: route-design-hidden-failure` |
| OPS-19 | `fireworks_runner.py` promoted every artifact without a trailing newline, unlike the repo's hand-maintained JSON. Fixed in `promote()` — one `handle.write("\n")` — taken while the runner was open for BUG-6, exactly as the item directed, rather than as a bookkeeping-only story. | PR #49 / `merge: route-design-hidden-failure` |

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
