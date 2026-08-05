# route-design-hidden-failure — split the critics, wire design, close BUG-6

Status: approved

> **Retroactive story file (2026-08-04).** This branch was built directly from Thomas's
> instructions across a working session, without a `/frame` pass, and the file is written after the
> code. What that does and does not compromise, stated plainly because OPS-20 is about exactly this:
>
> - **The acceptance criteria have an independent source.** Each traces to a specific instruction
>   Thomas gave *before* the corresponding code existed (quoted per AC below). They are not
>   reverse-engineered from the diff.
> - **The test notes do not.** They describe checks that already exist, written by the same head
>   that wrote both the change and the checks. Under OPS-20's terms this is the single-head coupling
>   in its purest form, and no claim of falsification rigour is made for them. The two mutation runs
>   recorded below were real and are reproducible, but the mutations were **author-chosen**.
> - **Consequence for this review:** the approach pass is partly circular (it judges a shape against
>   a spec written after that shape). The correctness and hidden-failure passes are largely
>   unaffected — a defect in the diff is a defect regardless of when the spec was written.

## Problem

Four separate defects and decisions, taken together on one branch because they interleave in
`fireworks_runner.py` and its suite:

1. `correctness` and `hidden-failure` — the two parallel critics whose independence is the whole
   point of divided parallelism (OPS-12) — both ran `glm-5p2`. A same-model panel is the
   echo-chamber shape OPS-13 documents, where shared training distributions validate each other's
   hallucinations.
2. The `design` pass ran on `codex` only; `fireworks` was routed for it but not wired.
3. **BUG-6** — schema validation was vacuous. JSON Schema treats unrecognised keywords as no-ops, so
   a file that merely parsed as JSON validated anything, including `{}`, and the round promoted an
   empty body as a clean review. Both enforcement layers read the same dict, so they failed together.
4. `.claude/workflow-protocol.md` — the doctrine document `install.sh` deploys to every project and
   all four skills cite — had been stale since 2026-07-16: it claimed codex was the only wired
   backend and told readers to select `llm`, a retired name the shipped code rejects.

## In scope

- Model routing for `design` and `hidden-failure`, recorded as revisitable decisions.
- Wiring the `design` pass to the fireworks backend end to end.
- BUG-6's fix, plus OPS-19 (trailing newline) since it lives in the same writer.
- The `workflow-protocol.md` drift, plus OPS-16's scope-containment exemption in the same file.
- OPS-20 filed to the backlog (separate commit).

## Non-goals

- Redeploying via `install.sh`. The deploy sources changed, so `--check` now reports drift; pushing
  to every project on the estate is a separate, explicitly-authorised action.
- Renaming `reviews/<slug>.codex.json`, now a misnomer since fireworks writes it. Belongs with BUG-7,
  which migrates the same consumers.
- Retitling `workflow-protocol.md` ("Claude↔Codex Review Protocol", now inaccurate) — it would mean
  touching all four skill descriptions.
- Moving BUG-6 / OPS-16 / OPS-19 to Done. Doctrine: `/close` writes that after the merge instruction.

## Acceptance criteria

- **AC-1** — `hidden-failure` routes to a model of a different lineage from `correctness`, and the
  reason is recorded in the routing table as revisitable. *(Instruction: "route design to kimi-k3 and
  hidden-failure to deepseek-v4-pro, record those as 'for now' decisions".)*
- **AC-2** — `design` routes to `kimi-k3`, recorded the same way. *(Same instruction.)*
- **AC-3** — the `design` pass runs on the fireworks backend end to end: pass table entry, altitude,
  `/frame` dispatch, and config. *(Instruction: "wire design to fireworks too".)*
- **AC-4** — a schema file that parses as JSON but constrains nothing stops the round before any
  request is made, and nothing is promoted. *(Instruction: "also bug-6"; defect text from BACKLOG
  BUG-6.)*
- **AC-5** — `workflow-protocol.md` states what is actually wired, names no retired backend, and
  lists the artifacts and installed skills that exist today. *(Instruction: "fix #1", referring to
  the doctrine-drift item presented that turn.)*
- **AC-6** — scope-containment ACs categorically exempt the review trail, stated in doctrine and in
  `/frame`'s test-notes guidance. *(OPS-16, folded in per the same turn.)*
- **AC-7** — the gate stays green, and no check silently weakens to accommodate the change.
- **AC-8** — scope containment: no non-review-trail file beyond those the ACs above imply.

## Test notes

Written after the fact — see the header. Per AC:

- **AC-1/AC-2** — `fireworks_runner.py --check-models` confirms both routes live with matching
  context lengths. Gate check `table model reaches the request, per purpose` asserts each critic
  calls the model routed for *its own* purpose. **Demonstrated red:** collapsing
  `resolve_route(purpose, …)` to `resolve_route("correctness", …)` fails it, naming
  `hidden_failure` falling back to `glm-5p2`.
- **AC-3** — `design altitude runs with no base` plus checks that it pushes contract and story and
  **no** diff or commit log. Oracle for "runs for real": a live design review against `kimi-k3` on a
  scratch repo, which returned schema-conforming tagged findings.
- **AC-4** — `a foreign JSON document used as a schema is rejected` (substituting
  `fireworks-models.json`, the exact case that surfaced the bug) and `a file that is illegal as a
  schema is rejected`. **Demonstrated red:** disabling the empty-object probe drops four checks,
  including `nothing promoted` — i.e. the round publishes an artifact from a schema that constrains
  nothing, reproducing BUG-6 as filed.
- **AC-5/AC-6** — no mechanical oracle; these are prose changes to a deployed document. Verified by
  reading. The reviewer is the honest check here, and saying so is better than inventing an
  assertion that cannot fail. `docs_test.sh` covers only README/ARCHITECTURE, not this file — a
  coverage gap left standing deliberately rather than papered over with a wording pin.
- **AC-7** — full gate: 19 + 32 + 113 + 46 + 16 = 226 checks. Two assertions were **changed**, both
  of which encoded coupling this change breaks; each is argued in the diff comments rather than
  silently rewritten. This is the AC most exposed to the retroactive-spec problem.
- **AC-8** — `git diff --name-only main...HEAD -- . ':(exclude)reviews/'`.

## Design sketch — HOW

- **Routing** is data: `fireworks-models.json` entries, no code change.
- **BUG-6** adds `load_schema(name, path)` between parse and use, running two checks because neither
  suffices alone — `check_schema` (catches a file illegal *as* a schema) and an empty-object probe
  (catches a foreign but *legal* schema whose keywords are unrecognised, the case observed).
  `_jsonschema()` is extracted so both it and `validate()` share one import-failure path.
- **Design wiring** is a `PASSES` entry (context: contract + story only — no diff exists at frame
  time), an `ALTITUDES` entry, a `/frame` dispatch block, and `workflow.json`. `--base` becomes
  conditionally required, **derived from the pass table** via a `needs_base` flag on context sources
  rather than special-casing the altitude name.
- **Doctrine** is prose edits plus one folded-in rule (OPS-16).

## Build note (2026-08-04)

| AC | Files |
|---|---|
| 1, 2 | `.claude/skills/review/fireworks-models.json` |
| 3 | `.claude/skills/review/fireworks_runner.py`, `.claude/skills/frame/SKILL.md`, `.claude/skills/review/SKILL.md`, `.claude/workflow.json`, `tests/reviewer_test.sh` |
| 4 | `.claude/skills/review/fireworks_runner.py`, `tests/fireworks_runner_test.py` |
| 5, 6 | `.claude/workflow-protocol.md`, `.claude/skills/frame/SKILL.md` |
| 7 | `tests/fireworks_runner_test.py`, `tests/reviewer_test.sh` |
| 8 | no files — verified by `git diff --name-only` |

OPS-19 (trailing newline) rode along in `promote()`, per BACKLOG's instruction to take it when the
runner is next open. OPS-20 was filed in a separate commit (`BACKLOG.md`).

The unwired-pair STOP in `review/SKILL.md` is now **unreachable** — every pass is wired at both
backends — and was deliberately kept, with a note and a gate pin saying so. It is the fail-closed
guard any future backend inherits the moment its name enters the value set.

## Fireworks approach review (2026-08-04, base main, HEAD ebb1c5b)

Backend `fireworks`, model `glm-5p2`. **Verdict: approve.** Empty findings array — the shape
cleared without a single concern raised, so the correctness altitude ran in the same round per
`/review` step 7.

**Caveat recorded, not glossed:** this pass judged the shape against a spec written *after* that
shape (see the header). A clean approach verdict under those conditions carries less weight than a
clean verdict on a framed story, and should not be cited later as evidence the retroactive-spec
route is sound.

## Fireworks correctness review (2026-08-04, base main, HEAD ebb1c5b)

Backend `fireworks`, model `glm-5p2`.

> The change wires the design pass to fireworks, re-routes hidden-failure to deepseek-v4-pro and
> design to kimi-k3, fixes BUG-6 (vacuous schema validation), updates doctrine, and adds OPS-20 to
> the backlog. The implementation is sound and well-grounded in the spec. I found no correctness
> defects — the BUG-6 fix is thorough (both check_schema and empty-object probe), the design pass
> wiring is consistent across pass table/altitude/frame dispatch/config, --base is correctly derived
> from needs_base flags, and OPS-19's trailing newline is applied. One minor observation and one
> question.

### QUESTION — Empty-object probe assumes every schema has `required`

*Claim.* `load_schema`'s probe validates `instance={}` and expects rejection; the docstring states
"Every schema here carries a non-empty `required`". A future schema that legitimately validates `{}`
(only-optional fields, constraining via `type`/property constraints instead) would be rejected as
"constrains nothing". The probe's semantics are *rejects empty object*, not *constrains something*,
and those are not identical for all possible schemas. Is "non-empty `required`" a permanent
invariant for every schema this runner will ever load?

*Suggestion.* If intended as a permanent invariant, state it in the docstring as a **precondition**
rather than an observation, so future schema authors know the probe will reject them. No code change
needed if the invariant is confirmed.

### NIT — `frame/SKILL.md`'s STOP text stayed design-specific while `review/SKILL.md`'s went generic

*Claim.* The pin `frame still routes an unwired design backend to the stop` passes, and correctly
reflects what `frame/SKILL.md` says. But `review/SKILL.md`'s STOP text was generalised to
"`<backend>` … not wired for the `<pass>` pass" while `frame/SKILL.md` kept design-specific
language — a minor inconsistency between two skills stating one rule.

*Suggestion.* No action required; aligning them would be cleaner but is out of this story's scope.

## Hidden-failure review (2026-08-04, base main, HEAD ebb1c5b)

Backend `fireworks`, model `deepseek-v4-pro` — **the first round run with the two correctness
critics on different model lineages**, which is AC-1's purpose.

> The diff adds explicit error handling (load_schema's multi-layered checks, _jsonschema's import
> guard) and removes no safety checks or assertions. All new error paths surface loudly as
> RunnerError; the conditional --base requirement is derived from the pass table and cannot silently
> skip when needed. No bare except, catch-log-continue, silent fallback, or analogous hidden failure
> is introduced.

**No findings.**

### Deviation recorded — which runner performed this review

`/review`'s command blocks invoke `$HOME/.claude/skills/review/fireworks_runner.py`, the **deployed**
copy. That copy is stale on this branch (`install.sh --check`: `skills/review`, `skills/frame`,
`workflow-protocol.md` all STALE), and its routing table still sends **every** purpose to
`glm-5p2`. Running it would have reviewed this change with the pre-change engine *and* put both
correctness critics back on one model — the exact coupling AC-1 removes. All three passes were
therefore run from the **repo copy** (`.claude/skills/review/fireworks_runner.py`). Deliberate
deviation, recorded because it means this review did not exercise the deployed path.
