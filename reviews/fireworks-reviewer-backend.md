# fireworks-reviewer-backend

Date: 2026-08-03 · Branch: claude/fireworks-reviewer-backend · Status: approved

## Problem

`review/SKILL.md` has carried a pluggable reviewer seam with a second backend (`llm`) parked as
"the designated second source — not yet wired" since OPS-12. A concrete second source now exists:
a Fireworks AI adapter at `/usr/local/bin/fireworks-reviewer` → `/opt/fireworks-backend/reviewer.py`.
Wiring it is worth doing — OPS-13 already records that cross-model critics are an evidence-backed
defense against single-model echo-chamber false positives, which is the loop's core quality risk.

The adapter as shipped cannot be wired safely. Verified on this machine, 2026-08-03:

1. **It does not enforce the schema, and fails silently toward "clean."** The `--schema` flag
   pastes the schema into the prompt as text; the API call uses `response_format={"type":
   "json_object"}`, which guarantees only *syntactically* valid JSON. There is no post-hoc
   validation (`jsonschema` is not installed in its venv). Observed: `qwen3p7-plus` returned `{}`
   on both trials. That parses, passes `jq -e .`, and exits 0 — so the loop's fail-closed promote
   fires and writes an artifact with **no findings**, which in this loop *is* the success signal
   ("empty findings array if there are no issues"). A review that never ran is indistinguishable
   from a clean one. This is the defect that makes every other one secondary.
2. **Its default model is dead.** It defaults to `accounts/fireworks/models/deepseek-r1`, which is
   not on this account; every call without an explicit `--model` returns 404. A hardcoded model id
   in code is exactly the thing that goes stale.
3. **It is unversioned and unreviewable.** It lives outside any repo, owned by `thomasadmin`, so it
   is invisible to `install.sh --check` drift detection and to the review loop that would depend on
   it.

Separately, `tests/reviewer_test.sh` states its own charter: it is a documentation linter with no
oracle, and "if you need a REAL gate, extract the resolver/arg-parser/adapter into executable code
(the heavy-seam follow-up, **which the llm backend will force anyway**) and unit-test THAT." This
story is that forcing event. The design review made it a BLOCKER to stop half way: orchestration
moves into executable code too, not just the API call.

## In scope

**This story wires the correctness altitude only** (the two concurrent critics). Design and approach
follow in a second story, added to the runner's pass table.

- An executable **Fireworks runner** in the repo that owns the backend boundary for the correctness
  altitude: context assembly, concurrent fan-out, join, and all-or-nothing artifact promotion.
- Schema enforcement that fails closed: API-side `json_schema`, explicit overflow `error`, a
  `finish_reason` check, and local validation before any write.
- A versioned, routinely-updatable **model routing table** (purpose → model), replacing hardcoded
  model ids.
- A **versioned Python runtime contract** in the repo — dependency manifest plus one deterministic
  user-local bootstrap — so the repo is authoritative for code *and* what it runs against.
- **Per-pass backend selection**: `reviewer` in `.claude/workflow.json` accepts a purpose→backend
  map, with the existing bare-string form still valid.
- Retiring the `llm` backend name.
- The new behavioral suite added to the configured gate.

## Non-goals

- Wiring the design (`/frame` step 6) and approach (`/review` step 6) passes — second story. They
  stay on `codex`, and selecting an unwired (pass, backend) pair must still stop loudly.
- Reimplementing or restructuring the `codex` backend, or touching its command blocks beyond the
  dispatch line that selects a backend.
- Cost optimisation as a measured claim — see Known limits.
- Any change to the approach→correctness gate, the decision menu, or `/close`.
- `install.sh` building or refreshing a virtualenv — it stays an offline file copier.

## Acceptance criteria

1. **Vendored runner with a versioned runtime contract.** An executable Fireworks runner lives at
   `.claude/skills/review/fireworks_runner.py` in this repo and is the source of truth. A dependency
   manifest with bounded versions (`.claude/skills/review/requirements.txt`) and one deterministic
   user-local bootstrap command are versioned alongside it. Both ride `install.sh`'s existing
   `.claude/skills/review::skills/review` artifact entry to `$HOME/.claude/skills/review/`, so they
   are covered by `./install.sh --check` with no new ARTIFACTS entry. Skills invoke the installed
   copy by absolute path; `/usr/local/bin/fireworks-reviewer` and `/opt/fireworks-backend` are no
   longer used by this workflow.
2. **Schema enforcement, fail-closed.** For every model call the runner sends `response_format` of
   type `json_schema` carrying the caller's schema, sends `context_length_exceeded_behavior: error`,
   and reserves an explicit output-token budget. It rejects any response whose `finish_reason` is
   `length`, and validates the parsed body against that same schema locally before writing. On any
   violation — schema mismatch, unparseable body, truncated completion, API error, missing
   dependency — it writes **no output file** (not even a partial or `.tmp`) and exits non-zero.
3. **Model routing by purpose.** The runner resolves the model for each pass from the routing table
   by purpose. `--model` remains an explicit per-call override. No live model id appears as a literal
   in runner code; a missing or unknown purpose is an error, never a fallback to some default model.
4. **Versioned routing table.** `.claude/skills/review/fireworks-models.json` maps each purpose to a
   model id, a one-line rationale, and the context length the size guard uses, and carries an
   `updated` date. Two checks exist: an **offline** structural check in the gate (parses; every
   purpose the runner can be asked for is routed; no unknown purposes) and an **online**
   `--check-models` mode that verifies each routed id against the live account **and compares the
   stored context length against the live value**. The online check is not in the local gate.
5. **The runner owns correctness-altitude orchestration.** A declarative pass table maps each
   correctness-altitude pass (`correctness`, `hidden-failure`) to its prompt, schema, required
   context, and output artifact. The runner performs the concurrent fan-out, the join, and
   promotion. **Promotion guarantee, stated precisely** (softened from "all-or-nothing" per Thomas's
   2026-08-03 disposition of the approach BLOCKER): if any pass fails, or any artifact fails to
   stage, **nothing** is published. Publication itself is a sequence of same-directory renames, one
   per artifact — atomic *per file*, so no reader can ever see a partial artifact, but not a single
   transaction across files. A process killed between two renames can leave one artifact new and one
   stale. This window is inherent to the existing artifact contract and the `codex` backend shares
   it; closing it means a round-directory or pointer scheme for **both** backends, deferred to its
   own story. The skill retains a thin invocation, not a copied command block.
6. **Declarative context profile, fail-closed.** The correctness altitude's required context is
   declared in the pass table, not assembled ad hoc. The runner verifies every declared input exists
   and is non-empty before building the payload; a missing or empty input aborts with a message
   naming it, and produces no artifact. Assembled size is compared against the routed model's context
   length and aborts before any request when it exceeds budget. Context is assembled **once** per
   altitude and the identical payload is given to both concurrent passes.
7. **Per-pass backend selection.** `reviewer` in `.claude/workflow.json` accepts either a bare string
   (that backend for every pass — the existing form, still valid, and a missing/empty value still
   means `codex`) or a purpose→backend map. This repo's own config is set to the map form with
   `correctness` and `hidden-failure` on `fireworks` and `design` and `approach` on `codex`.
   Selecting a backend for a pass that is not wired stops loudly and never falls back.
8. **`llm` retired.** The `llm` backend name is removed from the documented set, from the accepted
   values, and from its dispatch stops. No configuration may select it; the loud-stop behaviour for
   *unwired* selections survives its removal.
9. **The new suite runs in the gate.** `testCommand` in `.claude/workflow.json` includes the new
   behavioral suite, so ACs 2/3/5/6 are actually exercised by `/review`'s gate rather than existing
   beside it.
10. **Scope containment.** `git diff --name-only main...HEAD` shows no files beyond those this spec
    enumerates, excluding this story's own review-trail artifacts under `reviews/` (per OPS-16, the
    trail is written by the loop itself and is not a scope leak).

## Test notes

Gate (after AC-9): the existing five suites plus `tests/fireworks_runner_test.sh`.

The runner is the repo's first *executable* seam code, so ACs 2/3/5/6 get real oracles — behavioral
tests against the runner with a stubbed API client, no network and no key. AC-7's value parse is
behavioral (it already is, in `reviewer_test.sh`). AC-8 and the thin-invocation half of AC-5 remain
documentation and stay drift-linted per `reviewer_test.sh`'s charter, which is not relaxed.

### Falsification plan

**AC-1 — vendored runner with a versioned runtime contract**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| The runner file in the repo | Absent, or present but unparseable — nothing to install | `gate` — structural check asserts the path exists and parses as Python |
| The dependency manifest | Absent, or pins nothing, so a clean machine resolves different library versions than the reviewed ones | `gate` — assert the manifest exists and every entry carries a bounded version |
| The deployed copy under `$HOME/.claude/skills/review/` | Runner is vendored but never reaches the deployment, so callers run a different copy than the reviewed one | `gate` — `install.sh --check` against a `CLAUDE_WORKFLOW_DEST` temp dir reports runner and manifest in sync |
| A clean runtime environment | Bootstrap does not in fact produce a working environment; only the missing-dependency error path was ever proven | `manual` — bootstrap into an empty user-local venv and complete one successful stubbed run |
| The skill's invocation path | An invocation still resolves to `/usr/local/bin` or `/opt`, so the reviewed code is not the running code | `gate` — assert no wired invocation references either path |

`surfaces excluded`: `/opt/fireworks-backend` and `/usr/local/bin/fireworks-reviewer` as *runtime*
surfaces — under AC-1 they cease to be product surfaces; the only claim retained about them is the
negative one pinned in the row above.

**AC-2 — schema enforcement, fail-closed**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| Response handling | Model returns `{}` (the observed `qwen3p7-plus` behaviour) and the runner exits 0 having written it — the silent false-clean | `gate` — stubbed client returns `{}`; assert non-zero exit |
| Response handling | Well-formed JSON with wrong or extra fields is written anyway | `gate` — stubbed wrong-shape object; assert non-zero exit |
| Response handling | `finish_reason: length` accepted, so a completion cut off mid-object is treated as a real review | `gate` — stubbed truncated response; assert non-zero exit |
| The output artifact on disk | A failed run leaves a partial file, a stray `.tmp`, or a prior round's artifact standing as this round's result | `gate` — after a forced failure, assert neither the artifact nor any `.tmp` sibling exists |
| The API request | `response_format` reverts to `json_object`, losing API-side enforcement while local validation masks the loss | `gate` — assert the request carries `type: json_schema` and the caller's schema |
| The API request | Overflow behaviour left at the provider default (`truncate`), so an oversized prompt yields a clamped completion reported as bad JSON rather than an accurate context error | `gate` — assert the request carries `context_length_exceeded_behavior: error` and an output-token budget |
| Missing-dependency path | Validation library absent, so validation is skipped rather than failing | `gate` — simulate import failure; assert non-zero exit and a named message |

`surfaces excluded`: none.

**AC-3 — model routing by purpose**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| Runner pass resolution | Unknown or missing purpose quietly falls back to some default model instead of erroring | `gate` — assert non-zero exit for absent and for unknown purpose |
| Runner source | A model id is reintroduced as a literal, so the table stops being authoritative and goes stale exactly as `deepseek-r1` did | `gate` — assert no `accounts/fireworks/models/` literal appears in runner source |
| The `--model` override | Override ignored, or applied when it was not given | `gate` — assert the explicit id is what reaches the request, and the table's id otherwise |

`surfaces excluded`: none.

**AC-4 — versioned routing table**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| The table file | Malformed JSON, or a purpose the runner can be asked for is unrouted — discovered only mid-review | `gate` — offline check parses the table and asserts routed purposes exactly match the runner's pass table |
| Each route entry | An entry loses its context length, so AC-6's size guard silently has nothing to compare against | `gate` — assert every route carries a positive integer context length |
| The live Fireworks account | A routed id is syntactically fine but no longer served — the `deepseek-r1` failure, silent until a review is attempted | `manual` — `--check-models` against the account; deliberately outside the gate (network + credential) |
| The live model metadata | Stored context length drifts from the live value, so the size guard passes a payload the model will reject | `manual` — `--check-models` compares stored against live |
| The table's rationale and `updated` fields | Routing changes land with no recorded reason or date, so "routinely update" degrades into untraceable drift | `reviewer` — judgment at the correctness altitude |

`surfaces excluded`: none.

**AC-5 — the runner owns correctness-altitude orchestration**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| The pass table | A pass loses its schema or output binding and silently reuses another pass's, so two artifacts carry the same review | `gate` — assert each pass resolves to a distinct schema and artifact path |
| Concurrent execution | Passes run sequentially, losing the divided-parallelism property OPS-12 established | `gate` — stubbed client records call overlap; assert concurrency |
| The join | One pass fails and the other's artifact is promoted anyway, so the round reports a partial review as complete | `gate` — force one pass to fail; assert **neither** artifact is promoted and exit is non-zero |
| The promoted artifacts | A prior round's artifacts survive a failed round and are read as this round's result | `gate` — pre-place stale artifacts, force failure, assert they are not presented as current |
| `review/SKILL.md` step 8 | The thin invocation regrows into a copied command block, returning the logic to unlinted prose | `reviewer` — judgment at the approach altitude |

`surfaces excluded`: none.

**AC-6 — declarative context profile, fail-closed**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| Each declared input (contract, story, diff, history) | A missing file writes to stderr, assembly continues, and the reviewer critiques a diff without its own contract — returning confident findings against rules it never read | `gate` — remove each declared input in turn; assert abort, non-zero, no artifact |
| An input that exists but is empty | An empty diff or story passes an existence check and yields a review of nothing | `gate` — assert non-empty is required, not merely present |
| The assembled payload | Payload exceeds the routed model's context and is sent anyway | `gate` — oversized input asserts a named abort before any request is made |
| The payload given to each concurrent pass | Context is rebuilt per pass, so the two concurrent critics review different payloads and their findings are no longer partitioned by concern alone | `gate` — assert both stubbed calls receive byte-identical context |
| Temp files | A `mktemp` template with a suffix after the `X`s returns an unrandomised literal path (verified: BSD `mktemp` does this), so concurrent passes share one file and clobber each other | `gate` — assert every template ends in `X`s and resolves to a unique path |

`surfaces excluded`: none.

**AC-7 — per-pass backend selection**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| `.claude/workflow.json` value parse | The map form is rejected as invalid, so per-pass selection cannot be configured at all | `gate` — assert the map form parses to valid per-pass backends |
| `.claude/workflow.json` value parse | The bare-string form breaks, silently breaking every other repo using this workflow | `gate` — assert bare string still resolves that backend for every pass, and missing/empty still means `codex` |
| This repo's own config | Correctness and hidden-failure are not actually on `fireworks`, so the story ships without turning on what it built | `gate` — assert this repo's config routes those two passes to `fireworks` |
| An unwired (pass, backend) pair | Selecting `fireworks` for design or approach falls back to codex instead of stopping — the silent degradation the seam's loud-stop rule exists to prevent | `gate` — drift pin that the stop is scoped to unwired pairs and forbids fallback |
| `review/SKILL.md` resolution rule | The documented precedence and the implemented one disagree | `reviewer` — judgment at the approach altitude |

`surfaces excluded`: none.

**AC-8 — `llm` retired**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| The accepted value set | `llm` still parses as valid, so a stale config selects a backend that no longer exists anywhere | `gate` — assert `llm` is rejected |
| `review/SKILL.md` and `frame/SKILL.md` prose | Dangling references to `llm` survive, so the docs describe a backend the tests reject | `gate` — assert no `llm` backend references remain |
| The loud-stop behaviour itself | Removing `llm` removes the *only* stop, so a future unwired backend silently falls back | `gate` — the unwired-pair stop from AC-7 still passes with `llm` gone |

`surfaces excluded`: none.

**AC-9 — the new suite runs in the gate**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| `testCommand` in `.claude/workflow.json` | The suite exists but is not in the gate, so every oracle above is dead weight — the exact miss the design review caught | `gate` — assert `testCommand` names the new suite |
| The suite's own exit status | The suite is in the gate but always exits 0, so it can never fail the round | `gate` — demonstrate red: break one assertion, observe the gate fail, revert |

`surfaces excluded`: none.

**AC-10 — scope containment**

| Surface | Regression that must be caught | Oracle |
|---|---|---|
| The branch diff | Files land outside what this spec enumerates | `manual` — run `git diff --name-only main...HEAD` and verify no file appears beyond those the ACs enumerate, excluding this story's own `reviews/` trail |

`surfaces excluded`: n/a — the criterion names a single observable (the branch diff).

### Known limits

- **Review quality under these models is unproven and no oracle covers it.** Every gate above checks
  *shape* — that a finding is schema-valid, that a failure fails. None can tell a thorough review
  from a shallow one. A model that returns two obvious findings and misses the real defect passes
  everything here. Thomas has accepted this risk in making `fireworks` the correctness-altitude
  backend (see Design decisions); it is recorded here because no test in this story retires it.
- **"Cheap" is unverified.** The Fireworks models endpoint returns capability metadata but no
  pricing, so the cost half of "cheap high-performing right-fit" cannot be checked from the API. The
  routing table can carry a cost field, but it must be populated by hand and will go stale the same
  way a model id does.
- **`qwen3p7-plus` is not a safe route.** It is `kind: CUSTOM_MODEL`, reports no context length at
  all (so AC-6's size guard would have nothing to compare against), and was the weakest of three
  tested on structured output. The 262k figure attributed to it elsewhere is exactly
  `kimi-k2p7-code`'s window and appears misattributed.

## Build note (2026-08-03)

| AC | Files |
|---|---|
| 1 — vendored runner + runtime contract | `.claude/skills/review/fireworks_runner.py`, `.claude/skills/review/requirements.txt` |
| 2 — schema enforcement, fail-closed | `fireworks_runner.py` (`run_pass`, `validate`, `promote`) |
| 3 — routing by purpose | `fireworks_runner.py` (`load_routes`, `resolve_route`, `KNOWN_PURPOSES`) |
| 4 — versioned routing table | `.claude/skills/review/fireworks-models.json`, `tests/fireworks_runner_test.py` |
| 5 — runner owns orchestration | `fireworks_runner.py` (`PASSES`, `ALTITUDES`, `run_altitude`, `promote`), `.claude/skills/review/SKILL.md` (step 8 thin invocation) |
| 6 — declarative context profile | `fireworks_runner.py` (`CONTEXT_SOURCES`, `assemble_context`, `check_size`) |
| 7 — per-pass backend selection | `.claude/workflow.json`, `.claude/skills/review/SKILL.md`, `.claude/skills/frame/SKILL.md`, `tests/reviewer_test.sh` |
| 8 — `llm` retired | `review/SKILL.md`, `frame/SKILL.md`, `README.md`, `ARCHITECTURE.md`, `BACKLOG.md` (annotated), `tests/reviewer_test.sh` |
| 9 — suite in the gate | `.claude/workflow.json`, `tests/fireworks_runner_test.sh`, `tests/fireworks_runner_test.py` |
| 10 — scope containment | (no file — verified against the branch diff) |

## Build note — round 2 (2026-08-03)

Re-review scope only; the AC→file map above is unchanged. Round-2 commits touch:

| Approved finding | Files |
|---|---|
| Hidden-failure IMPORTANT — `finish_reason` too narrow | `.claude/skills/review/fireworks_runner.py` (`run_pass`), `tests/fireworks_runner_test.py` |
| Correctness NIT — unguarded `response.choices[0]` | `.claude/skills/review/fireworks_runner.py` (`run_pass`), `tests/fireworks_runner_test.py` |

## Falsification-plan amendments

The approved plan is append-only. Every change below is recorded, never applied in place.

**1 — retract · AC-6 · surface: "Temp files" (the shell `mktemp` template row) · added at: implement**

The row's regression is a *shell* `mktemp` template with a suffix after the `X`s. The approved
design put promotion inside the runner, so the fireworks path has no shell template anywhere — the
skill's invocation is one command and the runner uses `tempfile.mkstemp`, which is unique by
construction and cannot take a malformed template. The row therefore targets a mechanism this
implementation does not have, and could only ever pass vacuously. Retracted, not removed: the
retraction is itself a claim the reviewer may reject, and the codex block it was modelled on still
carries the real shell templates (pinned separately in `reviewer_test.sh`).

**2 — add · AC-6 · surface: the runner's temp paths under concurrency · added at: implement**

The risk the retracted row was reaching for is real and still applies at the surface that does
exist: two concurrent passes must not collide on a temp path, and no temp may survive a successful
promote. Demonstrated red: forcing both passes through a single fixed temp name collapses
`each promoted artifact used a unique temp path` (2 unique paths expected, 1 observed).

**3 — add · AC-1 · surface: the repo's `.claude/skills/review/` after a test run · added at: implement**

Implementation revealed a surface spec-time did not anticipate: this repo had no Python before, so
nothing had ever written bytecode. `tests/fireworks_runner_test.py` *imports* the runner, which
drops `__pycache__` beside it — inside the directory `install.sh` deploys verbatim. Committing that
would ship bytecode to every deployment and then read back as drift in `./install.sh --check`,
permanently. Guarded by `-B` in the suite's wrapper plus a `.gitignore` entry.

*Correction recorded against my own first reading:* I initially attributed this to the skill's
runtime invocation and wrote that rationale into `review/SKILL.md`. The demonstrate-red disproved
it — running the runner as a **script** never writes bytecode; only **importing** it does, which is
what the test suite does. The note in the skill and in `.gitignore` was corrected to state the real
mechanism. A wrong "keep this because X" is worse than no note, because the next person disproves X
and removes the guard.

**4 — add · AC-5 · surface: promotion of the artifact *set* · added at: implement**

The plan's AC-5 rows covered "one pass fails ⇒ neither artifact promoted" (a *review* failure) but
not a failure during promotion itself. A live smoke run against this very branch surfaced it: the
first `promote()` renamed each artifact as it went, so a failure on the second would leave the first
already promoted and the round half-reviewed. Restructured into stage-all-then-commit-all.
Demonstrated red: reverting to rename-as-you-go trips
`a failure staging the 2nd artifact promotes NEITHER` (`partial promotion: ['demo.codex.json']`).

*Provenance worth recording:* this was found by the backend reviewing its own branch — both the
correctness and hidden-failure critics flagged it independently, which is the divided-parallelism
property working as designed.

**5 — add · AC-2 · surface: the schema file itself · added at: implement**

An unparseable schema file fell through to the generic handler and reported "unexpected error",
naming no cause. Now caught and named. Demonstrated red by pointing the pass at a deliberately
malformed schema and asserting the message identifies it.

**6 — add · AC-4 · surface: the routed-purpose vocabulary · added at: implement**

AC-4 requires "no unknown purposes", but the approved design deliberately routes `design` and
`approach` **ahead of use** so the follow-up story is a dispatch change. A literal reading — routes
must equal the wired passes — would fail by construction. The check implemented is the one the
criterion actually means: every routed purpose must be a real review purpose (`KNOWN_PURPOSES`),
while routing ahead of wiring stays legal. Recorded because it narrows an approved criterion's
reading, which is Thomas's to reject.

**7 — add · AC-8 · surfaces: `README.md` and `ARCHITECTURE.md` · added at: implement**

AC-8's approved row named "`review/SKILL.md` and `frame/SKILL.md` prose" as the surface for dangling
`llm` references, and its `surfaces excluded` said `none`. That was **under-enumerated**: both
`README.md` and `ARCHITECTURE.md` describe the reviewer seam as current behaviour and both named
`llm` as the second backend, so retiring it left two documents actively wrong while the gate stayed
green. This is precisely the failure the extent claim exists to prevent, and the approved plan did
not catch it — the criterion ("removed from the documented set") plainly spans every doc that
documents the set, not only the two skill files I happened to be editing.

Both updated; pins added for the removal *and* for the positive claim (each doc must describe the
backend that actually exists, or the next rename leaves them silently empty). Demonstrated red by
reintroducing an `llm` sentence into `README.md`.

`BACKLOG.md`'s OPS-11 analysis also says `reviewer: {codex, llm}`, but that is a **dated record of
reasoning**, not a description of current behaviour. It keeps its text with a terminology note
rather than being rewritten — editing the historical record to match today would destroy the thing a
backlog is for.

**8 — add · AC-9 · surface: `.github/workflows/ci.yml` · added at: implement**

AC-9's approved row named `testCommand` in `.claude/workflow.json` as the surface and declared no
exclusions. Under-enumerated again, and worse than amendment 7: **CI is the *authoritative*
server-side gate** — `ci.yml` calls itself that, and branch protection requires its `gate` job.
Its suite list is hardcoded and did not include the new behavioral suite, so the strongest-looking
check was about to run a weaker gate than the local one, with every new oracle absent from it.

Codex's design review named this precisely — *"absent from the stated gate, `.claude/workflow.json`
test command, **and CI gate command**"* — and I fixed only two of the three while marking the finding
*Fix*. Recording that plainly: a partially-applied BLOCKER disposition is not a fixed BLOCKER.

`ci.yml` now bootstraps the runner's dependencies (the suite stubs the API client, so it needs no
network at run time and **no credential** — no secret is introduced) and runs the full gate. A new
behavioral pin compares `ci.yml`'s gate command against `workflow.json`'s `testCommand` as strings,
so the two can no longer drift silently. Demonstrated red by removing the suite from `ci.yml`.

**Sizing correction, no plan change:** the output reservation was first set to 8,000 tokens, and the
live run truncated a real review of this branch — the runner refused to promote it, which is how it
was found rather than shipped. Raised to 32,000 (verified accepted up to 131,072 on the routed
model). No falsification row changes; `finish_reason: length` was already covered and is what caught it.

## Codex approach review (2026-08-03, base main, HEAD 2e3f7ff)

**Verdict — not sound yet.** The centralized runner, declarative pass/context tables,
standard-library concurrency, routing data, and `jsonschema` validation are appropriate. However,
the publication model cannot provide its promised round-level atomicity, and the model override
separates model identity from the metadata required by the size guard.

### BLOCKER — Two renames do not form an atomic review round
*one-way · kludgy · locus: `fireworks_runner.py` (`promote`); `review/SKILL.md` step 8 artifact contract*

One logical review round is represented as two independently replaced stable files. Staging both
first stops a *staging* failure from publishing partial output, but the `os.replace` loop can still
publish the first artifact and fail on the second. The runner acknowledges this is not a multi-file
transaction, while AC-5 and the skill present both-or-neither promotion as an invariant. Every
future critic added to the altitude copies this pattern.

**Alternative:** write every result into one immutable, round-specific directory, fsync it, then
publish with a single atomic directory rename or current-round pointer; consumers resolve artifacts
only through that committed reference.
**Win:** one atomic commit point instead of a probabilistic sequence, centralizing the invariant for
all future critics.

### IMPORTANT — The model override bypasses the routing contract's metadata
*one-way · kludgy · locus: `fireworks_runner.py` (`run_pass`, `--model`)*

`--model` changes the live model id while the size guard keeps using the *configured route's*
`contextLength`. Model identity and the metadata needed to run it safely come from different
records: a smaller override passes a preflight sized for the routed model's larger window and fails
only after the request; a larger override is constrained by unrelated metadata.

**Alternative:** make an override supply a complete route record (id *and* context length), or drop
the raw override and require a temporary routing-table entry.
**Win:** one authoritative model contract, with the preflight guard applying to the model actually
called.

## Fireworks review (2026-08-03, base main, HEAD ee53291)

*First review run by the `fireworks` backend — `glm-5p2`, correctness altitude, both critics
concurrent.*

**Summary.** The runner, routing table, runtime contract, behavioral suite, CI integration, and
documentation updates all align with the spec's acceptance criteria. The error model is consistently
fail-closed — every failure path stops the round, writes no artifact, and exits non-zero. No
swallowed exceptions or silent degradations found. One minor diagnostic gap.

### NIT — `response.choices[0]` accessed without guarding against empty choices

If the API returned an empty `choices` list, the direct index raises `IndexError`, which reaches
`run_altitude`'s generic handler and surfaces as "unexpected error" rather than a named cause. Still
fail-closed — the round stops and nothing is promoted — but less actionable than the rest of the
runner's error model, which consistently names its failure.

## Hidden-failure review (2026-08-03, base main, HEAD ee53291)

**Summary.** Error model generally sound: exceptions wrapped in `RunnerError` and re-raised, failures
stop the round and promote nothing, temps cleaned on staging failure, `main()`'s catch-all exits
non-zero. One finding.

### IMPORTANT — `finish_reason` accepts `content_filter` and other abnormal reasons

`run_pass` rejects only `finish_reason == "length"`. Any other non-`stop` reason — most importantly
`content_filter`, where the model's output was altered or suppressed by safety filtering — falls
through silently. The body may still be valid JSON conforming to the schema (a partial or sanitized
findings array), so schema validation does not catch it. The model is signalling that the completion
went wrong and the runner ignores the signal, promoting a degraded review as a clean one — the exact
silent-degradation pattern this lens targets.

## Decisions (2026-08-03)

Round 1. All three critics that ran this round, with Thomas's call per finding.

**Approach pass (codex)** — *"accept imperfect atomicity and soften the claim in AC-5. accept the
important-2 recommendation"*

| Finding | Decision |
|---|---|
| BLOCKER — two renames do not form an atomic review round | **Accept**, with the overclaim corrected. AC-5, `review/SKILL.md`, and the runner docstrings now state the true guarantee; the residual window is named, and closing it (a round-directory scheme spanning *both* backends) is deferred to its own story. Applied in `ee53291`. |
| IMPORTANT — `--model` bypasses the routing contract's metadata | **Accept the recommendation.** `--model` now requires `--context-length`, so an override is a complete route and the size guard applies to the model actually called. Applied in `ee53291`. |

**Correctness pass (fireworks / glm-5p2)** — *"fix both"*

| Finding | Decision |
|---|---|
| NIT — `response.choices[0]` unguarded against empty `choices` | **Fix.** |

**Hidden-failure pass (fireworks / glm-5p2)** — *"fix both"*

| Finding | Decision |
|---|---|
| IMPORTANT — `finish_reason` accepts `content_filter` and other abnormal reasons | **Fix.** Same failure shape as the `{}` defect that motivated this story: an abnormal condition yielding a schema-valid artifact that reads as a clean review. |

Routing to `/close` to apply the two fixes. **This is not a merge authorization** — `/close` stops at
its merge fork and requires a separate, explicit instruction.

## Fixes (2026-08-03)

Both round-1 fixes Thomas approved, applied in `run_pass`.

**Correctness NIT — unguarded `response.choices[0]`.** An empty `choices` list is now caught and
named ("returned no choices — the API produced no completion at all") instead of raising `IndexError`
into the generic handler. Behaviour was already fail-closed; this makes the diagnostic match the rest
of the runner's error model. *Red demonstrated:* disabling the guard trips 2 checks.

**Hidden-failure IMPORTANT — narrow `finish_reason` check.** `run_pass` now accepts **only** `stop`.
`length` keeps its own message because its remedy is specific (raise the output budget); every other
value — `content_filter` foremost, but also unknown reasons a future API version might introduce —
is rejected with a message naming altered/suppressed output. The reasoning is recorded in the code:
a filtered or abnormal completion can still be valid JSON satisfying the schema, so validation cannot
catch it, and promoting it would repeat the `{}` failure shape that motivated this whole backend.
*Red demonstrated:* accepting non-`stop` reasons trips 11 checks.

Suite grew 66 → 80 checks; full gate 341 → 355, green.

## Observed, not fixed — for the review round

**A structurally-valid but meaningless schema makes validation vacuous.** JSON Schema treats
unrecognised keywords as no-ops, so a schema file that is well-formed JSON but not a real schema
would validate *anything* — and the runner would promote it. This surfaced while writing the AC-2
schema test (substituting one valid JSON file for another did not fail). It is a genuine
hidden-failure shape in code this story adds, but guarding it means validating the schema itself,
which is scope this story did not carry. Flagged rather than silently added.

## Test notes — demonstrate-red results (2026-08-03)

Every `gate` oracle in the approved plan was driven red by applying its planned regression, then
reverted. Full harness output retained in the session; summary:

| AC | Regression applied | Result |
|---|---|---|
| AC-2 | `json_schema` → `json_object` | RED (2 checks) |
| AC-2 | accept `finish_reason: length` | RED (2) |
| AC-2 | remove local schema validation | RED (6, incl. `{}` accepted and artifacts written) |
| AC-2 | drop `context_length_exceeded_behavior: error` | RED (1) |
| AC-3 | reintroduce a hardcoded model id | RED (1) |
| AC-3 | unknown purpose falls back instead of erroring | RED (1) |
| AC-5 | run the altitude sequentially | RED (1 — barrier times out) |
| AC-5 | promote whatever succeeded | RED (13) |
| AC-6 | accept a missing/empty context input | RED (4) |
| AC-6 | skip the pre-flight size guard | RED (3) |
| AC-6 | rebuild context per pass | RED (1) — see note |
| AC-9 | break one suite assertion | gate exits 1 |

**AC-6 "rebuild context per pass" — first regression was faulty, not the assertion.** Appending a
constant to the shared payload left both passes still byte-identical, so nothing went red. The
regression the row actually describes — handing each pass a *different* payload — drives
`both passes receive byte-identical context` red. The assertion is live; my first attempt at
falsifying it was not. Recorded because a regression that stays green is indistinguishable from a
dead assertion until you check which one it is.

**AC-1 deployment/`--check` rows** are `manual` oracles by plan and were run by hand: deploy to a
temp `CLAUDE_WORKFLOW_DEST`, execute the deployed runner, re-run `./install.sh --check` → in sync,
8/8 artifacts. Bootstrap into an empty user-local venv completed and ran `--check-models` green
against the live account (4/4 routes live, stored context lengths match).

## Open questions

**Q5 — Does the owed OPS-13 note ride with this story?** `retired/deep-audit-engine` and
`retired/deep-audit-lib` tags exist, but `BACKLOG.md` still reads "OPS-13 stays open (BEGUN, not
done): the execution-engine slice remains." That note is owed. It is unrelated to this scope, so it
is **not** assumed in — still Thomas's call, and it can ride with the second story instead.

## Design sketch — HOW

**Shape.** One vendored Python package plus two data files under `.claude/skills/review/`, all
inheriting the existing install + drift-check path with no change to `install.sh`'s ARTIFACTS array.
`review/SKILL.md` step 8 loses its fireworks-specific command block in favour of a thin invocation.

**Runner.** `fireworks_runner.py` owns the backend boundary:

- *Pass table* — declarative, mapping each pass (`correctness`, `hidden-failure` this story) to
  prompt, schema path, required context inputs, and output artifact. Adding the design and approach
  passes in the second story is a table entry, not new orchestration.
- *Routing* — read `fireworks-models.json` beside the module; resolve purpose → `{model,
  contextLength}`; unknown purpose is a hard error. No model literals in code.
- *Context assembly* — build once per altitude from the pass table's declared inputs; each verified
  present and non-empty first; size-checked against the route's context length before any request;
  the identical payload handed to every pass at that altitude.
- *Request* — `response_format={"type":"json_schema","json_schema":{"name":…,"schema":schema}}`,
  `context_length_exceeded_behavior="error"`, an explicit `max_tokens` budget. Verified working
  against both production schemas on `glm-5p2`.
- *Validation* — reject `finish_reason: length`, parse, then validate against the same schema with
  the `jsonschema` library. Two layers because API-side enforcement is grammar-constrained but not a
  guarantee across model versions, and the local check costs nothing. Deliberately **not**
  hand-rolled: AGENTS.md's guardrail is not to hand-roll what one declarative construct covers.
- *Concurrency and join* — the passes at one altitude run concurrently; the join is all-or-nothing.
  Temps are `reviews/`-local with the `X`s last (same-filesystem atomic rename), matching the codex
  block's proven pattern. Any failure promotes nothing.
- *Error model* — one failure path. Any of {missing dep, missing or empty input, oversized payload,
  API error, truncated completion, unparseable body, schema violation} → message naming the cause, no
  file written, exit non-zero.

**Runtime contract.** `requirements.txt` beside the module with bounded versions for `openai` and
`jsonschema`, plus a documented one-line bootstrap into a user-local venv under `$HOME/.claude/`.
`install.sh` stays an offline file copier; the runner fails closed with an actionable message naming
the bootstrap command if its environment is absent.

**Backend selection.** `reviewer` in `.claude/workflow.json` widens from string to
string-or-purpose-map. Resolution stays: per-invocation override beats config beats the `codex`
default; a bare string means that backend for every pass; missing or empty still means `codex`.
Backend selection lives in the per-repo config while *model* routing lives in the per-machine skill
artifact — the two are different concerns and belong in different files. `reviewer_test.sh`'s
existing behavioral parse check widens to cover both forms; the `llm` pins are removed and the
loud-stop pins are re-scoped from "non-codex" to "unwired", which is what they always meant.

**Testing.** `tests/fireworks_runner_test.sh` drives the runner with a stubbed client — no network,
no key — for ACs 2/3/5/6, and structurally checks the routing table for AC-4. It is added to
`testCommand`. `reviewer_test.sh` gains the AC-7/AC-8 pins only; its charter against growing into a
pseudo-behavioral suite is respected, because the behavioral checks now have real code to live
against.

## Codex design review (2026-08-03)

**Verdict — not sound yet.** Vendoring the adapter, using Fireworks `json_schema`, validating again
with `jsonschema`, and centralizing model routes are good choices. But the proposed shape stops short
of the executable harness this second backend was supposed to force, does not define sufficient
pass-specific context for a non-agentic reviewer, and leaves the Python runtime unversioned.

### BLOCKER — The executable seam stops at the API adapter
*one-way · kludgy · locus: Design sketch (Skill dispatch, Testing); AC-5 and AC-7 plans*

Backend orchestration — pass selection, context assembly, correctness fan-out, joining, artifact
promotion — stays as copied imperative prose across `frame/SKILL.md` and `review/SKILL.md`. That is
the heavy seam `tests/reviewer_test.sh`'s charter said this backend would force. So AC-5 and AC-7
still rest on implementation-token drift pins (PID capture, stop wording) rather than behavioral
oracles. The proposed adapter suite is also **absent from the configured gate** in
`.claude/workflow.json`, so its real oracles would never run. The AC-7 `reviewer` oracle for
mismatched sibling payloads is effectively circular with the discrepancy it is meant to catch.

**Alternative:** make one executable Fireworks runner the backend boundary, with a declarative pass
table mapping each pass to prompt, schema, required context, output, and critic grouping. The runner
owns concurrency and all-or-nothing promotion; each skill keeps a thin invocation. Exercise it
behaviorally and add the suite to the gate.
**Win:** removes repeated command-block logic, centralizes the fail-closed invariant, and turns
AC-5–AC-7 from prose-token checks into executable behavior.

### BLOCKER — The pushed-context contract cannot preserve reviewer grounding
*one-way · kludgy · locus: AC-6, its plan, and Design sketch (Adapter / Size guard)*

AC-6 treats `AGENTS.md` + story + non-empty diff as one generic input set, but the four invocations
have different grounding. **The frame design review runs before any code exists — there is no diff**,
so AC-6's own non-empty-diff requirement makes that pass impossible. Approach needs the full changed
files and dependency manifest, not merely their diff; correctness needs story, diff, and history.
Those product surfaces are unenumerated, so a schema-valid but blind review passes. The byte
approximation also does not establish fail-closed behavior, and `--check-models` only verifies route
existence rather than comparing stored context length against live metadata.

**Alternative:** a declarative context profile per pass, each falsified independently; set provider
overflow behavior to `error`; reserve an explicit output-token budget and fail on
`finish_reason: length`; have `--check-models` compare stored vs live context length.
**Win:** eliminates the impossible frame-time diff requirement and stops incomplete or truncated
context from producing a false-clean review.

*Verified against the Fireworks API reference, 2026-08-03:* `context_length_exceeded_behavior` is
real, its allowed values are `error` and `truncate`, and **`truncate` is the default**. The precise
mechanism differs slightly from the finding's wording: `truncate` clamps `max_tokens` to
`context_window_length - prompt_length` rather than silently dropping prompt text. The practical
failure is therefore a truncated or empty completion, not a quietly shortened context — but the
correction stands, because that surfaces as an unparseable-JSON error whose message names the wrong
cause. Requesting `error` explicitly, plus a `finish_reason` check, is what makes the diagnostic
accurate.

### IMPORTANT — The runtime dependency contract is outside the repository
*one-way · kludgy · locus: Open question Q3; Design sketch (Shape / Validation)*

The repo has no Python dependency manifest, yet the vendored "source of truth" is a module plus JSON
that require `openai` and `jsonschema`. Q3 recommends a hand-made user-local virtualenv with no
versioned dependency contract or stable entrypoint. Failing closed on missing imports proves only the
error path; it does not make the success path reproducible. AC-1's `/opt` row is also an
implementation-shaped legacy surface: under Q2(b) the product surfaces are the installed entrypoint
and its runtime environment, and `/opt` should be an explicit exclusion instead.

**Alternative:** resolve Q3 before approval; add a versioned dependency manifest with bounded
versions plus one deterministic user-local bootstrap command. `install.sh` stays an offline file
copier, but deployment checks verify entrypoint and environment separately. Update AC-8's scope.
**Win:** makes the repo authoritative for code *and* runtime, drops the admin-owned `/opt`
dependency, and lets a clean-environment test reproduce a successful run rather than only a failure.

## Design decisions (2026-08-03)

Thomas's scope decision, verbatim: **"go with B, retire llm, all four on glm-5p2; make fireworks the
default"** — followed by, on the sequencing conflict that raised, **per-pass backend in the table**.

| Design finding | Disposition |
|---|---|
| BLOCKER — executable seam stops at the API adapter | **Fix.** Scope option B: the runner owns orchestration, but only the correctness altitude is wired this story. Design and approach follow in a second story as pass-table entries. Deferring the runner itself was rejected because it would mean writing four prose command blocks now and deleting them later. |
| BLOCKER — pushed-context contract cannot preserve grounding | **Fix.** Context becomes a declarative per-pass profile (AC-6). Only the correctness altitude's profile is built this story; the impossible frame-time non-empty-diff requirement is gone with it. Overflow `error`, output-token budget, `finish_reason` check, and stored-vs-live context comparison all adopted. |
| IMPORTANT — runtime dependency contract outside the repo | **Fix.** Bounded dependency manifest and a user-local bootstrap versioned in the repo (AC-1). `install.sh` stays a file copier. `/opt` and `/usr/local/bin` are dropped from the workflow and become an explicit exclusion in AC-1's plan. |

**One-way doors ratified:**
- **Per-pass backend selection.** `reviewer` widens from a scalar to a purpose→backend map. Additive
  and walkable back by dropping the field, but it is the seam's model going forward — and it is the
  end state OPS-13's cross-model-diversity argument points at anyway.
- **`llm` retired.** A name that can only ever stop is dead surface now that a real second source
  exists. Nothing sets `reviewer: llm` today.
- **`fireworks` becomes the correctness-altitude backend.** Thomas asked for fireworks as the
  default; per-pass routing delivers that everywhere it is wired without breaking `/frame` or the
  approach pass on an unwired backend. **Accepted risk, stated once and not re-litigated:** review
  quality under `glm-5p2` is unverified, and no gate in this story can distinguish a thorough review
  from a shallow-but-schema-valid one.
- **Q2/Q3 taken as recommended, not explicitly ruled on:** skills invoke the installed copy by
  absolute path; `/usr/local/bin` and `/opt` are abandoned; a user-local venv keeps the privileged
  account off the routine path. Flagged here so it is visible and correctable.

**Model routing:** all four purposes on `accounts/fireworks/models/glm-5p2` (1,048,576 context;
verified 2026-08-03 returning schema-conforming output against both production schemas). The two
unwired purposes are routed in the table now so the second story only has to wire dispatch.
