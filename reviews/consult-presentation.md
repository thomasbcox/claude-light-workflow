# consult-presentation — how a decision is put to the human at the four stops

Date: 2026-07-15 · Branch: claude/consult-presentation · Status: approved

## Problem

The loop has **four mandatory stops** where it forces a decision from Thomas:

| Stop | Skill step | What it says to present |
|---|---|---|
| Frame consult | `/frame` step 7 | the spec, the design sketch, the reviewer's design findings; "Recommend a disposition per finding" |
| Approach menu | `/review` step 7 | the approach findings, "each with a recommended disposition derived from its tags" |
| Decision menu | `/review` step 9 | the correctness findings grouped by severity, "each with a recommended disposition (fix / defer / reject / answer)" |
| Re-review fork | `/close` step 4 | "re-review or merge?" |

**Every one of them specifies *what* to present and says nothing about *how*.** Two concrete
consequences, both observed on the `antipattern-lens` story (2026-07-15):

1. **No stop requires tradeoffs.** The word does not appear in any of the four. Menus that state
   what each option *does* — but never what it **costs** or **risks** — are fully compliant with the
   skills as written. Thomas had to ask "explain the tradeoffs" twice within a single decision.
2. **`/review` step 9 mandates an ungrounded recommendation.** Steps that recommend *from tags* are
   grounded: `/frame` step 7 and `/review` step 7 derive the disposition from reversibility ×
   standing, and `/close` step 4 recommends re-review from a named trigger list (money / security /
   auth / business logic / data-loss). But **`finding-schema.json` carries no tags** — only
   `severity`, `title`, `file`, `line`, `claim`, `suggestion`. So step 9's "recommended disposition"
   has **no derivation rule behind it**, which is an instruction to recommend reflexively.

Thomas's standing requirement (2026-07-15): **tradeoffs are always owed; a recommendation has to be
earned** — grounded in the purpose of the app and industry best practice, never in preference or in
a wish to appear decisive.

## The complication (why this story is not obviously worth doing)

On 2026-07-15 the general briefing rules were installed in **`~/.claude/CLAUDE.md`** — lead with
impact; use his shorthand but unpack it; always give tradeoffs; earn the recommendation; explain
mechanisms without dumping or hiding them; plain language.

That file **loads into every session**, and `README.md` says the workflow deploys "to every Claude
Code app on **this machine**" — the same machine. So the rules are already always present wherever
the loop runs, and restating them in the doctrine risks being exactly the **"third, drifting copy"**
this repo rejects elsewhere (the `CHANGELOG` doctrine; declared-vs-observed state).

Cutting the other way: `README.md` also states that **"the normative rules live in
`.claude/workflow-protocol.md`."** If how the loop consults its human is a *product* rule, its
declared home is the doctrine — and leaving it only in a personal preferences file makes the
product's correctness depend on a file outside the product, one that is free to be trimmed or
reworded at any time without the workflow knowing.

**This tension is the story's central question — see Open questions #1.** It is genuinely unresolved
and is the thing the design review should attack.

## In scope

1. Decide **whether and where** the consult-presentation rule lives (Open questions #1) — then
   implement the chosen shape.
2. Under the proposed shape (option **b**, below): extend the doctrine's **existing**
   `## Consult model (the two dials)` section with the *workflow-specific* presentation rule —
   tradeoffs unconditional, recommendations earned.
3. Give `/review` step 9's recommendation a **grounding rule**, since it has none today and its
   schema carries no tags to derive one from.
4. Add a one-line pointer at each of the four stops so the rule is visible where the decision
   actually happens.

## Non-goals

- **Restating `~/.claude/CLAUDE.md`'s general briefing rules in the doctrine.** Style — plain
  language, no cleverness, unpack the shorthand — is a property of *how Claude talks to Thomas
  everywhere*, not of this workflow. Duplicating it here creates the drift this repo exists to
  avoid.
- **Changing `finding-schema.json` or `design-review-schema.json`.** Adding tags to correctness
  findings to make step 9 derivable is a *much* larger change (it alters the reviewer's contract and
  every historical artifact's shape). If step 9 needs grounding, it can come from `severity` + the
  `claim`, which the schema already carries.
- **Changing what gets decided, or by whom.** The two dials (blocking = reversibility; assessment =
  best practice) are untouched. This story is about *presentation*, not authority.
- **Editing `~/.claude/CLAUDE.md`.** Already installed and out of this repo's tree.
- **`AGENTS.md`.** The reviewer's contract governs how the *reviewer* reports to Claude, not how
  Claude presents to Thomas. Untouched.

## Acceptance criteria

*(AC1–AC4 assume option **b** from Open questions #1. If Thomas selects a different option at the
frame consult, these change — the consult settles the shape before any implementation.)*

1. `.claude/workflow-protocol.md`'s **existing** `## Consult model (the two dials)` section states
   the presentation rule: **every option presented at a consult carries its cost and its risk
   (unconditional), and any recommendation must be earned** — grounded in the tags, the finding's
   severity + claim, the purpose of the app, or industry best practice — never reflexive.
2. The rule states its own **scope boundary**: it governs the *structure* of a consult
   (what an option must carry), not general communication style, which is not this document's job.
3. `/review` step 9 gains an explicit **grounding rule** for its recommended disposition, derived
   from what `finding-schema.json` actually carries (`severity` + `claim`) — no schema change.
4. Each of the four stops carries a **one-line pointer** to the rule: `/frame` step 7, `/review`
   steps 7 and 9, `/close` step 4.
5. **Tightness:** no new top-level section in `.claude/workflow-protocol.md` — the rule extends the
   existing `## Consult model` section; and no general-style prose is added (Non-goals #1).
6. The gate (`.claude/workflow.json` → `testCommand`) is green.
7. **Scope containment:** the diff touches only `.claude/workflow-protocol.md`,
   `.claude/skills/frame/SKILL.md`, `.claude/skills/review/SKILL.md`, `.claude/skills/close/SKILL.md`,
   and `tests/reviewer_test.sh` (if AC8 lands), **plus** the workflow's own
   `reviews/consult-presentation.*` trail artifacts (the story file + the design/approach/correctness
   JSON the loop writes), which are exempt — they are produced by `/frame` and `/review`, not product
   code.
8. **Drift assertions** (bounded): `tests/reviewer_test.sh` gains at most **two** `has` checks — one
   that the doctrine states the rule, one that a stop points at it — consistent with that file's
   "linter, not a behavioral gate" charter.

## Test notes

- **AC1/AC2** — read `.claude/workflow-protocol.md`; confirm the `## Consult model` section states
  both bars (tradeoffs unconditional, recommendation earned) and names its own scope boundary.
- **AC3** — read `/review` step 9; confirm the recommendation has a stated derivation from
  `severity` + `claim`, and that `finding-schema.json` is unchanged (`git diff` shows no schema file).
- **AC4** — grep each of the four stops for the pointer; confirm four hits, one per stop.
- **AC5** — `git diff main...HEAD -- .claude/workflow-protocol.md`: confirm no added line starts a
  new `##` heading, and no added line is general communication-style prose.
- **AC6** — run the configured `testCommand`; it must exit 0.
- **AC8** — `git diff main...HEAD -- tests/reviewer_test.sh`: confirm at most two added `has` lines.
- **AC7** — run `git diff --name-only main...HEAD` and verify no files appear beyond those the AC
  enumerates.

## Open questions

1. **Does this belong in the doctrine at all, now that `~/.claude/CLAUDE.md` carries the rules?**
   This is the story's load-bearing question; everything else follows from it.

   - **(a) Full rules in the doctrine.** Restate all six briefing rules in `workflow-protocol.md`.
     *Cost:* a second copy of rules that already auto-load on the only machine this runs on; if
     `CLAUDE.md` is ever reworded the two disagree and neither is authoritative. *Benefit:* the
     workflow is self-contained — correct even under a different user, machine, or a trimmed
     `CLAUDE.md`.
   - **(b) Consult-specific rules only** *(proposed — see Design sketch)*. The doctrine states only
     what is structural to a consult and absent from `CLAUDE.md`: **tradeoffs unconditional,
     recommendation earned**, plus step 9's missing grounding rule. Style stays in `CLAUDE.md`.
     *Cost:* the boundary between "structural" and "style" is a judgment call, and the rule set is
     then split across two files. *Benefit:* fixes the two defects actually observed without
     duplicating anything.
   - **(c) Pointer only.** The doctrine says "present per the briefing rules in `~/.claude/CLAUDE.md`."
     *Cost:* couples a deployable product to Thomas's personal preferences file, and `CLAUDE.md`
     auto-loads anyway — so the pointer buys close to nothing. *Benefit:* zero duplication.
   - **(d) Do nothing; record as decided-against.** *Cost:* the two observed defects stay in the
     product — no stop requires tradeoffs, and step 9 still mandates an ungrounded recommendation.
     Anyone following the skills literally reproduces the bad menus. *Benefit:* zero machinery,
     absolute DRY; `CLAUDE.md` already changes the behavior in practice.

   **No recommendation offered.** The `README` supports both readings — "deploy to every Claude Code
   app on *this machine*" (favouring d/c) and "the normative rules live in `workflow-protocol.md`"
   (favouring a/b). The design review should settle it; a recommendation from the author here would
   be a guess dressed as a reason.

2. **Is AC3 (step 9's grounding rule) severable?** It is the one defect that `CLAUDE.md` cannot fix
   — it is a skill instructing a reflexive recommendation, and no briefing rule overrides a skill
   step. If option (d) wins on the doctrine question, AC3 arguably **still** stands on its own as a
   narrow skill fix. Two-way; Claude's call unless Thomas says otherwise. **Default: keep AC3 alive
   independently of the option chosen.**

## Design sketch — HOW

**Proposed shape: option (b).** The doctrine gains only what is *structural to a consult and absent
from `CLAUDE.md`*; style stays where it already lives.

**Placement.** `.claude/workflow-protocol.md` already has `## Consult model (the two dials)`. Its two
dials — **blocking** (reversibility) and **assessment** (best practice) — both govern *what gets
decided and by whom*. **Nothing governs what an option must carry when it reaches the human.** The
rule extends that existing section rather than opening a new one (AC5): the section already owns
consults, so this is where a reader looks.

**The rule, in substance** (~3–4 lines, not a checklist):

> Every option presented at a consult carries its **cost** and its **risk**, not just what it does —
> unconditionally. A **recommendation must be earned**: grounded in the finding's tags, its severity
> and claim, the purpose of the app, or industry best practice. Where options are genuinely balanced,
> say so rather than manufacturing a pick. This governs the *structure* of a consult; general
> communication style is not this document's concern.

**Why the last sentence matters:** it is the seam that keeps this from becoming the drifting second
copy. It states out loud that the doctrine owns *consult structure* and not *how Claude writes*, so
a future editor knows what does **not** belong here.

**Step 9's grounding (AC3) — the one fix `CLAUDE.md` cannot make.** A briefing rule cannot override
a skill step that says "recommend a disposition per finding." Steps 7 (both skills) and `/close` 4
derive their recommendation from something real (tags; a named trigger list). Step 9 derives from
nothing, because `finding-schema.json` has no tags. Rather than add tags to the schema — which would
change the reviewer's contract and every historical artifact (Non-goals) — step 9 grounds in what the
schema **already carries**: `severity` (BLOCKER/IMPORTANT → recommend *fix*; QUESTION → *answer*;
NIT → *accept or defer*) plus the `claim` for anything the severity alone does not settle.

**Testing.** `tests/reviewer_test.sh` is explicitly *"a linter, not a behavioral gate"* — its header
forbids growing it into a pseudo-behavioral suite, and there is **no oracle** for "was the consult
well presented." At most two `has` drift checks (AC8), keyed on short stable phrases. The real
verification is the same as for every other instruction in this repo: the reviewer's own read, and
Thomas noticing when a menu is bad — which is precisely how this story was born.

**What this deliberately does not do:** no schema change, no `AGENTS.md` change, no change to who
decides what, and no restatement of style rules. The change is one doctrine paragraph, one grounding
rule, and four pointers.

## Codex design review (2026-07-15)

**Findings: none** (empty `findings` array). The sketch is sound. The reviewer was asked to attack
Open questions #1 directly and to name the option it would take.

**Verdict — it chose option (b):**

> *"Choose option (b). The consult contract is product behavior, so its structural invariants belong
> in the repo's normative doctrine even though Thomas's personal, auto-loaded CLAUDE.md currently
> produces similar behavior on this machine. The proposed boundary is sound: the doctrine owns what
> every workflow consult must contain — cost, risk, and an earned recommendation — while CLAUDE.md
> retains general communication style. This is justified overlap rather than a drifting second copy
> because the files have different authorities and scopes; options (c) and (d) would leave product
> correctness dependent on undeclared external state, while option (a) would duplicate unrelated
> style rules. Extending the existing Consult model, adding terse pointers at the four execution
> sites, and deriving step 9 dispositions from the existing severity + claim fields is compact,
> declarative, and consistent with the repository's instruction-driven design. No dependency or
> schema change would simplify it. AC3 is independently worth implementing even if Thomas rejects
> the doctrine addition, because the current step 9 explicitly requires a recommendation without
> defining how it is earned."*

Three things the reviewer settled:

- **The DRY objection is answered on authority, not on wording.** `CLAUDE.md` and the doctrine have
  **different authorities and scopes** — one is Thomas's personal preference file, the other is the
  product's declared normative home. Overlap between them is justified, not drift, because they are
  not competing to own the same rule.
- **(c) and (d) fail for a named reason:** they leave *product correctness dependent on undeclared
  external state*. The workflow would only behave correctly because a file outside the repo — one
  free to be trimmed or reworded without the workflow knowing — happens to be loaded.
- **AC3 is severable and independently justified** (Open questions #2 resolved as drafted): step 9
  demands a recommendation without defining how it is earned, and no briefing rule can override a
  skill step.

## Design decisions (2026-07-16)

**Scope + one-way door — approved as option (b).** Thomas selected *"(b) Consult-structure rules in
the doctrine"* at the frame consult. This **ratifies the one-way door**: the doctrine
(`workflow-protocol.md`) is now the declared home for *how the loop treats its human*, not only
*what gets decided*. Future presentation rules go there by this precedent.

Grounds for the decision (earned, not reflexive):
- **The declared normative home.** `README.md` states "the normative rules live in
  `.claude/workflow-protocol.md`." Consult behavior is a product rule, so it belongs there.
- **No dependence on undeclared external state.** Options (c)/(d) leave the workflow correct only
  because `~/.claude/CLAUDE.md` happens to load on this machine — a file the product neither owns
  nor can see, free to be trimmed without the workflow knowing. Standard practice is for a product's
  correctness to live inside the product.
- **DRY objection answered on authority.** `CLAUDE.md` (personal preference) and the doctrine
  (product norm) have different authorities and scopes; the overlap is justified, not the
  "third drifting copy" this repo rejects elsewhere.

**Acknowledged cost (accepted, not waved away):** this is *not* zero duplication. "Always give
tradeoffs" will exist both generally (in `CLAUDE.md`) and as a consult rule (in the doctrine).
Rewording one will not update the other, and there is **no mechanical check** against a future editor
drifting general-style prose into the doctrine. **Mitigation, binding on implementation:** AC2's
scope-boundary sentence must be present — the doctrine states out loud that it owns *consult
structure* and not *communication style*, so the boundary a future editor must respect is written
down even though it cannot be enforced by a test.

**AC3 (step 9 grounding) — kept alive unconditionally.** Confirmed independent of the option chosen:
it is the one observed defect `CLAUDE.md` cannot reach (a briefing rule cannot override a skill step
that mandates a recommendation), and the reviewer independently judged it "independently worth
implementing." Open questions #2 resolved: **AC3 stands on its own.**

**Binding on implementation (step 9):** the whole approved shape is option (b) exactly as the Design
sketch describes — extend the existing `## Consult model` section (no new top-level section),
add the four terse pointers, and ground step 9's recommendation in the `severity` + `claim` the
schema **already carries** (no schema change). Do not re-litigate these while building.

## Build note (2026-07-16)

| AC | Where it landed |
|---|---|
| AC1 — doctrine states both bars (tradeoffs unconditional, recommendation earned) | `.claude/workflow-protocol.md` — new "How a consult is presented" paragraph inside the existing `## Consult model` section |
| AC2 — rule states its own scope boundary (structure, not style) | same paragraph — closing sentence ("not a style guide … does not belong here") |
| AC3 — `/review` step 9 grounded in severity + claim, no schema change | `.claude/skills/review/SKILL.md` step 9 |
| AC4 — one pointer per stop (4 total) | `frame` step 7 (×1); `review` steps 7 and 9 (×2); `close` step 4 (×1) |
| AC5 — tightness: no new top-level section, no style prose | constraint on `.claude/workflow-protocol.md`; verified by diff |
| AC6 — gate green | the configured `testCommand` |
| AC7 — scope containment | `git diff --name-only main...HEAD` |
| AC8 — ≤2 drift assertions | `tests/reviewer_test.sh` — new "consult-presentation rule stated in doctrine + pointed at from a stop" group (2 `has` checks + a `PROTOCOL` var) |

**Doctrine is source, not live copy.** The edit is to the repo's `.claude/workflow-protocol.md`; the
live copy every app reads (`~/.claude/workflow-protocol.md`) is refreshed by `install.sh`, so this
reaches running skills on the next install — the same deploy path as `antipattern-lens`.
