Date: 2026-07-27 · Branch: claude/deep-audit-lib · Status: approved

# deep-audit-lib — the tested deterministic core (one shell library)

## User story (OPS-14 frame)

> **As** someone who acts on a deep-audit's output (approves its plan, reads its report), **I want**
> the audit's determinism, completeness, pricing, and coverage claims to be **mechanically enforced —
> executable code with behavioral tests — not asserted in prose**, **so that** I can trust the plan
> and report as contracts instead of hoping the wording matches the mechanism.

Yardstick: a rule that lives only in prose, or a check that can't reject the input it's meant to
exclude, fails this story even if the wording is present.

## Problem

The `deep-audit-engine` review loop surfaced **14 findings across 4 rounds** that a skeptical read
collapsed onto **one root disease: claims asserted in prose with nothing to enforce them** —
duplicated facts that drift (the fingerprint, the unit-resolution rule, the pricing, the adjudication
rule each lived in ≥2 places, no cross-check), vacuous guards (a tautological est-cost check, a
subset-not-exact gate, an empty report that validates as `complete`), and properties asserted but
never established (deep run count, unique runId, "deterministic"). They persisted because **the drift
linters pin prose *presence*, not behavior** — 96/96 green while a schema contradicted the skill. The
full journey + analysis is preserved in [reviews/deep-audit-engine.md](reviews/deep-audit-engine.md)
(carried forward; that story is parked, its prose engine superseded).

Thomas's decision (2026-07-27): **extract the deterministic core into one tested shell library**
(`full boundary` — the lib owns the plan *compiler*, not just the checks; `lib-first` — this
foundational story before the engine is rebuilt on it). Shell **is** this estate's real code
(`install.sh`, the linters), under the standard `shellcheck` + `shfmt -i 2 -ci` in CI. This is OPS-15
("prompt-instructions are code") resolved for the one place it truly bites: the audit's algorithms.

## In scope

**Scope: the plan-side slice (Option B).** The execute-side subcommands are deferred to the engine
story (Non-goals).

- **`deep-audit-lib.sh`** — one subcommand-dispatched Bash library, deployed by `install.sh`, under
  the estate shell standard. Plan-side subcommands (the deterministic core):
  - `fingerprint <root>` — mode-aware, NUL-safe source digest (working-tree exec bit + content,
    excluding `reviews/**`).
  - `resolve-units <depth> <codeUnitId…>` — the **exact** resolution (standard/deep = full ordered;
    light = the every-3rd sample).
  - `compile-plan <target-root> <profile.json> [patches]` — the **Table-P compiler**. It **derives
    the deterministic inputs (fingerprint, unit-map, signals) from the target itself** (LV-1); the
    only LLM-supplied input is the detection `profile` (ecosystems/domain). Emits the full structural
    plan (phased emit→resolve→transform, resolution, pricing `= runs × tokensPerRun`); deterministic
    and replayable.
  - `check-plan <plan.json>` — the **canonical validator** (LV-3): it enforces **shape** (required
    fields, types, enums, `additionalProperties`) **in the lib** (no external schema gate),
    **completeness** by **recompiling from the *target* via `compile-plan`** (authoritative inputs,
    not the plan's own echoed `unitMap` — LV-1) and comparing the compiler-owned structural
    projection, **and** consistency (identity uniqueness, `totals = Σ`, `runs = |unitIds| × factor`,
    `estTokens = runs × tokensPerRun`, `unitIds` = the exact resolution). Nonzero exit on any
    violation.
- **A behavioral test suite** `tests/deep_audit_lib_test.sh` — feeds **tampered fixtures** and asserts
  **nonzero exit** for each defect class; wired into `workflow.json` `testCommand` + `ci.yml`.
- **Refactor `/deep-audit`** to **call** the lib (`fingerprint`, `compile-plan`, `check-plan`) instead
  of restating the algorithms in prose — single-sourcing Table P; update its drift linter to reference
  the lib and `absent`-check the duplicated rule prose.
- **`plan-schema.json` is retired as a gate (LV-3):** the lib's `check-plan` is the canonical
  shape+semantic contract; the standalone Draft-7 file is **removed** (regenerable later if external
  tooling ever needs it). The contract fields the tests need (`source.contentFingerprint`,
  `tokensPerRun`) are **computed/checked by the lib**, not a hand-maintained schema — superseding the
  parked engine branch's prose versions.

## Non-goals

- **The execute-side of the lib** (`build-manifest`, `check-report`, `adjudicate`, the capability
  table) — **deferred to the engine story** (Option B, LV-2): they are engine integration contracts,
  built + tested **there, with their live consumer** (`/deep-audit-run`), added to this same library.
- **The engine / orchestration** — no Workflow fan-out, finder/verifier prompts, judgment-tier
  adjudication, or synthesis. That is the rebuilt `deep-audit-engine` story.
- **New lenses** (security/test-adequacy/architecture) or altitudes — the capability table starts at
  `hidden-failure@L1`; adding a lens later edits **only** that table.
- **Changing what `/deep-audit` decides** — the refactor preserves its behavior (same plans for the
  same inputs); it moves the *implementation* from prose to the lib, it does not re-open Table P.
- **The differential C-ledger mode** — stubbed contract fields only, as before.

## Acceptance criteria

1. **`deep-audit-lib.sh` exists**, subcommand-dispatched, deployed via `install.sh`'s `ARTIFACTS`,
   and passes `shellcheck --severity=warning` + `shfmt -d -i 2 -ci`. An unknown subcommand exits
   nonzero with a usage message.
2. **`fingerprint`** emits the mode-aware NUL-safe digest over non-`reviews/**` tracked working-tree
   content; it is **deterministic**, **changes** on a content edit or an (unstaged) exec-bit flip, and
   is **unchanged** by a `reviews/**` edit — each asserted behaviorally.
3. **`resolve-units`** returns the full ordered list for `standard`/`deep` and the every-3rd sample
   (indices 0,3,6,…) for `light`; asserted on fixtures incl. boundary counts.
4. **`compile-plan` derives its deterministic inputs from the target (LV-1).** Given `(target-root,
   detection profile, normalized patches)` it computes the **fingerprint, unit-map, and signals from
   the target itself** (only the `profile` is external) and emits a plan whose rows are exactly Table
   P's output (phased emit→resolve→transform, patches in order, pricing `= runs × tokensPerRun`);
   recompiling the same target+inputs yields an identical structural plan.
5. **`check-plan` is the canonical validator (LV-3) and proves completeness against the target
   (LV-1).** It rejects, with a nonzero exit: **malformed shape** (missing required field, wrong
   type, bad enum, extra property — validated *in the lib*, no external schema); **incompleteness**,
   by **recompiling from the target via `compile-plan`** (authoritative inputs — *not* the plan's own
   echoed `unitMap`) and comparing the structural projection, so an **omitted mandatory row**, a
   **suppressed upgrade**, a **misapplied patch**, or **source drift** (`contentFingerprint` mismatch)
   is caught; and **inconsistency** (identity uniqueness, `totals = Σ`, `runs = |unitIds| × factor`,
   `estTokens = runs × tokensPerRun`, `unitIds` = the exact resolution). Zero exit on a valid plan.
6. **Behavioral gate.** `tests/deep_audit_lib_test.sh` asserts **nonzero exit** for every tampered
   fixture in ACs 2–5 (bad shape, missing/suppressed/misapplied row, wrong totals,
   `estTokens≠runs×const`, dup identity, wrong resolution, fingerprint drift) and **zero** for the
   valid ones; wired into `workflow.json` `testCommand` and the `ci.yml` gate. (This is the net the
   prose-pin linters could never be.)
7. **`/deep-audit` calls the lib; the schema is retired (LV-3).** The plan-stage algorithms
   (fingerprint, compile, validate) are **invoked from the lib**, not restated; **`plan-schema.json`
   is removed** (the lib is the canonical contract); `deep_audit_plan_test.sh` references the lib and
   `absent`-checks the duplicated algorithm/schema prose. A smoke `/deep-audit` compile is validated
   by `check-plan` returning 0.
8. **Posture + scope containment.** Read-only against any audited target except the plan artifacts;
   secret redaction inherited (detector/type · path:line · count, never a value).
   `git diff --name-only main...HEAD` shows no file beyond the enumerated set **and files under
   `reviews/`**: `.claude/skills/deep-audit-lib.sh`; `.claude/skills/deep-audit/SKILL.md` (refactor);
   `.claude/skills/deep-audit/plan-schema.json` (deletion); `tests/deep_audit_lib_test.sh` (new);
   `tests/deep_audit_plan_test.sh` (lib-reference + absent-checks); `.claude/workflow.json` +
   `.github/workflows/ci.yml` (gate wiring); `install.sh` (deploy the lib).

## Test notes

- **AC1** — `shellcheck`/`shfmt` in CI; an unknown-subcommand fixture exits nonzero.
- **AC2–AC5** — each is a **behavioral** assertion in `tests/deep_audit_lib_test.sh`: build a small
  fixture git repo (for `fingerprint`/`compile-plan`) and valid + tampered plan JSON, run the
  subcommand, assert exit status and (where relevant) output. Every tampered case asserts **nonzero**;
  the valid case asserts **zero**. `check-plan`'s completeness cases (missing/suppressed/misapplied
  row) are built by compiling a valid plan then mutating it, and asserting `check-plan` rejects the
  mutation because the target recompile disagrees.
- **AC6** — the suite runs under the existing gate; a deliberately-broken fixture makes it fail.
- **AC7** — `deep_audit_plan_test.sh` greps the skill for `deep-audit-lib.sh` invocations,
  `absent`-checks the duplicated algorithm prose, and confirms `plan-schema.json` is gone; a smoke
  `/deep-audit` compile is validated by `check-plan` returning 0.
- **AC8** — `git diff --name-only main...HEAD` shows only the enumerated files plus `reviews/`.

## Open questions (for the consult)

1. **Sub-slice — build the execute-side now, or with the engine?** `build-manifest` / `check-report`
   / `adjudicate` / the capability table are **engine-side** (consumed by `/deep-audit-run`, which
   doesn't exist yet). Building them here means testing-against-fixtures before a live consumer.
   *Option A (as drafted):* build **all** of the lib now, tested against fixtures; the engine story
   just wires them. *Option B (trim):* this story ships the **plan-side** (`fingerprint`,
   `resolve-units`, `compile-plan`, `check-plan`) + the `/deep-audit` refactor + tests — proven by a
   real consumer — and the execute-side functions land **with the engine story** (built + tested where
   consumed). **Recommendation: B** — each function ships with a live consumer, no speculative
   fixtures, and the lib grows naturally; it also right-sizes an already-large story. Your call, since
   you listed the execute-side in the brief.
2. **Library layout — one `deep-audit-lib.sh` (subcommand dispatch) vs a sourced function file?** Lean:
   subcommand CLI (`deep-audit-lib.sh <cmd> …`), so both skills invoke it as a process and the tests
   drive it as a black box (true behavioral testing). Tradeoff: process-per-call overhead (negligible
   at these scales).
3. **`compile-plan` inputs.** Does the lib compute the unit-map + signals itself (from the target repo)
   or receive them as JSON from `/deep-audit`'s recon? Lean: the lib computes the **deterministic**
   unit-map + signals (git-derived — churn, sensitive-path, untested, legacy, chunking), and receives
   only the **detection profile** (ecosystems/domain — the genuinely LLM recon) as input. That puts
   *all* deterministic derivation in the tested lib.
4. **`jq` vs `python3`** for JSON in the lib. Both are already present; `jq` is already a workflow
   dependency (`install.sh`, `/close`). Lean: `jq`.

## Design sketch — HOW

- **One CLI library, one source of each fact.** `deep-audit-lib.sh <subcommand> [args]`, dispatched by
  a `case`; deployed to `~/.claude/skills/` beside the skills (a shared location both `/deep-audit` and
  the later `/deep-audit-run` reference). Every deterministic rule — the fingerprint stream, the
  resolution formula, Table P, the pricing identity, the capability table, the adjudication map —
  exists **exactly once**, here.
- **Compilation from the target, not just validation (PV-1 / LV-1).** `compile-plan` *is* Table P in
  code and **derives its own deterministic inputs from the target** — the fingerprint, the unit-map,
  and the signals (churn / sensitive / untested / legacy, chunking) via git plumbing — taking only the
  detection `profile` as external (phase A emit → phase B resolve/upgrade → phase C transforms;
  patches normalized + applied in order; `resolve-units` per row; `estTokens = runs × tokensPerRun`).
  `check-plan` **recompiles from the target** (authoritative — never the candidate plan's echoed
  `unitMap`) and compares the structural projection, so "which rows must exist" is proven, not
  asserted, and a tampered plan can't validate itself. `/deep-audit` becomes: detect profile →
  `compile-plan` → consult → on approval `check-plan`. Only narrative (`omissionRisk`, `why`) is
  LLM-authored.
- **JSON in, exit status out; the lib is the *whole* contract (LV-3).** Subcommands read/emit JSON
  (via `jq`) and **exit nonzero on any violation** — the skills' prose is "run `deep-audit-lib.sh
  check-plan <f>`; nonzero ⇒ STOP loudly." `check-plan` validates **shape**
  (required/types/enums/`additionalProperties`, in the lib) **and** semantics, so a zero exit means
  valid on both axes. The standalone `plan-schema.json` is **removed** — a second handwritten shape is
  the very duplication this story kills; the lib is the single contract, and no rule is restated in
  prose.
- **Behavioral tests are the contract.** `tests/deep_audit_lib_test.sh` is a real xUnit-style shell
  suite: construct fixtures (a tiny git repo for `fingerprint`/`compile-plan`; valid + tampered plan
  JSON), invoke subcommands, assert exit codes/outputs. Tampered-input rejection is the acceptance
  signal — the thing prose-presence linters structurally cannot check.
- **Execute-side deferred (LV-2).** `build-manifest`, `check-report`, `adjudicate`, and the
  lens×altitude capability table are *not* built here; they extend this same lib in the engine story,
  with their live consumer. (Their designs — full-identity `runId`, ledger=plan-rows, typed
  `claimClass` — are recorded in the parked engine story for that build.)
- **Leans on / reuses:** `git` plumbing (`ls-files -z`, `hash-object`), `jq`, `shellcheck`+`shfmt`
  (estate standard), the existing linter/test harness pattern, `install.sh`'s `ARTIFACTS` deploy. The
  fingerprint + resolution + pricing + report-ledger designs are inherited from the parked engine
  story (now made real + tested). **New:** the library itself, its behavioral test suite, and the
  `/deep-audit` refactor from prose-algorithms to lib-calls.

## Codex design review (2026-07-27)

Artifact: `reviews/deep-audit-lib.design.json`.

**Verdict:** *"The overall shape is sound and proportionate: one Bash CLI is idiomatic for this
repository, jq is already an estate dependency, subprocess boundaries give both skills one
implementation, and behavioral fixtures address the actual failure generator. Reusing the compiler in
check-plan is not circular provided the checker independently reconstructs the compiler inputs from
the bound target… I would trim the first delivery to the plan-side consumer and close two contract
seams before implementation."*

Shape **confirmed**; three IMPORTANT findings, no blockers:

- **LV-1 — `check-plan` must re-derive from *authoritative* inputs (not the candidate plan)** —
  *one-way · nonstandard.* If `check-plan` recompiled using the plan's **own** echoed `unitMap`/
  `signals`, completeness would be **circular** — coherently tampered inputs+rows validate each other.
  **Alternative:** one internal compiler taking `(target root, recorded detection profile, normalized
  patches)` that **derives fingerprint + unit-map + signals from the target itself**; `check-plan`
  verifies `contentFingerprint`, recompiles from those authoritative inputs, and compares the
  compiler-owned structural projection. **Win:** one check rejects source drift, omitted rows,
  suppressed upgrades, and misapplied patches — without duplicating Table P. (Also settles Open
  question 3: the lib derives the deterministic unit-map+signals; only the detection *profile* is
  LLM input.)
- **LV-2 — Ship the plan-side slice first** — *two-way · nonstandard.* `build-manifest` /
  `check-report` / `adjudicate` / the capability table are **engine-side integration contracts** most
  likely to shift when the live engine is built; landing them now enlarges the story on **speculative
  fixtures** with no real seam. **Alternative:** Option B — ship `fingerprint`, `resolve-units`,
  `compile-plan`, `check-plan`, the `/deep-audit` refactor, and their tests now; add the execute-side
  to the same lib **in the engine story, with its live consumer.** **Win:** removes three unconsumed
  subcommands + their speculative fixtures while keeping the one-library architecture. (= this spec's
  Open question 1, Option B.)
- **LV-3 — Name the executable JSON-shape gate** — *one-way · nonstandard.* `jq` is not a Draft-7
  validator; "schemas own shape, exit status is the verdict" never says **how** shape is validated.
  Parse-checking alone admits malformed contracts; hand-restating required/types/enums in `jq`
  **recreates the duplicated-shape seam this story exists to remove.** **Alternative:** either (a)
  `check-plan` invokes **one declared JSON-Schema validator** against `plan-schema.json` before
  semantic recompilation (a new pinned dependency), **or** (b) make a **single canonical contract in
  the lib** and *generate* `plan-schema.json` from it (no second handwritten shape). **Win:** a zero
  exit means schema-valid **and** semantically complete, with only one shape definition.

## Design decisions (2026-07-27)

Thomas's frame-consult decisions — **binding on implementation**:

- **Scope — "plan-side slice (Option B)" (LV-2).** Build `fingerprint`, `resolve-units`,
  `compile-plan`, `check-plan` + the `/deep-audit` refactor + behavioral tests. The execute-side
  (`build-manifest`, `check-report`, `adjudicate`, capability table) is **deferred to the engine
  story**, added to this same lib with its live consumer.
- **Contract form — "lib is canonical, no new dep" (LV-3, one-way, ratified).** `check-plan` validates
  **shape + semantics** in the lib (jq/shell), tested behaviorally; **`plan-schema.json` is removed**
  (the lib is the single contract; regenerable later if external tooling needs it). No JSON-Schema
  validator dependency is added — the estate stays dependency-light (jq/git, non-admin friendly).
- **LV-1 — re-derive from the target (one-way, ratified, folded in).** `compile-plan` derives the
  fingerprint + unit-map + signals **from the target itself**; `check-plan` recompiles **from the
  target** (authoritative), never from the candidate plan's echoed `unitMap` — so completeness is
  non-circular and a tampered plan cannot validate itself. Settles Open question 3 (the lib owns all
  deterministic derivation; the LLM supplies only the detection profile).
- **Smaller opens (leans, no objection):** library layout = one subcommand-dispatched CLI (Open
  question 2); JSON tooling = `jq` (Open question 4).
