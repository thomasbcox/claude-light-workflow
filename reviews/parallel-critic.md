Date: 2026-07-17 · Branch: claude/parallel-critic · Status: approved

# parallel-critic — a second, independent critic on the correctness altitude

## Problem

Today `/review` runs **one** external critic per pass: the correctness pass is a single `codex exec`
carrying every correctness concern at once — spec-drift, edge cases, security, data-loss, business
logic, **and** hidden failure. OPS-11 named the risk that this breadth **dilutes** any one lens; OPS-12
recorded the fix as **divided parallelism** — run more than one independent critic concurrently, each
asking a **different** question, so findings partition by concern instead of competing for one
critic's attention.

This story stands up the **parallel-critic seam** with its first, minimal, high-value lens:
a dedicated **hidden-failure** critic that runs concurrently with the existing correctness pass and
does nothing but hunt swallowed / absorbed / silently-degrading error handling. It is the most
**orthogonal** lens to the existing correctness pass (least overlap → cleanest division), and its
reviewer contract **already exists** in `AGENTS.md` ("Hidden failure" bullet). It is OPS-11's parked
anti-pattern pass, built as OPS-12's first citizen.

## In scope

- A **second critic** in `/review` **step 8** (the correctness altitude), launched **concurrently**
  with the existing correctness `codex exec`, same resolved reviewer backend, read-only.
- Its **own focused prompt** (hidden failure only), its **own schema** `hidden-failure-schema.json`, and
  its **own artifact** `reviews/<slug>.hidden-failure.json` — the **standing per-critic rule**: every
  parallel critic henceforth owns its schema and its artifact (Thomas, 2026-07-17).
- A **divided-parallelism reconciliation**: the critic's findings become their **own section** in the
  story file and their **own section** in the step-9 decision menu — grouped, not consensus-voted.
- Drift-detection checks in `tests/reviewer_test.sh` for the new critic's tokens/phrases, staying
  inside that file's stated linter charter.
- Carrying the **already-uncommitted `BACKLOG.md`** OPS-12 update into this branch and committing it
  here, plus a one-line pointer on OPS-12 to this story as its build.

## Non-goals

- **Not** the `llm` backend — it stays a loud not-yet-wired stop. Parallelism here is two roles on the
  **already-wired codex** backend, not two backends.
- **Not** a general/config-driven critic **registry** or multiple selectable lenses — exactly **one**
  hardcoded second critic. A second lens is a later story.
- **Not** any change to the **approach→correctness gate** or its short-circuit. Parallelism lives
  *within* the correctness altitude, never across the two altitudes.
- **Not** editing `finding-schema.json`, `design-review-schema.json`, the existing correctness
  **prompt/artifact**, `AGENTS.md`, `install.sh`, or `.claude/workflow.json`. The existing correctness
  pass keeps covering hidden failure too; the dedicated critic is an *additional* undiluted look, with
  obvious cross-section duplicates dropped.
- **Not** a consensus/voting/merge engine — separate section *is* the reconciliation.

## Acceptance criteria

1. **Step-8 orchestration (the concurrency invariant).** `/review` **step 8** launches the existing
   correctness critic **and** a dedicated **hidden-failure** critic **concurrently** — both
   `codex exec -s read-only`, each with its own `</dev/null`, under the **same resolved reviewer
   backend** (the `llm` stop still applies before either launches). Each is backgrounded with its
   **PID captured**; a **per-PID `wait`** records each critic's **explicit exit status**. Each writes a
   **fresh temp file**, validated (present + parseable JSON) and only then **atomically promoted** to
   its stable `reviews/<slug>.*.json` path. **Fail-closed:** a nonzero exit **or** an invalid artifact
   from *either* required critic **stops the round** — record which failed + how to rerun, present
   **no** decision menu and route to **no** `/close`; a recorded round always holds valid output from
   **every** required lens.
2. The hidden-failure critic uses a **focused prompt** — only swallowed/absorbed/silently-degrading
   error handling per `AGENTS.md`'s "Hidden failure" bullet — emits its **own** `hidden-failure-schema.json`
   contract, and writes **`reviews/<slug>.hidden-failure.json`**. The existing correctness prompt,
   `finding-schema.json`, and `reviews/<slug>.codex.json` are **byte-for-byte unchanged**.
3. The critic's findings are appended to the story as their **own** `## Hidden-failure review (<date>,
   base <base>, HEAD <sha>)` section, and step 9 presents them as a **separate menu section** beside
   the correctness findings — no consensus vote/merge (obvious cross-section duplicates may be dropped).
4. The critic runs **only within the correctness pass** — after the shape is blessed, on the same
   diff-base / round logic as correctness (first review **and** fix-verify re-reviews). The
   approach→correctness gate and its short-circuit are untouched.
5. **Per-lens "never re-raise":** in a re-review round the hidden-failure critic does not re-raise a
   hidden-failure finding Thomas deferred/rejected earlier; step 9's `## Decisions` block records
   dispositions for **both** critics' findings this round.
6. `tests/reviewer_test.sh` gains drift checks for the new critic's key tokens/phrases (its
   `-o reviews/<slug>.hidden-failure.json`, its `</dev/null`, the concurrent-launch marker, its
   own-section menu language), **within** the file's linter charter — no per-block parsing, no
   git-diff whitelist, no behavioral oracle. The full gate stays green.
7. `BACKLOG.md`'s OPS-12 update is committed on this branch, and OPS-12 carries a one-line pointer to
   `reviews/parallel-critic.md` as its build.
8. **Scope containment:** the diff touches only `.claude/skills/review/SKILL.md`,
   `.claude/skills/review/hidden-failure-schema.json` (new), `tests/reviewer_test.sh`, `BACKLOG.md`,
   and files under `reviews/`.

## Test notes

- **AC1/AC2/AC3/AC4/AC5** — instructions Claude follows, not code (same nature as the existing
  reviewer seam). Verified by: the new drift checks in `reviewer_test.sh` (token/phrase presence), the
  codex correctness pass reading the actual SKILL.md diff, and a human read of the revised steps 8–9.
  No behavioral oracle is invented (the seam is Markdown; per `reviewer_test.sh`'s own charter).
- **AC6** — `bash tests/reviewer_test.sh` passes; inspect that the additions are `has`/`absent`
  drift lines, not new machinery. Full gate: run `testCommand` from `.claude/workflow.json`, green.
- **AC7** — `git log`/`git show` on this branch include the `BACKLOG.md` change; OPS-12 text contains
  the `reviews/parallel-critic.md` pointer.
- **AC8 (scope containment)** — run `git diff --name-only main...HEAD` and verify no files appear
  beyond those AC8 enumerates.

## Open questions — resolved 2026-07-17 (Thomas)

1. **The lens** → **hidden-failure** — the lens most orthogonal to the existing correctness pass;
   contract already in `AGENTS.md`.
2. **Concurrency** → **genuinely concurrent**, per-PID `wait` with explicit exit status (AC1).
3. **Schema** → **dedicated per-critic schema** (`hidden-failure-schema.json`), established as the
   **standing rule** ("every parallel critic creates its own finding json henceforth"). OPS-12 amended
   to match.
4. **Failure posture** → **fail-closed / hard-stop** (AC1) — an added critic that fails stops the
   round rather than letting an incomplete review reach the merge fork.

## Design sketch — HOW

**Step 8 (correctness pass) becomes two concurrent critics with a proven-success join.** After the
approach gate blesses the shape, launch both critics to **fresh temp files**, capture each PID, wait
per-PID for an explicit exit status, validate, then atomically promote — so a failed critic can never
leave a prior round's artifact standing as this round's result:

```bash
tmp_c="$(mktemp)"; tmp_h="$(mktemp)"   # fresh per run — never the stable path

# existing correctness critic — prompt & finding-schema.json UNCHANGED; only -o now a temp
codex exec -s read-only \
  --output-schema "$HOME/.claude/skills/review/finding-schema.json" \
  -o "$tmp_c" ${codexModel:+-m "$codexModel"} \
  "<existing correctness prompt, verbatim>" </dev/null & pid_c=$!

# NEW hidden-failure critic — focused prompt, its OWN schema, its own temp -o
codex exec -s read-only \
  --output-schema "$HOME/.claude/skills/review/hidden-failure-schema.json" \
  -o "$tmp_h" ${codexModel:+-m "$codexModel"} \
  "You are the independent reviewer per AGENTS.md doing a CORRECTNESS review SCOPED TO ONE LENS:
   hidden failure / weak error handling (AGENTS.md's 'Hidden failure' bullet) ONLY. The parallel
   correctness critic covers everything else — do NOT duplicate it. Run \`git diff <base>...HEAD\`
   and read reviews/<slug>.md for the spec. Report ONLY findings where the diff swallows, absorbs,
   or silently degrades on error: bare/blind except|catch, catch-log-continue where propagating is
   correct, silent fallbacks, deleted assertions/safety checks — anything that lets code continue in
   a degraded state nothing surfaces. Ground every finding in the diff; empty findings array if none.
   Return strictly per the provided JSON schema." </dev/null & pid_h=$!

wait "$pid_c"; rc_c=$?
wait "$pid_h"; rc_h=$?
# Promote each ONLY on {clean exit AND parseable JSON}; any failure is fail-closed (AC1).
promote() { # <rc> <tmp> <dest> <label>
  { [ "$1" -eq 0 ] && jq -e . "$2" >/dev/null 2>&1; } \
    && mv "$2" "$3" \
    || { echo "FAIL: $4 critic (rc=$1) — round stopped; rerun /review" >&2; return 1; }
}
promote "$rc_c" "$tmp_c" reviews/<slug>.codex.json          correctness    || exit 1
promote "$rc_h" "$tmp_h" reviews/<slug>.hidden-failure.json hidden-failure || exit 1
```

Both are read-only, both keep their own `</dev/null` (the redirect binds per-command, so backgrounding
is safe). The absolute-`--output-schema` / repo-relative-`-o` split is unchanged (each critic's schema
is absolute; the promoted `-o` targets are repo-relative). On success, append the existing
`## Codex review` section **and** a new `## Hidden-failure review` section; commit both `.json`
artifacts + the story. **Fail-closed:** if either `promote` fails, stop the round here — no menu, no
`/close` (AC1).

**Step 9 (decision menu) grows one section.** Present correctness findings and hidden-failure findings
as **two labelled groups**, each finding still carrying severity + claim, each with a recommended
disposition derived exactly as today (BLOCKER/IMPORTANT→fix, QUESTION→answer, NIT→accept/defer). No
cross-critic vote; drop only an obvious same-`file:line`+claim duplicate. The `## Decisions` block
records dispositions for both groups; re-review rounds honor them per group (AC5).

**Reconciliation = grouping** (divided parallelism): because the second critic asks a *different*
question, its findings rarely overlap the correctness critic's, so no consensus machinery is needed —
this is precisely why "different things" is cheaper than "same thing, N times."

**Failure posture — fail-closed (resolved):** a critic fails if it exits nonzero **or** its temp
artifact is not parseable JSON; either way the `promote` step stops the round with a loud message and
non-zero exit — no menu, no `/close`. The added critic is *required*, so it can never silently become
optional (codex's IMPORTANT finding). One flaky secondary critic blocking a clean round is the
accepted cost; the fix is to rerun, not to proceed on partial output.

**Tests:** add `has` drift lines to `reviewer_test.sh` for the new critic's `hidden-failure-schema.json`
path, its `-o` temp/promote to `reviews/<slug>.hidden-failure.json`, the `</dev/null` on the second
critic, the per-PID join (`wait "$pid_h"`), and the step-9 own-section language — as drift-only checks,
honoring that file's "not a behavioral gate" charter.

**Backlog:** commit the carried `BACKLOG.md`; add to OPS-12 a line: *"Build: `reviews/parallel-critic.md`
(hidden-failure lens, first citizen)."*

## Codex design review (2026-07-17)

**Verdict:** Divided parallelism with one focused hidden-failure critic is a sound, appropriately
minimal first shape, and reusing the existing correctness schema is technically sufficient because
separate artifacts already identify the lens. Not ready to build as sketched: the orchestration can
accept stale output after a failed critic, the fail-open policy lets an incomplete review reach the
merge workflow, and the schema decision contradicts the recorded OPS-12 decision.

### BLOCKER
- **Bare `wait` + persistent output paths cannot prove both critics succeeded** — *one-way ·
  kludgy* · locus: Step-8 bash block + failure posture. A bare `wait` doesn't preserve/check each
  child's exit status, and both critics write directly to stable paths that may already hold an
  earlier round's artifact. If a background `codex exec` fails before replacing its file, the
  post-`wait` missing/JSON check can accept a **stale-but-valid** artifact and record it against the
  current base/HEAD — the exact silent degradation this lens hunts, and a pattern future critics copy.
  **Alternative:** isolate prior outputs, capture each PID, `wait` per-PID for explicit status, write
  each run to a fresh temp file, validate, then atomically promote to the stable path; treat exit
  failure and invalid artifact as the same explicit failure. **Win:** kills the stale-review path,
  makes both outcomes observable, sets one reliable concurrency invariant for every future lens.

### IMPORTANT
- **Fail-open lets a review complete without the required critic** — *one-way · nonstandard* ·
  locus: failure posture. Recording the failure is loud, but proceeding through the menu and `/close`
  still lets the branch reach the merge fork without the hidden-failure review AC1–AC5 require — the
  critic becomes optional exactly when it fails, and that becomes the precedent for future lenses.
  **Alternative:** hard-stop the round when either required critic fails (record which + how to
  rerun); if advisory critics are wanted, make that status explicit in the ACs so `/close` can't
  mistake a partial result for a complete review. **Win:** removes the incomplete-review→merge path;
  a recorded round always holds valid output from every required lens.

### QUESTION
- **Schema choice conflicts with the recorded OPS-12 decision** — *one-way · standard* · locus:
  OQ3 / AC2 / Non-goals vs BACKLOG.md OPS-12. The story recommends reusing unchanged
  `finding-schema.json`; OPS-12's "minimal build" bullet says the critic has its **own** schema plus a
  `lens`/`source` field. Two sources of truth. **Alternative (codex's lean):** reuse
  `finding-schema.json`, treat artifact-path + labelled section as lens identity, and **amend OPS-12**
  to record that; only add a dedicated tagged schema if lens identity must travel with findings
  outside the artifacts. **Win:** one authoritative contract, no needless schema fork, no ambiguous
  provenance for future critics.

## Design decisions (2026-07-17)

Scope **approved** by Thomas ("confirmed — do it"); the shape below is binding on implementation.

- **BLOCKER — stale-output orchestration → FIX (ratified).** Adopt per-PID `wait` with explicit exit
  status + fresh-temp-file → validate → atomic-promote; exit failure and invalid artifact are one
  failure. This is the one-way cross-cutting concurrency template every future critic copies. Folded
  into AC1 and the sketch.
- **IMPORTANT — fail-open → FIX, resolved to fail-closed.** Thomas chose **hard-stop**: either
  required critic failing stops the round (no menu, no `/close`). The added critic is required, never
  silently optional. Folded into AC1 and the failure-posture note.
- **QUESTION — schema vs OPS-12 → resolved to dedicated per-critic schema.** Thomas: "every parallel
  critic creates its own finding json henceforth." So this critic gets its own `hidden-failure-schema.json`
  (no shared `finding-schema.json`, no `lens`/`source` field — separation is structural), and **OPS-12
  is amended** to record this standing rule (removing its "own schema *plus a lens/source field*"
  wording). AC2, In-scope, and AC8 updated to add the new schema file.
