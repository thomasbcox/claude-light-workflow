# antipattern-lens — name the silent-failure anti-pattern in the reviewer contract

Date: 2026-07-15 · Branch: claude/antipattern-lens · Status: approved

## Problem

`AGENTS.md` (the independent-reviewer contract, read automatically by both codex passes) names
**over-engineering** and **reinvention / duplication** in its design lens — and the reviewer catches
those well. But the failure mode the research ranks #1 for AI-authored code is **silently swallowing
or degrading on failure**: bare / blind `except` / `catch`, catch-log-continue where propagation is
correct, silent fallbacks, deleted assertions or safety checks. Error-handling gaps run ~2× more
prevalent in AI-authored code, and the resulting failure is *silent* — the system continues in a
degraded state that nothing in the output makes visible.

Today that offender is covered only by the generic phrase "silent regressions, unsafe assumptions"
in the correctness list (`AGENTS.md:20`). It is **never named**, so:

- the reviewer is not pointed at the highest-frequency offender; and
- it **straddles both altitudes** — a design that hides failure is a *shape* flaw (approach pass), a
  swallowed exception in the diff is a *line* flaw (correctness pass) — so **neither pass owns it**.

Two supporting facts shape the fix:

1. **`AGENTS.md` is a prompt, not documentation.** Every line is reviewer context on *every* run.
   Instruction dilution is real (accuracy degrades as competing tasks pile up), but bounded — a
   controlled study found single-task prompts do *not* consistently beat multi-task prompts, and one
   sharp added item costs ~nothing. So the clause must be **tight**, and maintainer-facing rationale
   must **not** live here.
2. **The mechanical offenders are not the reviewer's job.** Bare `except`, `any`, dead code, unused
   imports/vars are caught deterministically, free, and with zero false positives by linters
   (Ruff `BLE001`/`E722`/`TRY`, ESLint `no-explicit-any`) — which `/dev-audit` Table A already
   recommends per-ecosystem. Putting an LLM on them is strictly worse. Only the **judgment** half
   (does this *hide* failure?) belongs in the contract.

A dedicated anti-pattern review pass ("option B") was evaluated and is **deliberately not being
built now** — it is filed as an optional roadmap item with its suggested shape and an escalation
trigger (see In scope #4 and the Design sketch).

## In scope

1. Add a **single named bullet** to `AGENTS.md`'s **correctness** list covering the silent-failure
   anti-patterns (swallowed / blind exception handling, catch-log-continue where propagation is
   correct, silent fallbacks, deleted assertions or safety checks).
2. Add a **single named bullet** to `AGENTS.md`'s **design / approach** list establishing that a
   design which hides or degrades on failure is a *shape* flaw, not merely a line bug — so the
   approach pass owns it at its altitude too.
3. Keep both additions **tight** (one bullet per altitude, no new section, no maintainer-facing
   meta-prose) — the dilution budget is the point, not an afterthought.
4. File **option B** in `BACKLOG.md` as an **optional roadmap item**, recording: its suggested shape,
   the concrete escalation trigger, and the mechanical-vs-judgment boundary (why lint-catchable
   offenders are *not* going into the reviewer contract).
5. Add **minimal drift assertions** to `tests/reviewer_test.sh` — one per altitude — consistent with
   that file's explicit "linter, not a behavioral gate" charter.

## Non-goals

- **Building option B** (a dedicated anti-pattern pass). Filed, not built. See Design sketch for the
  shape being recorded.
- **Wiring the `llm` reviewer backend.** B's suggested shape depends on it; B is not being built, so
  the backend stays unwired and its "not yet wired" stop is untouched.
- **Changing `finding-schema.json` / `design-review-schema.json`.** The existing `severity` +
  `claim` / `suggestion` (and `alternative` / `win`) fields already carry these findings. No schema
  change is needed or wanted.
- **Changing the `frame` / `review` / `close` skill prompts.** They already delegate to
  `AGENTS.md` ("You are the independent reviewer defined in AGENTS.md"), so the clause lands without
  touching them.
- **Changing `install.sh`.** `AGENTS.md::workflow-AGENTS-template.md` is already in `ARTIFACTS`
  (`install.sh:28`) — propagation to new repos is free.
- **Adding lint rules to this repo's gate or CI.** Per the estate standard, linters belong in CI and
  local gates stay dependency-light; `/dev-audit` already recommends them per-ecosystem. Separate
  concern, separate story if ever wanted.
- **Growing `tests/reviewer_test.sh` into a behavioral suite.** Its header forbids it; two `has`
  assertions is the whole test surface.

## Acceptance criteria

1. `AGENTS.md`'s **correctness** bullet list (under "Your role") gains **exactly one** new bullet
   naming the silent-failure anti-patterns: swallowed / blind exception handling, catch-log-continue
   where propagation is correct, silent fallbacks, and deleted assertions / safety checks.
2. `AGENTS.md`'s **design / approach** bullet list (under "Your role") gains **exactly one** new
   bullet establishing that a design which hides or degrades on failure is a shape flaw.
3. **Tightness holds:** AC1 and AC2 each add exactly one bullet; `AGENTS.md` gains **no new
   section/heading**, and **no maintainer-facing meta-prose** (rationale, tool names, lint-rule ids,
   or "why we did this") is added to it.
4. `BACKLOG.md` gains an **optional roadmap item** for option B recording all three of: (a) its
   suggested shape, (b) the concrete escalation trigger, (c) the mechanical-vs-judgment boundary.
5. `tests/reviewer_test.sh` gains **exactly two** new assertions — one per altitude — each a `has`
   drift check against `$AGENTS`, and no new helper, parser, or block-scoped machinery.
6. The gate (`.claude/workflow.json` → `testCommand`) is green.
7. **Scope containment:** the diff touches only `AGENTS.md`, `BACKLOG.md`, `tests/reviewer_test.sh`,
   `reviews/antipattern-lens.md`, and `reviews/antipattern-lens.design.json`.

## Test notes

- **AC1 / AC2** — read `AGENTS.md`; confirm each list gained its one named bullet, and that the
  correctness bullet enumerates the four named offenders while the design bullet frames hiding
  failure as a *shape* flaw.
- **AC3** — `git diff main...HEAD -- AGENTS.md`: confirm the added lines are exactly two bullets,
  that no line added starts a new `##` heading, and that no added line is rationale/tooling prose.
- **AC4** — read `BACKLOG.md`; confirm the roadmap item is present and that (a) shape, (b) trigger,
  (c) boundary are each explicitly stated.
- **AC5** — `git diff main...HEAD -- tests/reviewer_test.sh`: confirm exactly two added `has …
  "$AGENTS" …` lines and no other additions.
- **AC6** — run the configured `testCommand`; it must exit 0.
- **AC7** — run `git diff --name-only main...HEAD` and verify no files appear beyond those the AC
  enumerates.

## Open questions

> **Both resolved 2026-07-15 — see [Design decisions](#design-decisions-2026-07-15).** Kept here as
> the record of what was asked and what was recommended before the reviewer weighed in.

1. **What id / prefix does the option-B roadmap item get?** `BACKLOG.md` defines exactly three kinds
   — `BUG-` (skill-behavior *defects*), `OPS-` (deployment / shipping ergonomics), `AUDIT-`
   (graduated `/dev-audit` findings). Option B is **none of them**: it is an *enhancement to skill
   behavior*, which the taxonomy has no home for. `BUG-` is the right domain but the wrong nature
   (it is not a defect, and it would pollute the defect list); `OPS-` is the wrong domain (it does
   not change how skills are *shipped*), though `OPS-9` sets a loose precedent as an
   "evaluate-and-decide" item. Options:
   - **(a) New `RFC-` prefix + a `## Roadmap (optional)` section** — cleanest fit, honest taxonomy.
     **But adding a prefix is a cross-cutting pattern future items will copy ⇒ a one-way door
     needing your ratification.** *(recommended)*
   - **(b) Stretch `OPS-11`** — no taxonomy change; mislabels the item's domain.
   - **(c) Stretch `BUG-6`** — right domain, but asserts a defect that does not exist.

   **Recommendation: (a).** It names the gap honestly rather than hiding an enhancement inside a
   defect or shipping list. Needs your ratification as a one-way door.

2. **Should the `## Roadmap (optional)` section sit above or below `## Done`?** Cosmetic, two-way —
   Claude's call unless you say otherwise. Default: **above `## Done`**, below the OPS section, so
   open work stays together and the historical sections stay at the bottom.

## Design sketch — HOW

**The lever is one file.** `AGENTS.md` is (i) this repo's reviewer contract, (ii) the deploy source
for `~/.claude/workflow-AGENTS-template.md` that `/frame` copies into new repos (`install.sh:28`),
and (iii) read automatically by all three codex prompts, which delegate to it by name rather than
restating the lens. So a bullet added there reaches **both altitudes, every backend, and every
repo** with no skill-prompt edit, no schema change, and no `install.sh` change. Nothing else in the
change is load-bearing.

**Placement, per altitude** — both under the existing "Your role" section, appended to the lists
already there:

- **Correctness list** (`AGENTS.md:20-21`) — today: "drift from the spec, missed edge cases, silent
  regressions, unsafe assumptions, security / permission / data-loss risks, incorrect business
  logic." The new bullet makes the *named* case that "silent regressions" only gestures at.
- **Design / approach list** (`AGENTS.md:22-26`) — today: reinvention, bespoke per-case code,
  over-complexity, "code that should not exist." The new bullet adds *hiding failure* as a shape
  flaw, so the approach pass can block a design that swallows errors before correctness ever
  reviews a line.

**The dilution budget is the design constraint.** `AGENTS.md` is a **prompt, not documentation** —
every line is reviewer context on every run, and the research on instruction dilution is exactly why
this is one bullet per altitude and not a checklist. Two consequences, both deliberate:

- **No maintainer-facing prose in `AGENTS.md`.** The mechanical-vs-judgment boundary (why bare
  `except` / `any` / dead code go to linters, not the reviewer) is *rationale for maintainers*, not
  instruction for the reviewer. It would spend reviewer context on every run to answer a question
  the reviewer never asks. Its home is `BACKLOG.md`, next to option B — where someone asking "should
  we teach the reviewer to catch bare excepts?" will actually look.
- **No new section.** A heading invites future growth into the checklist the dilution research warns
  against.

**Option B — the shape being filed** (recorded in `BACKLOG.md`, not built):

> A dedicated anti-pattern pass whose sole instruction is hunting anti-patterns / weak error
> handling. **Shape:** wire it as the **`llm` backend** — non-agentic, inherently read-only (no file
> tools ⇒ no sandbox/worktree), cheap narrow model, one focused prompt, schema-valid JSON natively —
> run as an **independent critic**, *not* as a third sequential codex stage. **Rationale:** the
> multi-agent evidence (≈87% fewer false positives, ≈3× more real bugs) is a *parallel
> independent-critic* result; the same literature shows sequential **handoffs hurt reliability**
> (Azure SRE reversed course) and multi-agent costs 4–220× the tokens. A third chained stage would
> pay B's tax while collecting little of B's upside — and would cut against the loop's lightweight
> identity. **Escalation trigger (the thing that makes B worth building):** *observed* dilution —
> after this story lands, the correctness pass demonstrably missing silent-failure because it is
> already carrying spec-drift + edge cases + security + data-loss. Build B on evidence, not on a
> hunch. **Boundary:** B covers only the *judgment* half; the mechanical offenders stay with linters
> in CI, surfaced by `/dev-audit` Table A.

**Testing.** `tests/reviewer_test.sh` is explicitly *"a linter, not a behavioral gate"* — its header
forbids growing it into a pseudo-behavioral suite, and it already asserts `AGENTS.md` content
(lines 76–77). The change is in-band: **two** `has` drift checks, one per altitude, keyed on a short
stable phrase. There is no oracle for "did the reviewer actually catch a swallowed exception" — that
verification lives, by design, in the reviewer's own diff review and a human reading the contract.
Anything more here would be theater.

## Codex design review (2026-07-15)

**Verdict:** *"The two contract bullets and two presence-only drift assertions are a sound,
proportionate design. However, option B's roadmap shape conflates a review pass with a reviewer
backend, and the proposed singleton RFC taxonomy is unnecessary cross-cutting machinery. I would
revise those parts before approving the sketch."*

The core of the story — the two `AGENTS.md` bullets and the two drift assertions — was **blessed**.
Both findings target the *periphery*: option B's recorded shape, and the backlog id question.

### IMPORTANT

**1. Option B conflates a pass with a backend** · `one-way` × `kludgy` · *locus: Design sketch — Option B*

- **Claim:** the existing `llm` seam selects an alternative **backend** for the *established*
  design/approach and correctness passes. Option B is a new, **additional** pass. Calling it "the
  `llm` backend" gives one abstraction two meanings and makes configuration, dispatch, artifacts,
  and future backend support ambiguous.
- **Alternative:** describe B as an optional **parallel anti-pattern critic pass**, separate from
  backend selection. When built, let it use the normal reviewer adapter — or explicitly configure an
  `llm` *provider* for that pass — without redefining what the `llm` reviewer *backend* means.
- **Win:** preserves one backend-selection invariant; avoids a second dispatch meaning and a
  provider-coupled pass design; lets the focused critic reuse the eventual `llm` context/schema
  harness instead of creating parallel orchestration semantics.

**2. A new RFC taxonomy is too much structure for one deferred idea** · `one-way` × `kludgy` · *locus: Open questions — option-B roadmap id*

- **Claim:** adding an `RFC-` prefix and a new backlog section for a single optional,
  evidence-triggered idea expands a convention that currently defines exactly three kinds. That is
  disproportionate for explicitly deferred work and conflicts with the repo's lightweight bias.
- **Alternative:** record option B as `OPS-11`, following the existing `OPS-9` evaluate-and-decide
  precedent, and state plainly that it is reviewer-tooling *evaluation*, not committed work. Revisit
  the taxonomy only if multiple architectural proposals accumulate.
- **Win:** avoids a new cross-cutting naming convention and section; keeps the change to one backlog
  item; preserves the option to introduce a real roadmap taxonomy when more than one item justifies
  it.

## Design decisions (2026-07-15)

**Scope — approved as specified.** Thomas: *"Approve as specified"* — all 7 ACs stand, including
both `AGENTS.md` bullets. The design bullet (AC2) was explicitly considered for cutting and
**kept**: the correctness pass is already the heaviest prompt in the system, the design lens is
less loaded, and the approach pass **gates** correctness — so the design bullet is the one that
lets a failure-hiding *shape* be blocked before correctness ever reads a line. Cutting it would
have forfeited the two-altitude architecture's existing leverage.

**Finding 1 — Option B conflates a pass with a backend · FIX.** Accepted; the reviewer is right and
the sketch was wrong. The `reviewer: {codex, llm}` seam selects a **backend** for the *existing*
passes; option B is a **new pass**. Overloading `llm` would give `reviewer: llm` two meanings.
**Binding on implementation:** `BACKLOG.md` records B as an optional **parallel anti-pattern critic
pass**, orthogonal to backend selection — it may *use* an llm provider when built, without
redefining what the `llm` reviewer *backend* means. Pass and backend stay two axes.

**Finding 2 — new `RFC-` taxonomy · FIX → `OPS-11`.** Accepted; the reviewer's proportionality
argument beat the spec's. Two things decided it:
- **`OPS-9` is a direct precedent, not a stretch.** It is a *parked evaluate-and-decide* item
  ("nothing is strictly missing… not a known gap"). B is identically shaped: parked, uncommitted,
  evidence-triggered. The nature matches exactly; only the domain label is loose.
- **Reversibility asymmetry.** `OPS-11` is a **two-way** door (rename one line). A new `RFC-` prefix
  is **one-way** — a 4th kind in a documented taxonomy that future items copy. Doctrine says take
  the two-way option and let evidence force the one-way one later; this is the OPS-6
  *deferred-until-needed* pattern.

Also noted: the "taxonomy has a gap for enhancements" premise behind `RFC-` **did not hold**. The
backlog is a *parking lot for deferred work*, not the enhancement inflow — recent enhancements
(`markdown-row`, `shell-tooling`, `drop-shipped-tag`, `pluggable-reviewer`) went straight to
`/frame` with no id at all. B needs an id only because it is parked.

**Binding on implementation:** no new prefix, no new `## Roadmap` section. B is `OPS-11` under the
existing *Deployment & tooling improvements* section, framed as reviewer-tooling **evaluation**, not
committed work. **Open question 2 (section placement) is therefore moot** — there is no new section.
If a *second* parked enhancement ever appears, that is the signal to revisit the taxonomy, designed
from two data points rather than one.

## Build note (2026-07-15)

| AC | Where it landed |
|---|---|
| AC1 — correctness bullet names the hidden-failure offenders | `AGENTS.md` — `**Hidden failure:**`, nested under the existing **Correctness** bullet |
| AC2 — design bullet frames hiding failure as a shape flaw | `AGENTS.md` — `**Hiding failure is a shape flaw…**`, nested under the existing **Design / approach** bullet |
| AC3 — tightness (one bullet per altitude, no new section, no meta-prose) | `AGENTS.md` — constraint, not a location; the two nested bullets above are the whole addition |
| AC4 — option B filed with shape + trigger + boundary | `BACKLOG.md` — `OPS-11`, under *Deployment & tooling improvements*, after `OPS-9` |
| AC5 — two drift assertions, one per altitude | `tests/reviewer_test.sh` — new `== drift: the hidden-failure lens is named at both altitudes ==` group |
| AC6 — gate green | no file — the configured `testCommand` |
| AC7 — scope containment | no file — `git diff --name-only main...HEAD` |

**Nesting note (AC1/AC2).** Both bullets are **nested sub-bullets** under the two existing
altitude bullets in *Your role*, rather than new top-level entries. That list is structured as
*one bullet per altitude* ("what to hunt, here"); a third top-level bullet would have had no
altitude to belong to, and a new heading was ruled out by AC3. Nesting keeps each addition
visibly scoped to the altitude that owns it — which is the whole point of the change, since the
offender straddles both.

**No `install.sh` change (by design).** `AGENTS.md::workflow-AGENTS-template.md` is already in
`ARTIFACTS` (`install.sh:28`), so this repo's contract *is* the template `/frame` copies into new
repos. Both bullets propagate estate-wide on the next install with no deploy-set edit.
</content>
</invoke>
