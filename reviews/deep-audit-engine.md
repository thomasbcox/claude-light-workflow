Date: 2026-07-24 · Branch: claude/deep-audit-engine · Status: approved

# deep-audit-engine — execute the approved audit plan (OPS-13 engine slice)

## User story (the unit of work — OPS-14 frame)

> **As** the maintainer of a repo who has already compiled and approved a deep-audit plan,
> **I want** the engine to execute *exactly that plan* — run each scheduled lens critic at its
> altitude and depth, then adversarially verify every finding before it reaches me —
> **so that** a whole-app audit surfaces the real judgment-level defects hiding in old, cold code
> the diff-scoped review loop never sweeps, **without burying me in AI false positives.**

The benefit is the yardstick this story is measured against (OPS-14): a finding that isn't a
**verified** judgment-level defect, or a "sweep" that silently skips scope, fails the story even if
the machinery runs. Two named enemies, both from OPS-13's evidence bullet: **coverage gaps that read
as coverage** (a partial sweep presented as whole) and **hallucinated findings that survive to the
report** (same-model panels echo-chambering each other into false confidence).

## Problem

`/deep-audit` (shipped, PR #35) is the **plan stage only**: it compiles a priced, deterministic
audit plan and **stops loudly** — *"the execution engine is not yet built."* Nothing executes the
plan. So the whole-app coverage OPS-13 exists to provide — judgment lenses (hidden-failure,
security, test-adequacy, architecture-coherence) sweeping the *entire* app, not just the newest diff
— does not exist yet. The review loop stays diff-scoped by design; linters cover the *mechanical*
cases in CI; the **judgment** cases in old/cold code have coverage **nowhere**. This story builds the
engine that turns an approved `audit-plan-<date>.json` into a verified findings report.

Two hard lessons from OPS-13's research pass constrain the build and are non-negotiable:

- **Verification is adversarial or it is theater.** Documented mid-2026: 80+ agents *including
  dedicated adversarial reviewers* unanimously endorsed a **nonexistent** vulnerability — same-model
  panels validate each other's hallucinations. Consensus is not verification. So finders and
  verifiers must be **model-independent and context-asymmetric**, verifiers **kill-mandated**, claims
  **mechanically confirmed** wherever checkable.
- **The human triage budget is the scarce resource.** Precision-first reporting with explicit
  **coverage accounting** ("what was NOT covered") — never volume, never a partial sweep dressed as
  complete.

## In scope (recommended: the *first engine slice* — one lens, whole pipeline)

The recommendation is to build **one lens end-to-end through every pipeline stage**, not all four
lenses at once — the same move `parallel-critic` made (ship the hidden-failure lens first, as the
"first citizen"; the rest become wiring once the harness exists). The slice proves the load-bearing,
one-way-door parts (the fleet substrate, the adversarial-verify contract, the plan-execution gate);
adding lens 2–4 afterward is prompt + schema + a plan-row filter, not new architecture.

- A **`/deep-audit-run <plan.json>`** entry point that loads an **approved** plan and executes it.
- **Entry gates** (the two deferred engine ACs that any execution needs): **source-identity
  verification** (recompute a content fingerprint of the audited file set, *excluding* generated
  `reviews/**` plan/review artifacts, and fail closed on mismatch) and the **executability gate**
  (re-run the plan semantic check + a scope registry against the loaded artifact before anything
  runs).
- The **critic fleet**: run the **`hidden-failure` L1** rows — one critic per `unitId`, at the row's
  depth, executing *exactly* the plan's resolved `unitIds` (never re-derived or re-sampled). Own
  prompt + own schema + own artifact (OPS-12 rule); fail-closed temp→validate→promote (the review
  loop's parallel-critic template).
- The **adversarial verify stage**: kill-mandate verifiers, context asymmetry, cross-model,
  mechanical confirmation — the finder→verify contract every lens will reuse.
- **Synthesis**: one precision-first report artifact (verified findings only) + explicit **coverage
  accounting**.
- A **drift linter** `tests/deep_audit_engine_test.sh` pinning the new skill's load-bearing phrases,
  wired into `workflow.json` `testCommand` + `ci.yml` (matching the existing linters).

**Files this story touches (the AC9 scope enumeration — plus anything under `reviews/`):**
`.claude/skills/deep-audit-run/` (`SKILL.md` + `hidden-failure-unit-schema.json` +
`evidence-schema.json` + `audit-report-schema.json`); `.claude/skills/deep-audit/SKILL.md` (the
loud-stop → hand-off replacement, no compile change); `tests/deep_audit_engine_test.sh` (new linter);
`tests/deep_audit_plan_test.sh` (pin update tracking `/deep-audit`'s changed hand-off text, OPS-17);
`.claude/workflow.json` + `.github/workflows/ci.yml` (gate wiring); `install.sh` (deploy the skill
estate-wide).

## Non-goals

- **Lenses 2–4** (`security-data-loss`, `test-adequacy`, `architecture-coherence`) — follow-on
  slices once the harness is proven. (If Thomas scopes the full engine at consult, this moves
  in-scope — see Open question 1.)
- **B/C engines** — no budgeted recursive descent (engine B), no differential re-audit (engine C).
  C's artifact layout is **stubbed** (a two-way door) per the OPS-13 decision; not activated.
- **Estate / multi-repo** — one repo per invocation, exactly like `/deep-audit` and `/dev-audit`.
- **Changing the plan compiler or `/deep-audit`'s plan stage** beyond the minimal contract extension
  the engine's recorded fields require (AC7). `/deep-audit`'s loud stop is *replaced by* pointing at
  `/deep-audit-run`, not by inlining execution into the plan skill.
- **`AUDIT-` graduation to `BACKLOG.md`** — report-first; hand-off only on an explicit instruction
  (the `/dev-audit` posture invariant).
- **Deferred AC (a) — patch-phase structural ops.** Flagged for separation — see Open question 4.

## Acceptance criteria

1. **`/deep-audit-run <plan.json>` exists** at `.claude/skills/deep-audit-run/SKILL.md` (name +
   description frontmatter only, OPS-9 convention) with a **step-0 stand-down** (defer to
   `docs/ai-protocol.md` repos) and a **refuse-unless-approved** guard: a plan whose `status` is not
   `approved` stops loudly, unexecuted.
2. **Source-identity gate (deferred AC c).** Before any critic runs, the engine recomputes a content
   fingerprint of the audited file set **excluding generated plan/review artifacts** (`reviews/**`,
   so an in-repo plan commit does not self-invalidate the bound revision), and **fails closed** if
   the target no longer matches the plan's `source` — clean tree: the bound `revision`; dirty tree: a
   content fingerprint that uniquely identifies the tree (the boolean `dirty` alone does not). No
   silent "run anyway."
3. **Executability gate (deferred AC b).** Before any critic runs, the engine re-runs the plan
   semantic check against the *loaded artifact* — row-identity uniqueness; `totals.runs` /
   `totals.estTokens` equal the row sums; per row `runs = |unitIds| × (deep?2:1)`; every L1 row's
   `unitIds ⊆` its scope's `codeUnitIds` — **plus a scope registry**: every row's `unitIds` resolve
   in `unitMap`. Any failure stops loudly; no partial execution.
4. **Fleet executes the plan exactly — off an explicit run manifest (DR-3).** Before spawning, the
   engine expands the in-scope rows into a **run manifest**: one run-record per `(row identity,
   unitId, pass index)`, the pass count derived from the depth factor (`deep` → 2 passes per unit,
   `standard`/`light` → 1), so a deep row materializes `2 × |unitIds|` records — **not** `|unitIds|`.
   The engine **validates the manifest's cardinality and est-cost equal the approved plan's
   `totals`** (a deep row that fanned out once would fail this), then maps the fleet over **exactly**
   those records — never re-deriving or re-sampling `unitIds` (light-depth sampling was fixed at plan
   time). Each critic owns its prompt, schema, and artifact (OPS-12), keyed by run identity; each is
   launched to a fresh temp and **promoted only on {clean exit AND valid JSON}** — any critic failing
   **stops the round** (the parallel-critic fail-closed template, scaled).
5. **Adversarial verify — evidence record + deterministic adjudication (DR-1).** The verifier stays
   **claim-blind and cross-model**: given the **location + lens but never the finder's claim/
   argument** (context asymmetry), run by **a different model from the finder** (echo-chamber
   defense), it reads the cited code fresh and emits a **structured, claim-independent evidence
   record** — observable control flow, error-propagation behaviour, reachable outcomes, uncertainty —
   with **mechanical confirmation** run first wherever the lens's claim class is mechanically
   checkable. A separate **deterministic adjudication step** then evaluates the *stored finder claim*
   against that evidence via an explicit promote/refute decision table (default **refuted** on
   uncertainty). Stable `findingId`/`evidenceId` join the two. A finding reaches the report **only
   if adjudication confirms it**; refuted or uncertain findings are dropped. (This preserves context
   asymmetry as a real property, not a leak-through — the verifier never sees the proposition it
   would otherwise just echo.)
6. **Synthesis is precision-first, off a per-row execution ledger (DR-2).** The report is built from
   a **declarative execution ledger** — one entry per plan row in a distinct state
   (`planned` / `executed` / `omitted` / `failed`) plus a `verifiedFindingCount`. It records **only
   verified findings** (grouped by lens / altitude / scope, each carrying its run + evidence
   provenance) **and** a coverage account computed from the ledger: `notCovered` is derived **only**
   from `omitted` rows (planned omissions) + out-of-slice lenses/altitudes — an **`executed` row with
   zero survivors is *covered* with a negative result, never listed as uncovered** (a clean sweep and
   a scope gap must be mechanically distinguishable). Volume is never the headline; the coverage
   account is mandatory.
7. **Failure ≠ planned omission.** A **failure** (critic crash, unparseable output, verify-stage
   error, gate mismatch) **stops the round loudly** — a partial sweep is *never* presented as a whole
   one (the exact hidden-failure disease the audit exists to catch). A **planned omission** (a lens
   the plan didn't schedule) is reported honestly in the coverage account. The report never conflates
   the two, and never silently downgrades a failure into an omission.
8. **Contract handling.** The engine consumes `plan-schema.json` v1. Any field the engine must record
   (e.g., the source fingerprint) either extends v1 **in place** (permitted — v1 has no other
   consumers) or bumps `planVersion`; the choice is documented once in the skill, JSON stays
   canonical, and the plan semantic check is updated in lockstep.
9. **Read-only + posture + scope containment.** The engine is **read-only against the target** except
   its own output artifacts under `reviews/`; secret redaction is inherited (detector/type ·
   path:line · count, **never a value**). `git diff --name-only main...HEAD` shows no file beyond
   those this story enumerates **and files under `reviews/`** (the workflow's own review-trail
   artifacts are categorically exempt — OPS-16).
10. **Drift linter + gate.** `tests/deep_audit_engine_test.sh` pins the new skill's load-bearing
    phrases (the fail-closed rule, the cross-model + context-asymmetry verify requirement, the
    failure-vs-omission distinction) and is wired into `workflow.json` `testCommand` and the `ci.yml`
    gate. Per OPS-17: each rule is pinned **once** here; schema `description` fields **reference** the
    skill, they do not restate the rule.

**AC → user-story trace (OPS-14).** Benefit "surfaces real defects": AC4 (runs the plan), AC6
(reports them). Benefit "in cold code the loop never sweeps": AC3/AC4 (whole-plan execution).
Benefit "without burying me in false positives": AC5 (adversarial verify — the precision guarantee),
AC7 (no partial-sweep-as-whole). Trust preconditions: AC1/AC2 (executes only an approved plan,
against the code it was priced on).

## Test notes

- **AC1** — the skill file exists with the required frontmatter, stand-down, and status guard; the
  linter (AC10) pins the guard phrase. A `status: proposed` plan fixture is refused.
- **AC2/AC3** — feed the engine a **tampered** plan fixture (mutated `totals`, a `unitId` absent from
  `unitMap`, a `source.revision` that no longer matches) and assert it **stops** before any critic
  launches. A clean fixture passes both gates.
- **AC4** — assert the set of critic invocations equals the plan's `unitIds` for the in-scope rows
  (no more, no fewer; light rows run the sampled subset the plan already fixed). Kill one critic
  mid-run and assert the round stops with no promoted stale artifact (the parallel-critic invariant).
- **AC5** — an integration check that the verifier invocation carries the code location but **not**
  the finder's claim text, and runs a **different model** than the finder; a seeded false finding is
  dropped, a seeded true finding survives. (Model identity + prompt shape are inspectable in the
  skill's documented invocation; a live cross-model run is a manual dogfood, not a unit gate.)
- **AC6/AC7** — the report artifact schema requires a non-empty coverage account; a run with a forced
  critic failure produces a **loud stop**, not a report with a silently shortened coverage list.
- **AC9** — `git diff --name-only main...HEAD` shows no file beyond those the ACs enumerate plus
  files under `reviews/`. Redaction re-uses the `/dev-audit` rule verbatim.
- **AC10** — the linter fails if any pinned phrase drifts; it runs under the existing `testCommand`.

## Open questions (for Thomas at the consult)

1. **Slice size — the lead decision.** Recommended: **first engine slice** (hidden-failure lens
   end-to-end). *Cost:* one lens's worth of report value now; lenses 2–4 are separate cycles.
   *Risk it buys down:* the fleet substrate and the adversarial-verify contract are **one-way doors**
   (every future lens copies them) — proving them on one lens before committing four is the whole
   point. **Alternative — full engine (all four lenses) in one story.** *Cost:* the largest story in
   this repo's history by a wide margin, against the loop's "lightweight" identity; `deep-audit-plan`
   took 5–7 review rounds at a *fraction* of this surface. *Risk:* if the verify contract needs
   rework after lens 1, you've built it into four. **Recommendation: slice.** (Grounded in
   `parallel-critic`'s precedent and OPS-13's own "first slice" framing — not preference.)
2. **Fleet substrate + the finder/verifier model split (one-way door — needs ratification).** The
   OPS-13 build note records an intent to **reuse the session harness's Workflow engine** for
   orchestration (fan-out, budgets, verify) rather than hand-roll it. But the echo-chamber evidence
   forbids **same-model** finder/verifier pairs. The two reconcile only one way: orchestrate on the
   Workflow engine **and** make the verify stage genuinely independent — **finders one model,
   verifiers another** (e.g., Claude finders + `codex` verifiers, or the reverse), context asymmetry
   enforced by the orchestration. *Alternative:* a pure `codex exec` fleet (review-loop-consistent,
   but codex-finds-codex-verifies is the echo chamber the evidence warns against, and it rebuilds
   orchestration the Workflow engine already has). This is the decision that shapes everything
   downstream — I recommend **Workflow-orchestrated + cross-model verify**, and it needs your
   one-way-door ratification.
3. **Contract extension (AC8) — extend v1 in place vs. bump to `planVersion` 2.** Extending in place
   is cheaper and permitted (no other consumers); a bump is cleaner if the engine's recorded fields
   are substantial. Two-way either way, but it sets the precedent for the C-ledger mode. Lean:
   **extend v1 in place** unless the fingerprint field grows into a cluster.
4. **Deferred AC (a) — patch-phase structural ops.** OPS-13 filed it as an "engine-slice opening AC,"
   but its nature is **plan-compiler** work (dedicated `exclude-files`/`only-files` union branches;
   `remove`/`restrict` reserved for compiled rows) — it changes how the *plan* is compiled, not how
   it's *executed*. The engine can execute today's plans without it (the smoke plan has empty
   overrides). **Recommendation: separate it** into a small plan-stage follow-up, keeping this story
   about execution. Your call — it's your deferral to move.
5. **Output artifact naming / C-ledger stub shape.** Proposed: `reviews/audit-report-<date>.json`
   (canonical) + per-lens raw finding files, mirroring the plan's `.json`+derived-view split, with
   the C-ledger disposition fields stubbed. Two-way; confirm the naming so it doesn't churn later.

## Design sketch — HOW

**Shape: a pipeline skill that reads the plan, gates, fans out, verifies, synthesizes — orchestrated
on the existing Workflow engine, not a new runtime.** Stages, in order:

1. **Load + guard.** `/deep-audit-run <plan.json>` reads the artifact, validates it against
   `plan-schema.json` v1, and refuses anything not `status: approved`. (Reuses the plan skill's
   parse-check + semantic-check code path — the executability gate is that same check re-run on the
   loaded file, so there is one implementation of "is this plan sound," not two.)
2. **Entry gates (deferred ACs b + c).** *Source-identity:* `git`-fingerprint the audited file set
   with `reviews/**` excluded (so the plan's own in-repo commit doesn't self-invalidate), compare to
   `source` — clean tree keys on `revision`, dirty tree on the content fingerprint; mismatch → loud
   stop. *Executability:* the semantic check + scope registry (`unitIds` ⊆ `unitMap`). Both are
   **fail-closed pre-flight**; nothing spawns until both pass.
3. **Run manifest → fleet (DR-3).** First materialize a **run manifest**: expand every in-scope row
   into run-records keyed by `(row identity, unitId, pass index)`, pass count = the depth factor
   (`deep` → 2, else 1); **assert the manifest's cardinality and est-cost equal the approved plan's
   `totals`** (this is what makes a deep row actually launch its `2×|unitIds|` priced runs). Then
   author a **Workflow** that `parallel`/`pipeline`s over exactly those records — each a **finder**
   agent carrying the lens's prompt and its **own structured schema** (Table L / OPS-12 own-schema
   rule; the `hidden-failure` critic reuses the charter of `hidden-failure-schema.json`, adapted to
   whole-unit scope rather than a diff). Fail-closed promotion per finder, keyed by run identity (the
   review-SKILL temp→validate→promote template is the invariant; the Workflow's per-agent error
   handling enforces it).
4. **Adversarial verify — evidence record + adjudication (DR-1).** The verifier is **claim-blind and
   cross-model**: given the **location + lens only, never the finder's claim**, run by **a different
   model**, it reads the cited code fresh and emits a **structured evidence record** (control flow,
   error propagation, reachable outcomes, uncertainty), with mechanical confirmation run first where
   the lens's claim class is mechanically checkable (e.g. "this `catch` swallows" → grep/AST the
   cited block). A separate **deterministic adjudication** step then scores the *stored finder claim*
   against that evidence via an explicit promote/refute table (default **refuted** on uncertainty),
   joined by `findingId`/`evidenceId`. Survivors — and only survivors — pass to synthesis. Teams stay
   **small (3–4)** with hierarchical summarization as the repo-scale context substrate (the OPS-13
   evidence bullet).
5. **Synthesis off an execution ledger (DR-2).** Build a **per-row execution ledger** — each plan row
   in state `planned` / `executed` / `omitted` / `failed`, plus `verifiedFindingCount`. Emit
   `audit-report-<date>.json` (canonical) + a derived `.md` view (the plan's JSON-canonical /
   view-derived split): verified findings grouped by lens/altitude/scope, and a coverage account
   **derived from the ledger** — `notCovered` = `omitted` rows + out-of-slice lenses/altitudes
   **only**; an `executed` row with zero survivors is *covered* (negative result), never uncovered.
   Any `failed` row suppresses the whole report (stage 7 below). Report-first stop; no `AUDIT-` write
   without an explicit instruction.

**Cross-cutting patterns (these are the one-way doors the design review should weigh):**
- **Fail-closed everywhere, and *failure ≠ omission*.** A crash/invalid-output/gate-mismatch stops
  the round loudly (the `/deep-audit` loud-stop pattern, generalized); a *planned* gap is coverage
  data. One boolean must never quietly become the other (AC7).
- **Per-critic own schema + own artifact** (OPS-12), and **each rule stated once** (OPS-17): the skill
  prose is authoritative; schemas `description`-reference it.
- **Cross-model + context-asymmetric verify** as a *contract*, not a per-lens choice — every future
  lens inherits it.
- **C-ledger artifact fields stubbed** from day one (two-way door, per OPS-13) so a later differential
  mode doesn't reverse-engineer the report shape.

**Leans on / reuses:** the Workflow engine (orchestration — Thomas's build-note intent); the
parallel-critic fail-closed join (`review/SKILL.md`); the plan semantic check and `plan-schema.json`
(`deep-audit/`); the `/dev-audit` redaction + read-only posture; `hidden-failure-schema.json` as the
lens-schema precedent. **New:** the `/deep-audit-run` skill, the lens finder/verifier prompts +
schemas (one lens for the slice), the report artifact + its schema, the source-identity fingerprint,
and the drift linter.

## Codex design review (2026-07-24)

Artifact: `reviews/deep-audit-engine.design.json`.

**Verdict:** *"The slice-first pipeline and fail-closed posture are directionally sound, but I would
not build the cross-cutting harness from this sketch yet. Its verification join cannot actually
refute an identified claim, its coverage model classifies successful negative sweeps as uncovered,
and its fan-out does not realize the plan's deep-run cardinality. I would retain the Workflow-based
pipeline but drive it from an explicit run manifest, use claim-independent evidence records for
adversarial verification, and model execution coverage separately from finding outcomes."*

Three findings, **all BLOCKER, all one-way** — each defines a reusable-harness contract every future
lens inherits, so each is worth fixing in the sketch *before* code. I concur with all three; #3 is
mechanically provable from the shipped smoke plan.

### BLOCKER

- **DR-1 — A claim-blind verifier cannot refute a specific finding** — *one-way · kludgy.* (locus:
  stage 4, adversarial verify / AC5.) The sketch gives the verifier `file:line` but **not** the
  finder's claim, yet asks it to decide whether *that finding* was refuted. Location alone is no
  proposition to test — implementations would have to leak the claim through a side channel or treat
  "independent rediscovery near the same line" as verification; neither delivers the promised
  precision. Even the mechanical-confirmation example ("this `catch` swallows") needs to know the
  alleged behaviour. **Alternative:** keep the verifier claim-blind, but have it emit a **structured,
  claim-independent evidence record** for the cited location + lens (observable control flow, error
  propagation, reachable outcomes, uncertainty); then a **deterministic adjudication** step evaluates
  the stored finder claim against those facts. Stable finding/evidence IDs + an explicit
  promote/refute decision table become part of the reusable verifier contract. **Win:** removes an
  undefined judgment handoff, stops nearby-but-different defects from falsely corroborating a finder,
  and preserves context asymmetry without covertly weakening it — one contract serves every lens.

- **DR-2 — Coverage and finding outcomes are collapsed into one set** — *one-way · nonstandard.*
  (locus: stage 5, synthesis / AC6.) The `notCovered` union includes scheduled rows with **zero
  surviving findings** — but such a row **was covered** and produced a *negative* result; it was not
  omitted. Encoding it as uncovered contradicts the sketch's own failure-vs-omission invariant (AC7)
  and makes a clean audit indistinguishable from a scope gap in the canonical report contract future
  lenses inherit. **Alternative:** a declarative **per-row execution ledger** with distinct states
  (`planned` / `executed` / `omitted` / `failed`) plus `verifiedFindingCount`; derive `notCovered`
  **only** from planned omissions + out-of-slice scope; list executed-zero-survivor rows under
  *covered*. Still suppress the whole report on any `failed` row. **Win:** centralizes the coverage
  invariant, kills ambiguous set arithmetic, makes zero-defect sweeps, intentional omissions, and
  fatal failures mechanically distinguishable without prose.

- **DR-3 — Fan-out does not encode deep-run multiplicity** — *one-way · kludgy.* (locus: stage 3,
  fleet / AC4.) The plan contract defines a deep row as `runs = 2 × |unitIds|`, but the sketch fans
  out **once** over `unitIds`. Deep rows carry the *same* full unit list as standard rows — depth is
  **not** "baked into `unitIds`," it lives in `runs` — so iterating `unitIds` launches only **half**
  the approved, priced deep runs, and "at the row's depth" never defines what the second pass is or
  how its provenance joins. (Smoke plan proof: the deep `(root)` row has `runs: 2`, `unitIds:
  ["install.sh"]`.) **Alternative:** materialize one **execution manifest** before spawning — expand
  every row into run-records keyed by `(row identity, unitId, pass index)`, pass count derived from
  the depth factor; validate manifest cardinality + est-cost equal the approved plan; map Workflow
  over exactly those records, aggregating by row/unit. **Win:** removes bespoke depth handling from
  the orchestrator, makes the launched fleet equal the approved price *by construction*, and gives
  every finder artifact an unambiguous run identity for failure accounting + verification provenance.

**Common thread:** all three say *make the harness drive off explicit declarative records* — a **run
manifest** (DR-3), **evidence records + an adjudication table** (DR-1), and an **execution ledger**
(DR-2) — rather than implicit iteration and set arithmetic. That is one coherent correction to the
sketch, and it strengthens exactly the one-way-door contracts lenses 2–4 will copy.

## Design decisions (2026-07-25)

Thomas's frame-consult decisions — **binding on implementation**:

- **Scope — "first-lens slice."** Build the `hidden-failure` lens end-to-end through the whole
  pipeline (gates → run manifest → fleet → evidence-record verify → adjudication → ledger synthesis);
  lenses 2–4 are follow-on cycles. Rationale on record: the fleet substrate and the verify contract
  are one-way doors every lens copies, so they are proven on one lens before four are committed
  (the `parallel-critic` precedent, and OPS-13's own "first slice" framing).
- **Fleet substrate — "Workflow + cross-model verify" (one-way door, ratified).** Orchestrate on the
  session harness's Workflow engine (the OPS-13 build-note intent); finders one model, verifiers
  another, context asymmetry enforced by the orchestration. Cross-model verify is a **contract**, not
  a per-lens choice.
- **Design findings DR-1, DR-2, DR-3 — all FIX (folded into the approved shape).** No objection at
  consult; all three are one-way BLOCKERs defining reusable-harness contracts. AC4 now builds the
  **run manifest** (DR-3); AC5 the **claim-blind evidence record + deterministic adjudication**
  (DR-1); AC6 the **per-row execution ledger** (DR-2). The sketch stages 3–5 were revised to match.
- **Smaller opens — taken at the recommended leans (no objection):** (3) extend `plan-schema` v1
  **in place** (no other consumers); (4) deferred AC (a) patch-phase structural ops is **plan-compiler
  work, split to a separate plan-stage follow-up** — not this execution story; (5) report artifact
  **`audit-report-<date>.json`** confirmed, with C-ledger disposition fields stubbed.
