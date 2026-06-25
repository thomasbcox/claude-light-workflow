Date: 2026-06-25 · Branch: claude/design-review-loop · Status: approved

# design-review-loop

## Problem

Two linked gaps in the light workflow:

1. **Codex stays in the weeds.** The contract and prompt pin it to the diff
   (`AGENTS.md`: *"Ground every finding in the actual diff — no speculation"*), and
   the schema's severities are all defect-shaped. A high-leverage critique like
   *"you hand-rolled per-route validation that one zod schema would do
   declaratively"* has nowhere to live — it's about code that **shouldn't exist**,
   not a diff line — so Codex never raises it. The reviewer never volunteers
   altitude.

2. **"Decide twice" is too coarse.** The human is consulted only on scope and
   merge. The shape of a change — the high-level design and the implementation
   tradeoffs — is decided entirely by Claude, unreviewed at the design altitude.
   The bad approach (above) isn't caught until it has shipped toward merge, after
   the build turns are already spent.

We want the human consulted at the altitudes where leverage lives — **requirements,
high-level design, implementation tradeoffs** — and we want Codex to judge the
*shape* and *quality* of a change, before and while it judges the lines, **without**
turning the loop into heavyweight phase-gating.

## Model (the conceptual core — read before the ACs)

**Two independent dials**, deliberately decoupled:

- **Blocking dial = reversibility.** Only **one-way-door** decisions (expensive to
  reverse) stop Claude and demand a human decision. **Cross-cutting patterns /
  repeated structure that future code will pattern-match on count as one-way doors**
  (this is the zod class — locally reversible, globally not). Reversible (two-way)
  decisions default to Claude and are **logged for veto**, not blocked.
- **Assessment dial = best practices.** Codex **always** assesses every notable
  decision against modern idiom and the repo's own conventions, and **flags**
  nonstandard / dated / kludgy choices **regardless of reversibility** — so a
  two-way door still gets surfaced if it's substandard.

They compose because they answer different questions: *"must the human decide this
before we proceed?"* (reversibility) vs. *"is this good?"* (best practice). Rule of
thumb: **block narrow (one-way doors), assess broad (everything, against best
practice).**

**Three guardrails** so the best-practices lens doesn't become a liability:
1. **Concrete win, not novelty.** Every flag names the payoff (lines removed, a
   dependency dropped, an error path eliminated). "Newer" is not a reason.
2. **Weigh internal consistency.** A choice nonstandard for the ecosystem may be
   standard for *this* codebase; matching existing patterns can rightly win. Flag
   deviation from **both** the ecosystem norm and the repo's conventions.
3. **Repo conventions are the local standard** (`AGENTS.md` / contributing docs).

**The loop after this change:**

```
/frame   1. Requirements + high-level design — Claude drafts spec + a design sketch,
            Codex design-reviews the sketch (best-practices, always-on), one consult:
            Thomas approves scope, ratifies one-way doors, decides best-practice flags.
         then implement.
/review  2. Approach pass (best-practices lens) gates the correctness pass:
            block on one-way doors / major violations → redesign + re-review;
            advise on minor two-way kludges; correctness runs only on a blessed shape.
/close   3. Merge authorization (unchanged), + accepted redesign routes to re-review.
```

Disposition of a finding falls out of its two tags (reversibility × standing):
one-way **or** major best-practice violation → **block/consult**; two-way + minor →
**advisory/log**.

## In scope

1. **Doctrine** (`workflow-protocol.md`): replace "decide exactly twice" with the
   consult model + the two-dial / one-way-door / best-practices rules above.
2. **Contract** (`AGENTS.md`): split grounding (correctness=diff, design=spec+
   surroundings), add the always-on best-practices mandate + the three guardrails.
3. **Shared review schema** (`.claude/skills/review/design-review-schema.json`,
   new): one strict schema used by **both** the frame design review and the review
   approach pass, carrying the reversibility/standing tags + alternative + win.
4. **Frame** (`frame/SKILL.md`): a **design sketch** in the spec; a **Codex design
   review** of it; the combined frame consult; the first-review override reminder.
5. **Review** (`review/SKILL.md`): the **approach pass** (best-practices lens) with
   the **round-keyed default**, **bare-arg overrides**, and the
   **decision-gated short-circuit + disposition split** gating the correctness pass.
6. **Close** (`close/SKILL.md`): accepted approach/redesign fix routes to re-review.
7. **Docs** (`README.md`): describe the new loop, pointing at the skills as the
   normative source. *(De-parenting `ai-dev-workflow-architecture.md` — which
   documents the parent v3 system, not this one — is deferred to a follow-up story;
   see Decisions.)*

## Non-goals

- **No separate requirements-vs-design STOP.** Requirements and high-level design
  are presented and decided in **one** frame consult (you rarely approve scope then
  refuse to look at design). Splitting them is a later option, not v1.
- **No frame-time review of generated code.** The frame review reads the *sketch*
  (intent); code review stays at `/review`.
- **No auto-applied changes through a one-way door.** Claude may tidy/adopt the
  modern pattern for **two-way advisory** items; one-way-door choices always need
  Thomas.
- **No new skill or top-level command.** The loop stays frame → review → close.
- **No change to the correctness schema or its severities** (`finding-schema.json`
  is untouched; the correctness pass keeps using it).
- **No "skip approach on tiny diffs" size heuristic** beyond the override + the
  one-way-door/best-practice tiering, which already collapses the trivial case.
- **No second copy of the doctrine in the docs** — they describe and point at the
  skills, never restate the rules verbatim (avoids drift).

## Acceptance criteria

### Doctrine & contract
1. **`workflow-protocol.md`** replaces "the human decides exactly twice" with: the
   human is consulted at **requirements, high-level design, and implementation
   tradeoffs**, plus the merge authorization; **blocking is gated by the one-way-door
   test** (irreversible decisions block; **cross-cutting patterns count as one-way
   doors**); two-way decisions default to Claude and are logged for veto. It states
   the **two-dial principle** (blocking=reversibility, assessment=best-practices,
   always-on).
2. **`AGENTS.md`** (a) replaces the blanket *"ground every finding in the actual
   diff"* with two clauses (correctness=diff-grounded; design/approach=spec-and-
   surroundings-grounded, may cite code that should not exist); (b) adds the
   **always-on best-practices mandate** (assess every notable decision vs. modern
   idiom **and** the repo's conventions; flag nonstandard/dated/kludgy **regardless
   of reversibility**); (c) states the **three guardrails** (concrete win not
   novelty; weigh internal consistency; repo conventions = local standard).

### Shared schema
3. **`.claude/skills/review/design-review-schema.json`** is valid JSON, strict
   (`additionalProperties:false`, every property in its `required` array), with
   top-level required `verdict` (string) + `findings`. Each finding requires:
   `severity` (`BLOCKER|IMPORTANT|QUESTION|NIT`), `reversibility`
   (`one-way|two-way`), `standing` (`standard|nonstandard|dated|kludgy`), `title`,
   `locus` (`["string","null"]` — sketch section at frame time, file:line/module at
   review time), `claim`, `alternative` (string), `win` (string — the concrete
   payoff that justifies the alternative). Optionals are nullable, never absent.

### Frame (requirements + design consult)
4. **`frame/SKILL.md`** adds a `## Design sketch — HOW` section to the spec (the
   intended approach: key structures, libraries, patterns), drafted **before**
   implementation and **before** the frame consult.
5. **`frame/SKILL.md`** runs a **Codex design review** of the sketch:
   `codex exec -s read-only --output-schema $HOME/.claude/skills/review/design-review-schema.json -o reviews/<slug>.design.json … </dev/null`,
   reading the spec + sketch + surrounding code + dependency manifest, returning
   best-practices findings (no gate prerequisite — it reviews intent, pre-code).
6. **`frame/SKILL.md`** presents **one combined consult**: scope + the design sketch
   + Codex's design findings, where Thomas (a) approves scope, (b) ratifies any
   one-way-door decisions, (c) decides each best-practice flag (fix / accept /
   defer). Implementation proceeds only on approval. **Tiering:** a sketch with no
   one-way doors and an empty Codex flag list is a clean pass (still shown; no extra
   ceremony). The existing "write no code before approval" constraint is preserved.
7. **`frame/SKILL.md`**'s hand-off to `/review` surfaces the `approach` /
   `correctness` override args (the first-review reminder).

### Review (approach pass gating correctness)
8. **`review/SKILL.md`** defines the **approach pass**: a distinct
   `codex exec -s read-only --output-schema …/design-review-schema.json -o
   reviews/<slug>.approach.json … </dev/null` that reads the spec first, then the
   **full** changed files + dependency manifest (not only the diff), applies the
   best-practices lens, is licensed to cite simpler/declarative/library designs and
   code that should not exist, and returns at most the **3 highest-leverage**
   concerns (each with `alternative` + `win`).
9. **`review/SKILL.md`** specifies the **round-keyed default** (approach pass on the
   first review of a branch and on any round following an accepted redesign;
   correctness-only on fix-verification re-reviews) and the **bare-arg overrides**
   `/review approach` (force on) / `/review correctness` (force off).
10. **`review/SKILL.md`** specifies the **decision-gated short-circuit + disposition
    split**: the approach menu is presented **before** the correctness pass;
    **one-way-door problems and major best-practice violations block** (an accepted
    redesign **skips correctness this round** → re-review); **minor two-way kludges
    are advisory** (logged; Claude may tidy or Thomas vetoes; no forced redesign); a
    blessed-or-clean shape runs correctness **in the same round**. The invariant is
    stated: *the correctness pass only ever runs on a shape that has cleared approach
    review.*

### Close, deploy & docs
11. **`close/SKILL.md`** step 4 states that an accepted approach/redesign fix routes
    to **re-review**, not straight to merge (same treatment money/security fixes get).
12. **Deploys with no installer edit:** `design-review-schema.json` ships because
    `install.sh` `cp -R`s `.claude/skills/review/`; `/frame` references it by the
    absolute installed path (mirroring how `/review` references its schema).
    Verified, not assumed.
13. **`README.md`** describes the new loop (three consults, two dials, the always-on
    best-practices lens, the override args), pointing at the skills as normative
    rather than restating the rules. *(`ai-dev-workflow-architecture.md` is out of
    scope — it documents the parent v3 system; de-parenting it is a follow-up story.)*

## Test notes

- The repo gate `bash tests/guard_test.sh` tests the guard hook and is **unaffected**
  by this change; it must stay green at `/review`.
- AC3: `python3 -m json.tool .claude/skills/review/design-review-schema.json` parses;
  assert the required keys, the three enums, and the nullable `locus` by inspection / `jq`.
- AC1–2, AC4–11, AC13: verified by inspection — each AC names the exact clause to
  look for in the named file.
- AC12: confirm `install.sh` copies `.claude/skills/review` via `cp -R` (verified in
  framing) and that both skills reference the schema by `$HOME/.claude/...` absolute path.
- Scope containment: `git diff --name-only main...HEAD` shows no files beyond those
  the ACs enumerate: `.claude/workflow-protocol.md`, `AGENTS.md`,
  `.claude/skills/review/design-review-schema.json`, `.claude/skills/frame/SKILL.md`,
  `.claude/skills/review/SKILL.md`, `.claude/skills/close/SKILL.md`, `README.md`,
  this story file, and the CHANGELOG entry `/close` adds at merge time.

## Decisions so far (Thomas, 2026-06-25)

- **Relax "decide twice"** → consult at requirements / high-level design /
  implementation tradeoffs, plus merge.
- **One-way-door blocking**, with **cross-cutting patterns counted as one-way doors.**
- **Always-on Codex best-practices assessment** that flags substandard two-way doors
  too (with the three guardrails).
- **Bare-arg overrides** `/review approach|correctness`, **always reminded** on a
  first (non-re-review) `/review` offer.
- **Docs in scope** (README + architecture doc).
- **Frame-time design review: in** (the high-level-design consult).
- **One combined frame consult** (scope + design decided together), not two STOPs.
- **One shared `design-review-schema.json`** for both passes, not per-pass schemas.
- **Scope approved** 2026-06-25: *"1 yes combine; 2 shared"* (after approving the
  consult model, one-way-door blocking, and the always-on best-practices lens).
- **AC13 amended → README-only** (2026-06-25): `ai-dev-workflow-architecture.md`
  documents the parent **AI Protocol v3**, not the light workflow, so it is dropped
  from this story's scope. De-parenting it (Thomas's call: *rewrite, not delete —
  next*) is a follow-up story (`standalone-architecture-doc`).

## Open questions

None — scope approved. Implementation proceeds AC-by-AC.

## Build note (2026-06-25)

AC → file map:
- AC1 (doctrine: consult model, two dials, one-way-door blocking) → `.claude/workflow-protocol.md`
- AC2 (contract: design altitude, always-on best-practice mandate, three guardrails, reversibility/standing tags) → `AGENTS.md`
- AC3 (shared strict schema) → `.claude/skills/review/design-review-schema.json`
- AC4–AC7 (design sketch, Codex design review, combined frame consult, first-review override reminder) → `.claude/skills/frame/SKILL.md`
- AC8–AC10 (approach pass, round-keyed default + bare-arg overrides, decision-gated short-circuit + disposition split + invariant) → `.claude/skills/review/SKILL.md`
- AC11 (accepted approach/redesign fix → re-review) → `.claude/skills/close/SKILL.md`
- AC12 (deploys via `install.sh` `cp -R`, no installer edit) → verified, no file change
- AC13 (docs; README-only per the amendment) → `README.md`

Reviewed under the installed single-pass `/review` (the new two-pass skill is on this branch, not yet deployed) — see the note in `/review` handoff.

## Codex review (2026-06-25, base main, HEAD afbe398)

**Summary:** Reviewed the branch against `reviews/design-review-loop.md`. Two spec mismatches: one workflow contradiction that can allow an unreviewed redesign to merge, and one README omission against AC13.

### BLOCKER
- **Redesign path still offers merge** — `.claude/skills/close/SKILL.md:22`. AC11 requires an accepted approach/redesign fix to route to re-review, not straight to merge, but step 4's lead still says to present exactly the "re-review … or merge" choice **every time**. The added bullet says not to offer a straight merge for redesigns, so the procedure is internally contradictory and can still lead Claude to offer the forbidden merge option after a redesign.
  - *Codex suggestion:* Make step 4 conditional — if the latest approved fixes include an approach/redesign fix, stop with re-review as the only route; otherwise present the normal re-review-or-merge fork.

### IMPORTANT
- **README omits review override args** — `README.md:15`. AC13 requires README to describe the `/review approach` and `/review correctness` override args, but the new `/review` row only describes the default approach-gates-correctness flow and README contains no mention of either override.
  - *Codex suggestion:* Add a short note that `/review approach` forces the approach pass and `/review correctness` skips straight to the correctness pass.

Raw output: `reviews/design-review-loop.codex.json`.

## Decisions (2026-06-25)

Thomas: *"fix both please"*
- **BLOCKER — Redesign path still offers merge** (`close/SKILL.md:22`): **fix** — make step 4 conditional (redesign fix ⇒ re-review is the only route; else the normal fork).
- **IMPORTANT — README omits review override args** (`README.md:15`): **fix** — add the `/review approach` / `/review correctness` overrides near the `/review` row.

## Fixes (2026-06-25)

Both approved fixes applied on the feature branch:
- **BLOCKER** (`.claude/skills/close/SKILL.md` step 4): rewrote step 4 as **conditional** — if the round's approved fixes include an approach/redesign fix, re-review is the **only** route (no merge offered); otherwise the normal re-review-or-merge fork. Resolves the internal contradiction Codex flagged.
- **IMPORTANT** (`README.md`): added the `/review approach` / `/review correctness` override args (and the correctness-only-on-re-review default) below the consult-model paragraph.

## Codex review (2026-06-25, re-review, base afbe398, HEAD d4a2e97)

**Summary:** Re-reviewed `afbe398...HEAD`. The README override-args fix is **sound**. The close-flow fix is **incomplete**: step 4 is now conditional, but the hard-constraints section still mandates asking "re-review or merge?" after every fix round — so the same contradiction persists at a different location.

### BLOCKER
- **Redesign path still conflicts with mandatory merge fork** — `.claude/skills/close/SKILL.md` (hard constraints, not step 4). The new step 4 correctly makes re-review the only route for an approach/redesign fix, but the hard constraint above it still says *"After fixes, ask 're-review or merge?' … every time,"* which remains in force and re-introduces the same contradiction (AC11 violation).
  - *Codex suggestion:* Update the hard constraint to defer to the conditional step-4 fork — redesign fixes offer only re-review; otherwise ask "re-review or merge?" and stop.

*(README override-args fix confirmed sound — no finding.)*

Raw output: `reviews/design-review-loop.codex.json`.

## Decisions (2026-06-25, round 2)

Thomas: *"explain then fix"* → **fix** the BLOCKER.

## Fixes (2026-06-25, round 2)

Root cause of the round-1 miss: I point-fixed the location Codex cited (step 4) instead of grepping for **every** place the "after fixes, offer re-review or merge" rule was encoded. This round, grepped the rule across all skills + doctrine and fixed **both** broken instances:
- **`.claude/skills/close/SKILL.md`** (hard constraint): now mandates the *stop* at the step-4 fork but defers the *menu shape* to step 4's conditional (redesign ⇒ re-review only).
- **`.claude/skills/review/SKILL.md`** (step 9): the description of `/close` no longer asserts it always "asks re-review or merge" — notes the fork is conditional.
- Verified consistent, left as-is: `close/SKILL.md:13` ("after the step-4 fork is presented") and `workflow-protocol.md:19` ("an accepted redesign always re-reviews"). README's `/close` table row is a coarse phase summary, not a normative rule.
