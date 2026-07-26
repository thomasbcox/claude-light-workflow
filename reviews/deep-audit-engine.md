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
`evidence-schema.json` + `audit-report-schema.json`); `.claude/skills/deep-audit/SKILL.md` (loud-stop
→ hand-off; **AR-1**: step 2/6 compute + record `contentFingerprint`) and
`.claude/skills/deep-audit/plan-schema.json` (**AR-1**: the `source.contentFingerprint` field);
`tests/deep_audit_engine_test.sh` (new linter); `tests/deep_audit_plan_test.sh` (pin updates: hand-off
text + `contentFingerprint`); `.claude/workflow.json` + `.github/workflows/ci.yml` (gate wiring);
`install.sh` (deploy the skill estate-wide). Under `reviews/` (exempt): the story + design/approach
artifacts, and the smoke-plan fixture patched with a `contentFingerprint`.

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
2. **Source-identity gate (deferred AC c; AR-1).** Before any critic runs, the engine recomputes the
   plan's **`source.contentFingerprint`** — a content digest of the audited file set **excluding
   generated plan/review artifacts** (`reviews/**`, so an in-repo plan commit does not
   self-invalidate the binding) over **working-tree content**, computed **identically for clean and
   dirty trees** — and **fails closed** if it no longer matches. One mechanism covers both: a **dirty
   plan is executable** (the digest captures its uncommitted content), so there is no dirty-plan
   refusal. `revision`/`dirty` are provenance. No silent "run anyway."
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
5. **Adversarial verify — evidence record + mechanical-first adjudication (DR-1, AR-2).** The verifier
   stays **claim-blind and cross-model**: given the **location + lens but never the finder's claim/
   argument** (context asymmetry), run by **a different model from the finder** (echo-chamber
   defense), it reads the cited code fresh and emits a **structured, claim-independent evidence
   record** — observable control flow, error-propagation behaviour, reachable outcomes, uncertainty —
   with **mechanical confirmation** run first wherever the lens's claim class is mechanically
   checkable. Adjudication then runs in **two tiers, without claiming blanket determinism (AR-2)**: a
   **mechanical tier** decides deterministically where the claim class is mechanically checkable (the
   evidence enums settle promote/refute, no model), and a **judgment tier** — a cross-model,
   kill-mandate, evidence-grounded adjudicator — judges the rest as **honest model judgment** (default
   **refuted** on uncertainty). Stable `findingId`/`evidenceId` join finder to evidence. A finding
   reaches the report **only if its adjudication tier promotes it**; refuted or uncertain findings
   are dropped. (What closes the echo chamber is the claim-blind cross-model verifier **upstream** —
   not the adjudicator; the mechanical tier keeps determinism exactly where it is real, and the
   judgment tier is honest about being judgment.)
6. **Synthesis is precision-first, off a per-row execution ledger (DR-2).** The report is built from
   a **declarative execution ledger** — one entry per plan row in a distinct state
   (`planned` / `executed` / `omitted` / `failed`) plus a `verifiedFindingCount`. It records **only
   verified findings** (grouped by lens / altitude / scope, each carrying its run + evidence
   provenance) **and** a coverage account computed from the ledger: `notCovered` is derived **only**
   from `omitted` rows (planned omissions) + out-of-slice lenses/altitudes — an **`executed` row with
   zero survivors is *covered* with a negative result, never listed as uncovered** (a clean sweep and
   a scope gap must be mechanically distinguishable). Volume is never the headline; the coverage
   account is mandatory.
7. **Failure ≠ planned omission (+ durable failure record, AR-3).** A **failure** (critic crash,
   unparseable output, verify-stage error, gate mismatch) **stops the round loudly and writes no
   findings report** — a partial sweep is *never* presented as a whole one (the exact hidden-failure
   disease the audit exists to catch) — **but records a durable failure diagnostic**
   (`reviews/audit-run-<date>.failed.json`: the stage that failed + each in-scope row's reached
   state) so a run that **failed midway** is distinguishable from one that **never began**. A
   **planned omission** (a lens the plan didn't schedule) is reported honestly in the coverage
   account. The report never conflates the two, and never silently downgrades a failure into an
   omission.
8. **Contract handling (AR-1).** The engine **extends `plan-schema` v1 in place** (permitted — v1 has
   no other consumers): it adds **`source.contentFingerprint`**, the one digest that identifies the
   audited code for clean and dirty trees. The report is its own contract (`audit-report-schema.json`
   v1). Only the differential C-ledger mode bumps a `planVersion`/`reportVersion`; the choice is
   documented once in the skill, JSON stays canonical, and the plan semantic check moves in lockstep
   with the added field.
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
2. **Entry gates (deferred ACs b + c).** *Source-identity (AR-1):* recompute the plan's **one
   `source.contentFingerprint`** over the non-`reviews/**` tracked working-tree content (excluding
   `reviews/**` so the plan's own in-repo commit doesn't self-invalidate), compare to `source`;
   mismatch → loud stop. Computed identically for clean **and** dirty trees, so a **dirty plan is
   executable** — no refusal, one mechanism. *Executability:* the semantic check + scope registry
   (`unitIds` ⊆ `unitMap`) **+ cardinality/est-cost equality**. Both are **fail-closed pre-flight**;
   nothing spawns until both pass.
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
4. **Adversarial verify — evidence record + mechanical-first adjudication (DR-1, AR-2).** The verifier
   is **claim-blind and cross-model**: given the **location + lens only, never the finder's claim**,
   run by **a different model**, it reads the cited code fresh and emits a **structured evidence
   record** (control flow, error propagation, reachable outcomes, uncertainty), with mechanical
   confirmation run first where the lens's claim class is mechanically checkable (e.g. "this `catch`
   swallows" → grep/AST the cited block). Adjudication then runs in **two tiers, with no
   blanket-determinism claim (AR-2)**: a **mechanical tier** decides deterministically from the
   evidence enums where it can (no model), and a **judgment tier** — cross-model, kill-mandate,
   evidence-grounded — judges the rest as **honest judgment** (default **refuted** on uncertainty),
   joined by `findingId`/`evidenceId`. Survivors — and only survivors — pass to synthesis. Teams stay
   **small (3–4)** with hierarchical summarization as the repo-scale context substrate (the OPS-13
   evidence bullet).
5. **Synthesis off an execution ledger (DR-2).** Build a **per-row execution ledger** — each plan row
   in state `planned` / `executed` / `omitted` / `failed`, plus `verifiedFindingCount`. Emit
   `audit-report-<date>.json` (canonical) + a derived `.md` view (the plan's JSON-canonical /
   view-derived split): verified findings grouped by lens/altitude/scope, and a coverage account
   **derived from the ledger** — `notCovered` = `omitted` rows + out-of-slice lenses/altitudes
   **only**; an `executed` row with zero survivors is *covered* (negative result), never uncovered.
   Any `failed` row suppresses the whole findings report — **but writes a durable
   `audit-run-<date>.failed.json`** (AR-3) so the failure is observable, distinct from a run that
   never began (stage 7 below). Report-first stop; no `AUDIT-` write without an explicit instruction.

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

## Codex approach review (2026-07-25, base main, HEAD da6b7ec)

Artifact: `reviews/deep-audit-engine.approach.json`. First review; approach pass run against the
built shape.

**Verdict:** *"The slice-first Workflow pipeline is the right overall architecture, but I would not
ship this as the reusable harness future lenses copy. The source binding rejects artifacts the
planner permits, the supposedly deterministic adjudication still requires semantic AI judgment, and
execution lifecycle state remains split across prose-only structures. I would retain Workflow, Git,
and Draft-7 — the repo has no conventional dependency manifest — but drive them from versioned source,
claim/evidence, and run-state contracts."*

Three findings, **all BLOCKER, all one-way** — each names a cross-cutting contract future lenses
inherit. The consistent thrust (echoing the frame-time review): *drive the harness off typed
contracts, not prose.*

### BLOCKER

- **AR-1 — Source identity has two incompatible contracts** — *one-way · kludgy.* (locus
  `SKILL.md:49`.) The planner can compile and approve a **dirty-tree** plan, but the engine
  **categorically refuses** one — an approved artifact the hand-off cannot execute (contradicts AC2),
  and it splits source-identity into revision-compare (clean) + a deferred dirty mechanism with
  bespoke hashing around the split. **Alternative:** extend `plan-schema` v1 **now** with one
  canonical `source.contentFingerprint` over the audited non-`reviews/**` tracked set, computed for
  **both** clean and dirty; recompute + compare that same digest at execution; keep `revision`/`dirty`
  as provenance. **Win:** deletes the dirty-refusal path and the clean/dirty branch, one field + one
  comparison, every approved plan executable.

- **AR-2 — The deterministic adjudicator has no deterministic inputs** — *one-way · kludgy.* (locus
  `SKILL.md:115`; both finder + evidence schemas.) The finder emits **unrestricted prose** `claim`;
  the evidence record leaves `controlFlow`/`reachableOutcomes` as **prose**; the "decision table" just
  says promote when they "corroborate the claim's mechanism" — **no deterministic operation can do
  that semantic comparison.** So the adjudicator step reintroduces **model judgment (and the
  echo-chamber risk) at the very stage meant to remove it.** **Alternative:** make finder claims and
  verifier observations **discriminated unions** — a small claim taxonomy + decisive facts
  (construct-present, handler action, error propagation, degraded continuation, mechanical-check
  result); one declarative **claim-class × evidence-facts** promote/refute table; prose only
  explanatory. **Win:** removes the adjudicator agent + its error path, makes promotion mechanically
  reproducible, preserves claim-blindness, and gives every future lens an explicit extension point.

- **AR-3 — Manifest and ledger are postulated, not modeled as one execution contract** — *one-way ·
  nonstandard.* (locus `SKILL.md:89` & `:139`; `audit-report-schema.json`.) The run manifest is
  prose, validates cardinality but **not AC4's est-cost equality**; execution state is then
  **reconstructed after the run** in a separate report ledger with only `executed`/`omitted` —
  `planned`/`failed` deliberately absent. So the orchestrator hand-rolls lifecycle + failure
  accounting, and **a failed run leaves no record distinguishing it from one that never began.**
  **Alternative:** **one versioned run artifact** initialized before spawning (row identity, child run
  records, approved est-cost, model provenance, `planned`/`executed`/`omitted`/`failed` +
  verifiedFindingCount); validate cardinality + cost + model-separation before launch; transition it
  during the run; derive the report only when **no row is `failed`**. **Win:** centralizes
  manifest/failure/provenance/coverage, kills post-hoc reconstruction, makes AC4/AC6/AC7 checkable
  from one artifact, and gives failures an observable record without publishing a partial report.

## Decisions (2026-07-25, approach round 1)

All three approach BLOCKERs → **FIX** (a redesign). Per the approach short-circuit, the correctness
pass did **not** run this round; the redesign goes through `/close` and comes back for a fresh review
(next round re-runs the approach pass on the new shape). The exact scope `/close` will apply:

- **AR-1 → FIX** (Thomas: *"Fix — one contentFingerprint field"*). Extend `plan-schema` v1 with a
  canonical **`source.contentFingerprint`** over the audited non-`reviews/**` tracked-file set,
  computed for **both** clean and dirty at plan time; `/deep-audit` step 2 computes + stores it;
  `/deep-audit-run` step 2 **recomputes + compares that one digest** and **drops the dirty-plan
  refusal** (dirty plans become executable). `revision`/`dirty` stay as provenance. Touches
  `plan-schema.json`, `deep-audit/SKILL.md` step 2, `deep-audit-run/SKILL.md` step 2,
  `audit-report-schema.json` (dirty may now be true), and both drift linters. *(Scope note: this adds
  `.claude/skills/deep-audit/plan-schema.json` to the AC9 enumeration — approved here.)*

- **AR-2 → FIX, option C — honest hybrid** (Thomas: *"C — honest hybrid (mechanical + judgment)"*,
  after weighing the determinism question). Adjudication stops claiming blanket determinism: **mechanical
  confirmation decides where it can** (deterministic, reproducible, no model — driven by the evidence
  record's `errorHandling` / `mechanicalChecks` / `locationConfirmed` enums); where a claim is **not**
  mechanically decidable, a **cross-model, kill-mandate, evidence-grounded adjudicator judges** it
  (default refute). `deep-audit-run/SKILL.md` step 5 states the split honestly; the finder keeps its
  prose claim (no rigid claim taxonomy — option A was declined). Decision rationale recorded:
  determinism was never the echo-chamber defense (context-asymmetry + cross-model + kill-mandate are);
  it bought partial reproducibility + gate-inspectability, which C keeps exactly where it is real.

- **AR-3 → FIX, core only** (Thomas: *"Fix core only — est-cost + failed record"*). `/deep-audit-run`
  step 4 manifest validation also asserts **AC4's est-cost equality** (Σ in-scope `estTokens`); and a
  **failed run leaves a durable observable record** (a `failed`-state artifact distinguishing
  "failed midway" from "never ran") **without** publishing a partial findings report. Manifest and
  report-ledger stay separate structures (the full unified run-artifact — option "fix fully" — was
  declined for slice 1).

## Fixes (2026-07-25, approach round 1)

Applied the three approved redesigns; gate green.

- **AR-1 (one contentFingerprint).** `plan-schema` v1 gains **`source.contentFingerprint`** (required);
  `/deep-audit` step 2 computes it over the non-`reviews/**` tracked working-tree content (clean *and*
  dirty), step 6 records it; step 6's binding text now points at the fingerprint. `/deep-audit-run`
  step 2 **recomputes + compares that one digest** and **drops the dirty-plan refusal** — dirty plans
  are now executable via the fingerprint. Report schema echoes `contentFingerprint` and no longer
  claims dirty is always false. Both drift linters + the smoke-plan fixture updated. AC2/AC8, sketch
  stage 2, and the file enumeration follow.
- **AR-2 (honest hybrid adjudication).** `/deep-audit-run` step 5 now states the split: a **mechanical
  tier** decides deterministically from the evidence enums where it can (no model, reproducible), and
  a **judgment tier** — cross-model, kill-mandate, evidence-grounded — judges the rest as **honest
  model judgment, explicitly not claimed deterministic** (default refuted). The skill states that the
  echo chamber is closed *upstream* by the claim-blind verifier, not by the adjudicator. AC5 + sketch
  stage 4 + the engine linter follow. (Option A's rigid claim taxonomy was declined.)
- **AR-3 (est-cost + failed record).** `/deep-audit-run` step 4 manifest validation now asserts
  **est-cost equality** (Σ in-scope `estTokens`), not just cardinality; and a failure writes a durable
  **`reviews/audit-run-<date>.failed.json`** (stage that failed + per-row reached state) so a run that
  failed midway is distinguishable from one that never began — without publishing a partial findings
  report. AC7 + the hard constraint + sketch stage 5 + the engine linter follow. (The full unified
  run-artifact was declined for slice 1.)



AC → file map:

- **AC1** (skill + frontmatter, stand-down, approval guard) → `.claude/skills/deep-audit-run/SKILL.md`
  (steps 0–1).
- **AC2** (source-identity gate, deferred AC c) → `SKILL.md` step 2.
- **AC3** (executability gate, deferred AC b) → `SKILL.md` step 3.
- **AC4** (run manifest → fleet, DR-3) → `SKILL.md` step 4; `hidden-failure-unit-schema.json`.
- **AC5** (claim-blind evidence record + adjudication, DR-1) → `SKILL.md` step 5; `evidence-schema.json`.
- **AC6** (execution ledger synthesis, DR-2) → `SKILL.md` step 6; `audit-report-schema.json`.
- **AC7** (failure ≠ planned omission) → `SKILL.md` hard constraints + steps 4/6.
- **AC8** (contract handling) → `SKILL.md` "Contract handling"; `audit-report-schema.json`.
- **AC9** (read-only + posture + scope enumeration) → `SKILL.md` hard constraints; the In-scope file list.
- **AC10** (drift linter + gate) → `tests/deep_audit_engine_test.sh`; `.claude/workflow.json`;
  `.github/workflows/ci.yml`; `install.sh`.
- **Hand-off** (`/deep-audit` loud stop → point at the engine) → `.claude/skills/deep-audit/SKILL.md`;
  `tests/deep_audit_plan_test.sh` (pin update).

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

## Codex approach review (2026-07-26, base main, HEAD e36b9d5 — re-review round 2)

Artifact: `reviews/deep-audit-engine.approach.json`. Re-review after the accepted AR-1/2/3 redesign.

**Verdict:** *"The accepted AR-2 hybrid adjudication and AR-3 durable failure record are sound, and
AR-1 now uses one fingerprint contract. I would retain this architecture, but three new contract
defects should be resolved before future lenses copy it: run IDs omit part of row identity, the
est-cost check is tautological, and the fingerprint misses executable-mode changes."*

The redesign is **confirmed sound** on the AR-1/2/3 axes; these are **new** one-way defects the
reshaped contracts exposed (not re-raises). Both drift linters pass — they check wording, not these
semantics, so they could not have caught them.

### BLOCKER

- **RR2-1 — Run IDs omit lens and altitude** — *one-way · kludgy.* (locus `deep-audit-run/SKILL.md`
  step 4.) The run-record is correctly keyed by `(row identity, unitId, pass)`, but `runId` is built
  as `<scope>::<unitId>::p<pass>` — **dropping lens + altitude.** Latent in slice 1 (one lens), but
  when lenses 2–4 add another L1 lens over the same scope+unit, their run IDs, stable artifacts,
  finding IDs, and report provenance **collide** — a defect baked into the reusable fleet contract.
  **Alternative:** `runId = <lens>::<altitude>::<scope>::<unitId>::p<pass>` (or a canonical hash of
  the full identity), keeping the structured fields alongside. **Win:** no cross-lens artifact
  overwrites, no per-lens collision handling later — one canonical identity rule.

### IMPORTANT

- **RR2-2 — Manifest cost validation compares a subtotal to itself** — *one-way · kludgy.* (locus
  `deep-audit-run/SKILL.md` step 4; `deep-audit/SKILL.md` steps 5–6.) The AR-3 est-cost check
  compares `Σ in-scope estTokens` to the plan's in-scope `estTokens` subtotal — **the same row fields
  on both sides.** The plan semantic check verifies `totals = Σ rows` but **never** `row.estTokens =
  row.runs × per-run cost`, so a plan with arbitrary internally-summed prices passes both gates: the
  accepted est-cost check **establishes no new invariant.** **Alternative:** record the per-run token
  estimate as a **structured plan constant**, require every row's `estTokens = runs × tokensPerRun`,
  assign that cost to each manifest record, and compare the manifest-record sum to the approved
  subtotal (no unified run artifact needed). **Win:** turns a tautology into one enforceable pricing
  invariant; kills malformed-price plans and future per-lens cost drift.

- **RR2-3 — Content fingerprint ignores executable-mode changes** — *one-way · nonstandard.* (locus
  `deep-audit/SKILL.md` step 2; `deep-audit-run/SKILL.md` step 2.) The canonical stream is path +
  `git hash-object` (content bytes) **only** — a tracked script can gain/lose its **executable bit**
  with no digest change, so the engine can accept a target whose runtime behaviour no longer matches
  the approved state. **This repo has tracked executable scripts**, so it's material, not theoretical
  — a **fail-open** source-identity path. **Alternative:** define the fingerprint over a canonical,
  NUL-safe tracked-entry stream carrying path + working-tree **mode** (at least the exec bit) +
  content hash + an explicit deletion marker; use the **identical helper** in plan and engine. **Win:**
  closes the fail-open path while keeping the single-fingerprint mechanism; one shared helper removes
  the duplicated shell-format assumption.
