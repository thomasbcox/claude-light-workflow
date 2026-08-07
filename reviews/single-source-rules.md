Date: 2026-08-07 · Branch: claude/single-source-rules · Status: approved

# Single-source the shared rules — assemble the reviewer's copy at call time, never store it

OPS-17. Thomas, 2026-08-07: *"can we not have a declared rule source, and other copies are created
maybe temporarily as needed to give to agents, and then the derived copies go away once used… This
feels like it should be a lot easier than this."*

**This replaces an earlier draft of this story** that built a checker to verify two stored copies
agreed. That draft rested on an error: having verified that schema `description` fields are sent to
the reviewer as its live instructions, it concluded the rule must therefore be *duplicated in the
schema file*. It does not follow. The rule must be in the **payload**; it need not be in the **file**.
The payload is built fresh on every call. Storing a second copy to satisfy a per-call need was the
mistake, and policing that copy would have institutionalised it.

## Problem

Every behavioural rule in this loop is written in several places, and a fix lands on the copy a
reviewer cited while the siblings keep the old text. A later round finds an un-fixed copy and it
reads as *the same issue, again*. OPS-17 records three instances inside one story. The story merged
yesterday added three more: of six review findings across two rounds, four were documents left behind
by a decision and **none** was a coding error.

The rule text the reviewer needs is already single-source in one place — `workflow-AGENTS.md`, read
from disk at call time and pushed verbatim. The schemas hold a **second copy of the same rules**,
stored on disk, drifting silently, because the model needs the text inline in each field description
and cannot follow a pointer.

**Nothing requires that copy to be stored.** The runner already assembles the request. It can
assemble the descriptions too, from the one authoritative statement, and discard them with the
request.

## In scope

### 1. Markers replace stored rule text in schema descriptions

A `description` that today restates a contract rule instead carries a **marker** naming where the
rule lives:

```json
"reversibility": { "description": "{{contract:Classify#reversibility}}" }
```

**The grammar, pinned before any schema copies it** (ratified 2026-08-07 as a one-way door — every
future schema and its tests inherit it):

- **(a) Section.** The name matches the heading text **up to any trailing parenthetical**,
  case-sensitive, and must match **exactly one** heading. Against the contract as it stands this is
  unambiguous: `Your role`, `Grounding`, `Best-practice assessment`, `Classify`, `You must NOT`,
  `Severity labels`, `Output`. The design review caught the sketch's own first example failing here —
  `{{contract:Classify#reversibility}}` cannot resolve under exact matching, because the heading is
  `## Classify (design / approach findings)`. Rule (a) is what makes that example correct.
- **(b) Term.** `#term` matches the **full bold lead-in**, exact match, of **either** a `-` bullet or
  a numbered item — so `Classify`'s `- **reversibility**` and `Best-practice assessment`'s
  `1. **Concrete win, not novelty.**` are both addressable. Bullets-only would have left the finest
  anchors this story may need unreachable.
- **(c) Whole-value only.** A `description` is *entirely* a marker or *entirely* literal — v1 does
  not embed a marker inside surrounding prose. A description that today mixes a rule with
  field-shape guidance either moves the shape text or is recorded as a **declared literal
  exception**.
- **(d) Anything else in `{{…}}` fails closed.** Any `{{…}}` sequence that is not a well-formed
  contract marker is malformed (AC3). This reserves `{{skill:…}}` and every other namespace **for
  free**, without building the general system — and it is why this story carries no open question
  about namespace reservation.

Descriptions that explain a field's *shape* rather than a rule ("Short label for the finding") stay
literal — they restate nothing.

### 2. One resolver, both backends

- **`fireworks`** — resolve in memory in `fireworks_runner.py`, after `load_schema` and **before**
  `check_size` (resolved text changes payload size) and before the request. Nothing is written.
- **`codex`** — it is handed a schema **file path** and reads the file itself, so an unresolved
  marker would reach it verbatim. The runner gains `--render-schema <pass> --out <path>`, writing a
  resolved schema to a temp file that the skill's codex block passes to `--output-schema`. **Same
  resolver, one implementation** — the two backends cannot disagree about what the reviewer was told.

**The rendered file is allocated under the system temp directory — never inside the working tree**
— via `tempfile`/`mktemp`, with cleanup on the failure path too (a shell `trap`, matching the
existing parallel-critic block). This is structural, not janitorial: a resolved schema cannot be
committed because it never exists anywhere committable. Writing it repo-relative is the natural
thing to put in a skill block and would mean an interrupted run leaves a resolved copy that one
`git add -A` turns into the stored second copy this story exists to abolish.

### 3. Fail closed on any unresolved marker

A marker naming a missing section or bullet, or a malformed marker, **stops the round**: a message
naming the marker, **no request made**, no artifact written. This is the property that makes the
scheme safe — a broken pointer is loud, where divergent prose is silent. That asymmetry is the whole
argument for pointers over copies.

### 4. The doctrine line

One statement in `workflow-protocol.md`: a behavioural rule is **stated once**; where a second
audience needs it inline and cannot follow a pointer, the copy is **assembled at call time from that
one statement and discarded with the request** — never stored, never edited in place.

## Non-goals

- **Editing the contract's wording.** The markers address it as it stands.
- **Restatements sourced from a skill rather than the contract.** `lesson-review-schema.json`'s
  `trigger_qualified` restates `/close`'s bounded question, which lives in the skill. Resolving
  against arbitrary deployed artifacts is a general templating system; this story resolves against
  **the contract only**. Named as a known remaining copy, not silently skipped.
- **Story acceptance criteria, test pins, and sample artifacts.** Real restatement sites, but their
  readers *can* follow a pointer, so the answer there is convention, not machinery.
- **A build step or any generated file in the repo.** Nothing is generated ahead of time; assembly
  happens per call.
- **Generating the contract from the schemas.** The contract is authored prose for a human reader.

## Acceptance criteria

1. Every schema `description` that today restates a contract rule carries a marker instead; the rule
   text appears in exactly one file (`workflow-AGENTS.md`).
2. A marker naming a section or bullet absent from the contract stops the round: non-zero exit, **no
   API call made**, no artifact written.
3. A malformed marker does the same.
4. A resolved description contains the contract's text for the named anchor — the actual text, not a
   paraphrase, and never empty.
5. Resolution changes **only** `description` values: the schema's structural content (`type`, `enum`,
   `required`, `additionalProperties`, `properties` keys) is identical before and after.
6. `--render-schema` produces, for a given pass, a schema equal to what the fireworks path sends —
   one resolver, two consumers, no second implementation.
7. The codex blocks in `review/SKILL.md` and `frame/SKILL.md` render before invoking and pass the
   rendered path to `--output-schema`.
8. No rendered schema is committed: the render target is a temp path, and the repo contains no
   resolved copy.
9. `workflow-protocol.md` states the doctrine once, and names the assemble-and-discard rule.
10. This story's diff touches only the files its design sketch names.

## Test notes

**Regressions are not written here.** They come from the step-6 design review.

| AC | Oracle | Mechanism |
|---|---|---|
| 1 | **gate** | For each field named in the resolver's marker map, assert the on-disk schema value *is* a marker — and separately assert the contract still contains that anchor, so the pair cannot pass by both going missing. |
| 2, 3 | **gate** | `tests/fireworks_runner_test.py` with its stubbed client: point a schema at a missing anchor, run the altitude, assert non-zero exit, **`len(calls) == 0`** (the stub records every request — this is what proves it failed *before* spending a call), and no artifact in `reviews/`. |
| 4 | **gate** | Assert the resolved description equals the contract text extracted independently by the test — the test reads the contract itself rather than asking the resolver what it produced, so a resolver returning its own input cannot pass. |
| 5 | **gate** | Deep-compare the schema before and after resolution with every `description` key stripped from both; assert equal. Catches a resolver that mutates enums or drops a `required`. |
| 6 | **gate** | Render via `--render-schema` to a temp path, and separately capture what the stubbed client received on a real altitude run; assert the two are equal. |
| 7 | **gate** | **Behavioral, not a token grep.** Put a stub `codex` on `PATH` that records its argv and the *contents* of the file named by `--output-schema`; execute each skill's codex block; assert the consumed file contains **no** unresolved `{{` and **does** contain the contract's anchor text. A grep for `--render-schema` passes if the render sits in a comment, runs after the invocation, or the path is overridden later — none of which the criterion allows. Reworked from a spelling check during the frame consult. |
| 8 | **gate** | `git ls-files` shows no rendered schema; the render path is under a temp directory. |
| 9 | **reviewer** | Whether a doctrine line states rather than restates is not machine-checkable. Named plainly. |
| 10 | **manual** | `git diff --name-only main...HEAD -- . ':(exclude)reviews/'` shows nothing beyond the sketch's list. |

### Proposed regressions (from the design review — ratified at step 7, executed at step 9)

All 10 criteria covered; 20 entries.

- **AC1** — The marker map is written to match what was converted rather than what restates: a description that restates a contract rule but sits outside the map — a nested items.description, a $defs entry, or a lesson-review-schema field beyond the named trigger_qualified — stays literal. The AC1 gate checks only mapped fields, so it passes while a stored copy remains; the map becomes the hiding place.
- **AC1** — The rule text leaves the description but persists in the same schema file under a different key — $comment, title, or an x- extension note. Every mapped description is a marker (letter satisfied), yet the schema file still stores a second copy of the rule (intent: the text appears in exactly one file, workflow-AGENTS.md).
- **AC2** — Fail-closed is implemented on the fireworks altitude path only: --render-schema prints the error and exits 0, or writes the unresolved schema to --out before exiting non-zero. The AC2 gate runs the altitude and passes; the codex path proceeds with raw markers or a written artifact, violating the intent that ANY unresolved marker stops the round on either backend.
- **AC2** — The output is opened before resolution runs: the render path creates/truncates the --out file (or the altitude path creates a reviews/ placeholder) and only then discovers the bad marker. Non-zero exit and zero API calls satisfy the letter, but an artifact exists — the intent is failing before producing anything.
- **AC3** — The parser 'helpfully' normalizes near-miss markers — wrong case ({{Contract:...}}), extra whitespace, ':' instead of '#', singular vs plural section names — and resolves them anyway. Only unparseable garbage trips the gate, so the typo class most likely to occur never stops the round; 'malformed' gets defined by what the parser tolerates rather than by exactness.
- **AC3** — Marker detection is scoped to the fields in the marker map: a malformed marker sitting in an unmapped or nested description is never scanned, ships verbatim to the reviewer, and the round proceeds. The gate plants its malformed marker in a mapped field, so it passes while the intent — any marker-shaped string anywhere in descriptions is validated — fails.
- **AC4** — Wrong-anchor resolution returning genuine contract text: the section is matched by substring ('Classify' matches the first heading containing the word) or #term matches the first bullet that mentions the word rather than equality on the bold lead-in, so the description fills with real, non-empty contract prose for the wrong anchor. 'Actual text, not a paraphrase, never empty' is satisfied; 'for the named anchor' is not.
- **AC4** — The test's 'independent' extractor reuses the resolver's regex or helper, so a systematic mangle — collapsing a multi-bullet section into one line, dropping the bold lead-in, trimming a heading's parenthetical — appears identically on both sides of the equality and the gate passes against text that is not what a human reads in the contract.
- **AC5** — The test's before-snapshot aliases the resolver's input dict instead of deep-copying it; in-place mutation makes before and after identical by construction, so a resolver that drops a required entry or mutates an enum is invisible — the gate cannot fail no matter the structural damage.
- **AC5** — The walk visits only top-level properties.*.description and never recurses into items, $defs, or nested properties. Those subtrees are identical before and after precisely because nothing was done to them — AC5 passes — while markers inside them reach the reviewer unresolved, violating the paired intent: every description resolved, nothing else touched.
- **AC6** — The --render-schema CLI handler duplicates the resolution logic instead of calling the altitude path's function; the two copies agree today, the output-equality gate passes, and 'one implementation' holds only until the next edit. The gate as specified — compare outputs — structurally cannot detect a second implementation.
- **AC6** — Equality is checked on parsed JSON dicts while codex consumes file bytes: the render path serializes differently from the wire payload (unicode escaping, key ordering, trailing newline), so the two are 'equal' per the test's notion and different per the actual consumer — codex is not told byte-for-byte what the fireworks reviewer is told.
- **AC7** — Dead-token satisfaction: the skill invokes --render-schema in a comment, an unused helper, or a branch that does not run, while the live codex invocation passes a raw schema path through a variable (--output-schema "$SCHEMA") that the token grep cannot classify. The gate passes; codex reviews against raw {{contract:...}} markers; the failure is silent.
- **AC7** — Wiring/ordering broken with all tokens present: render runs after the codex invocation, or renders altitude A's schema while the altitude B call consumes it, or the rendered path is computed but a stale or never-assigned variable is what actually gets passed. Every greppable token is in place; the property is broken.
- **AC8** — The render target is a repo-relative dotfile (e.g., reviews/.tmp-schema.json) deleted on the happy path; an interrupt or a failed codex call with &&-chained rm leaves it behind, and a later git add -A commits a resolved copy. git ls-files is clean at test time (letter), but the design permits the committed second copy to recur (intent).
- **AC8** — The gate pattern-misses the artifact: the ls-files assertion greps for a filename convention (e.g., *rendered* or *-schema.resolved.json) while the skill writes the resolved schema under a name outside that pattern — committed, green, and exactly the stored duplicate the story abolishes.
- **AC9** — The doctrine paragraph states assemble-and-discard but illustrates it by inlining actual rule text 'for example' — quoting the reversibility definitions or a severity bullet — so the doctrine file itself becomes a new stored copy, recreating the drift site one level up while the letter (stated once, rule named) passes.
- **AC9** — The same diff adds fresh rule restatements in the skill files' prose while editing their codex blocks for AC7. AC9 names only workflow-protocol.md, so the letter passes while the story's own change introduces new copies — violating the single-source intent it codifies.
- **AC10** — Yardstick editing: implementation discovers it needs an unlisted file (a shared test fixture, a third consumer) and amends the sketch's file list to match what was touched, so the diff-vs-sketch comparison passes. The intent — the human ratifies scope before building — is defeated by editing the yardstick instead of surfacing the scope change.
- **AC10** — The reviews/ exclusion becomes the smuggling route: a committed fixture, helper output, or sample rendered schema lands under reviews/ where the name-only diff never looks, satisfying the letter while the diff reaches beyond what was designed.

## Open questions

1. **Does a whole-section excerpt read well as a field description?** `## Severity labels` is four
   bullets — probably fine. `## Best-practice assessment` is three numbered guardrails plus a
   preamble, which may be more than a `win` field wants. If any anchor reads badly inlined, the
   options are a finer anchor or leaving that one description literal and declaring it. Settle per
   anchor during implementation and record which.
2. **Should the resolver be reusable beyond the contract?** Generalising to any deployed artifact
   would also cover the lesson schema's skill-sourced copy. Deliberately not built here — but if the
   marker syntax should reserve room for it (`{{skill:close#…}}`), that is cheaper to decide now than
   to retrofit.

## Design sketch — HOW

**Files touched.** `.claude/skills/review/fireworks_runner.py` (resolver + `--render-schema`), the
schema files carrying markers, `.claude/skills/review/SKILL.md` and `.claude/skills/frame/SKILL.md`
(codex blocks render first), `.claude/workflow-protocol.md` (doctrine), `tests/fireworks_runner_test.py`
and `tests/reviewer_test.sh` (assertions). **No change to `workflow-AGENTS.md`.**

**Resolver.** One function: parse `{{contract:Section}}` or `{{contract:Section#term}}`, read
`CONTRACT_PATH`, split on `##` headings, and for a `#term` select the bullet whose bold lead-in
matches. Returns the anchor's text or raises `RunnerError` naming the marker. A **marker map** —
which fields are expected to carry markers — is the one hand-written thing, and it is the definition
of "shared rule" rather than a copy of a list that exists elsewhere; AC1 checks against it.

**Where it runs.** `resolve_schema(schema)` walks the loaded dict and returns a new dict with
`description` values resolved, leaving everything else untouched. Called by the altitude path before
`check_size`, and by `--render-schema` for codex. Same function, so AC6 holds by construction rather
than by discipline.

**Error model.** Fail closed and loud, matching the runner's existing doctrine: unresolved marker,
unreadable contract, or a marker map naming a field no schema has → `RunnerError`, no request, no
artifact. Resolution runs **before** the API call specifically so a broken pointer costs nothing.

## Fireworks design review (2026-08-07)

**Verdict.** Build it — the shape is right: call-time assembly from one authoritative source, fail-closed resolution before any API spend, one resolver feeding both backends, and no stored derived artifact. The sketch correctly refuses the two seductive wrong shapes (a stored second copy plus a drift checker, and a general templating system). I considered the still-simpler design — descriptions holding plain-text references into the contract the reviewer already receives in its prompt — and reject it on the story's own terms: a model silently failing to follow a pointer is precisely the silent-divergence failure this story exists to make loud, and deterministic fail-closed resolution is cheap where pointer-following is probabilistic. Three concerns, none blocking the concept: (1) the marker grammar is under-specified in exactly the spots every future schema will copy — the sketch's own example {{contract:Classify#reversibility}} does not resolve under exact heading matching against the actual heading '## Classify (design / approach findings)', '#term' is defined for bullets while the guardrails are numbered items, whole-value vs inline embedding is undecided, and namespace reservation (open question 2) is really a grammar decision cheapest made now. (2) AC7's gate greps skill markdown for flag tokens; the property that matters is what codex consumes. (3) The rendered temp file's lifecycle is left to happy-path shell janitorial work. Oracle notes: AC1's gate is well-shaped (the independent contract-side anchor check prevents both-missing collusion) but inherits the marker map's completeness — a too-narrow map passes; AC2/3's stubbed-client len(calls)==0 is behavior-derived and strong but exercises only the altitude path, leaving --render-schema's fail-closedness ungated; AC4's independent extraction is right only if the extractor shares no code or regex with the resolver; AC5's deep-compare is meaningful only against a deep-copied before-snapshot; AC6's output equality cannot prove 'one implementation' (two synchronized resolvers pass) and must define equality as the bytes the codex consumer actually reads; AC8's git ls-files is a point-in-time check blind to interrupt-leaked repo-relative temps; AC9/AC10 are honestly named human gates, though AC10's reviews/ exclusion is a blind spot that intersects AC8.

**Findings.**

- **[IMPORTANT] AC7's gate greps skill markdown for tokens — test what codex consumes, not what the file spells** — `two-way` × `kludgy` · locus: Test notes → AC7 row
  - **Claim:** The named mechanism — assert both skills' codex blocks invoke --render-schema and that no --output-schema points at a raw *-schema.json path — is derived from the implementation's spelling, not from the criterion ('codex blocks render before invoking and pass the rendered path'). It passes if the render call sits in a comment or dead branch, if the rendered path is overridden by a later variable assignment, if render runs after the codex invocation, or if the path flows through a variable the grep cannot classify. The failure it guards is Tier-1 and silent: codex reviewing against raw {{contract:...}} markers — exactly the silent-divergence mode this story exists to eliminate — and a token grep cannot see any of the realistic ways it happens.
  - **Alternative:** Make the gate behavioral in the same shell harness: put a stub codex executable on PATH that records argv and the content of the file named by --output-schema, execute each skill's codex block, then assert the consumed file contains no unresolved marker and does contain the contract's anchor text. Keep the token grep as a cheap pre-filter if desired.
  - **Win:** The gate tests the property (what the reviewer was told) instead of the spelling; ordering bugs, wrong-variable wiring, and dead render steps all become detectable; no reliance on markdown-layout discipline in skill files.

- **[IMPORTANT] Rendered-schema lifecycle is janitorial where it should be structural** — `two-way` × `kludgy` · locus: Design sketch → Where it runs; In scope §2 (codex)
  - **Claim:** 'The rendered file is a temp, deleted after the call' puts the deletion duty in the skill's shell block, outside the runner's fail-closed error model. An interrupt, or a failed codex call with an &&-chained rm, leaves a resolved copy on disk — and the sketch never says WHERE the temp lives. If that path is repo-relative (the natural thing to write in a skill block), the leaked file is one git add -A away from becoming a committed second copy: the exact stored-duplicate failure this story exists to abolish, reintroduced through the temp file. AC8's gate (git ls-files at test time) cannot see a file that does not yet exist.
  - **Alternative:** Specify the render target as a tempfile/mktemp allocation under the system temp directory — never under the working tree — with deletion via a shell trap or runner-side cleanup so the failure path deletes too. Then AC8 holds structurally: a resolved schema cannot be committed because it never exists inside the repo.
  - **Win:** Converts AC8 from happy-path janitorial discipline into a structural property; eliminates the interrupt-leak → accidental-commit failure mode that resurrects the stored second copy; removes a cleanup branch from each skill block.

- **[QUESTION] Pin the marker grammar before it is copied into every schema** — `one-way` × `standard` · locus: Design sketch → Resolver; In scope §1
  - **Claim:** The grammar every schema file will copy is under-specified in four places, and the sketch's own example exposes the first: {{contract:Classify#reversibility}} cannot resolve under exact heading matching, because the contract's heading is '## Classify (design / approach findings)' — so section matching is implicitly prefix/substring, with the rule unstated. Second, '#term matches the bullet whose bold lead-in is that term' covers '- ' bullets, but the Best-practice guardrails are numbered items, so the finest anchors the story may want (open question 1's fallback) are not addressable by the specified mechanism. Third, whole-value vs inline embedding is undecided: a description that mixes rule text with field-shape guidance must either lose the shape text to whole-value replacement or stay literal as an undeclared exception. Fourth, open question 2 (reserve {{skill:...}}?) is a grammar decision, not an implementation one — the cheap answer is 'any {{...}} that is not a well-formed contract marker fails closed', which reserves every namespace for free. This syntax is a cross-cutting pattern future schema edits will copy; retrofitting it later means migrating every schema plus the tests.
  - **Alternative:** Add a short grammar paragraph to the sketch before building: (a) section names match the heading text up to any trailing parenthetical, case-sensitive, and must match exactly one heading; (b) #term matches the full bold lead-in of both '- ' and numbered items, exact match only; (c) v1 markers are whole-value — descriptions mixing rule and shape guidance either move the shape text or are recorded as declared literal exceptions per open question 1; (d) any {{...}} sequence not matching the contract grammar is a malformed marker and fails closed (AC3), which reserves skill:/other namespaces without building the general system.
  - **Win:** Deletes open question 2 with a one-line rule instead of a future retrofit; prevents the resolver and the test's independent extractor from silently implementing two different matching rules; avoids a syntax migration across all schema files when the first numbered-item or inline marker is needed.

**Coverage check.** All 10 criteria received at least one regression (20 total). No gap.

## Design decisions (2026-08-07)

**Scope — approved.** Thomas, 2026-08-07: *"approved, fix all three"*, on the redesign he asked for:
*"can we not have a declared rule source, and other copies are created maybe temporarily as needed to
give to agents, and then the derived copies go away once used… This feels like it should be a lot
easier than this."*

Binding on implementation. Do not re-litigate.

| Finding | Disposition | Where it landed |
|---|---|---|
| Pin the marker grammar before it is copied (**one-way**, ratified) | **fix** | In scope §1 — rules (a)–(d), including the fail-closed catch-all that deletes the namespace open question |
| AC7's gate greps skill markdown for tokens | **fix** | Test notes AC7 — stub `codex` on `PATH`, assert what it actually consumed |
| Rendered-schema lifecycle is janitorial | **fix** | In scope §2 — system temp dir, never the working tree, cleanup on the failure path |

**One-way door ratified:** the marker grammar. Every future schema and its tests inherit it;
changing it later means migrating all of them.

**Carried into implementation from the reviewer's oracle critique** (its verdict, not its findings —
recorded so they are not quietly dropped): AC1 inherits the marker map's completeness, so a too-narrow
map passes; AC2/3 exercise only the altitude path, leaving `--render-schema`'s fail-closedness
ungated; AC4's independent extractor must share no code or regex with the resolver; AC5's comparison
needs a genuine deep-copied before-snapshot; AC6 cannot prove "one implementation" by output equality
alone. Each is mine to address in the test notes as built, and any that cannot be closed will be
stated rather than reshaped.
