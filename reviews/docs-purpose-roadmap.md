Date: 2026-07-27 · Branch: claude/docs-purpose-roadmap · Status: approved

# docs-purpose-roadmap — accurate purpose, all committed features, an explicit roadmap

## User story (OPS-14 frame)

> **As** the owner (and any future reader, human or AI reviewer) of this repo, **I want** the docs to
> state plainly what this repo *is* (a meta-repo whose skills are authored here and deploy to run on my
> *other* codebases), document **every shipped feature**, and show a **clear roadmap**, **so that**
> nobody has to infer the purpose or discover features by reading code — the exact gap that just
> produced a confident-but-wrong architecture review (the reviewer took "the product is Markdown" at
> face value because the docs never said the skills run on external code).

## Problem

The canonical docs under-declare what this repo is and omit shipped work — concretely:

1. **Purpose is implicit.** README/ARCHITECTURE frame the repo as "a lightweight development loop,"
   never plainly stating it is a **meta-repo**: the skills + guard hook are *authored here* and
   *deployed* (`install.sh` → `~/.claude`) to operate **across all the user's other projects**. The
   loop skills (`/frame` `/review` `/close`) act on whatever repo you're in; the recon tools
   (`/dev-audit` `/deep-audit`) inspect a *target* repo. This repo is the atypical **self-hosting**
   case (its own product is prompt-instructions). That ambiguity directly caused the F2 review error.
2. **A shipped feature is undocumented.** `deep-audit` shipped on `main` (`merge: deep-audit-plan`,
   PR #35) but appears **zero times** in README, ARCHITECTURE, or `workflow-protocol.md`. The docs
   still say "three loop skills plus `/dev-audit`."
3. **No explicit roadmap.** What's shipped / in-progress / parked / planned lives scattered across
   `BACKLOG.md`'s `OPS-`/`BUG-` items and per-branch story files; there is no at-a-glance status.

## In scope

- **Purpose statement (README + ARCHITECTURE), single-sourced.** State plainly: authored-here /
  deployed-everywhere meta-repo; loop-skills-act-on-current-repo vs recon-tools-inspect-a-target; the
  self-hosting caveat; **dual audience** — honest that it is the owner's personal estate tool, written
  so a stranger *could* adopt it. Stated authoritatively in **one** place, referenced from the other
  (no two drifting copies).
- **Document all committed features.** README's feature map and ARCHITECTURE §§2–3 cover **all five
  shipped skills** — `/frame` `/review` `/close` `/dev-audit` **`/deep-audit`** — accurately. Correct
  the stale "three loop skills + dev-audit" framing to "the loop (frame/review/close) + recon tools
  (dev-audit, deep-audit)."
- **`deep-audit` documented as shipped + roadmap status.** Its shipped **plan stage** is described
  as a committed feature; its **execution engine** is explicitly marked *roadmap — direction under
  evaluation (core / plugin / park)*, so the map is accurate to `main` and honest about the unsettled
  future.
- **`ROADMAP.md` (new) — a strategic view (DR-1).** Grouped by theme (the loop · recon ·
  deployment/tooling), it states **intended direction** and the **open decisions** (notably deep-audit
  core/plugin/park) — the strategic narrative nothing else owns — and **references** `BACKLOG.md`
  (operational state) + git/README (shipped capability) for status. It does **not** re-assert per-item
  lifecycle labels (git owns "shipped"; BACKLOG owns operational state — no second writer).
- **Docs-consistency linter (DR-2 form).** `tests/docs_test.sh` enforces **one** drift-proof
  invariant: every deployed skill in `install.sh`'s `ARTIFACTS` set is documented in README **and**
  ARCHITECTURE. No purpose-phrase pins (purpose/roadmap *semantics* stay for review). Wired into the
  gate — the next shipped-but-undocumented skill fails it.

## Non-goals

- **No product / skill-behavior changes.** Docs only. No skill logic, schema, or hook edits.
- **Not deciding** the deep-audit core/plugin/park question — it is *documented* as under-evaluation,
  not resolved here.
- **Not restructuring `BACKLOG.md`** — it stays the loop's staging area; `ROADMAP.md` references it.
- **Not rewriting** the historical `ai-dev-workflow-architecture.md` (a deliberate historical
  reference) or `workflow-protocol.md`'s normative rules (light touch only if a purpose pointer helps).
- **Not documenting** `deep-audit-lib` / `deep-audit-run` as shipped — they are in-progress/parked
  (they appear in the roadmap under in-progress/parked, not the feature map).

## Acceptance criteria

1. **Purpose is explicit and single-sourced.** README's opening states the meta-repo purpose:
   authored-here + deployed via `install.sh` to run across the user's other projects; loop-skills act
   on the current repo while recon tools inspect a target; the self-hosting caveat; the dual
   (personal-now / shareable-ready) framing. ARCHITECTURE §1 carries the same purpose by
   **reference/alignment**, not a divergent restatement.
2. **All five shipped skills are documented** in both README (feature map) and ARCHITECTURE, each
   with an accurate one-line role; the stale "three loop skills" framing is gone.
3. **`deep-audit` is in the map** as a shipped plan-stage tool **with** its execution engine marked
   *roadmap — under evaluation*; no claim implies the engine ships today.
4. **`ROADMAP.md` is a strategic view (DR-1), not a status dashboard.** It states, by theme, the
   **intended directions** and **open decisions** (notably deep-audit core/plugin/park), and
   **references** `BACKLOG.md` (operational state) + git/README (shipped capability) for status. It
   does **not** re-assert per-item lifecycle labels — no second writer of state that git/BACKLOG own.
5. **Accuracy / no stale claims.** No doc describes an unshipped feature as shipped or omits a shipped
   one; `deep-audit`'s parked engine and the in-progress lib are represented honestly (as directions/
   open work in the roadmap, not in the shipped feature map).
6. **Docs-consistency linter (DR-2 form).** `tests/docs_test.sh` derives the deployed skill names from
   `install.sh`'s `ARTIFACTS` entries and asserts **each appears in README *and* ARCHITECTURE**; it
   pins **no** purpose/roadmap prose. Wired into `workflow.json` `testCommand` + the `ci.yml` gate;
   `shellcheck` + `shfmt -i 2 -ci` clean. A deployed-but-undocumented skill fails the gate.
7. **Scope containment.** `git diff --name-only main...HEAD` shows no file beyond the enumerated set
   **and files under `reviews/`**: `README.md`; `ARCHITECTURE.md`; `ROADMAP.md` (new);
   `tests/docs_test.sh` (new); `.claude/workflow.json` + `.github/workflows/ci.yml` (gate wiring).

## Test notes

- **AC1, AC3, AC5** — inspection: grep for the purpose claims (meta-repo, deploy-everywhere,
  target-vs-current, self-hosting, dual framing) and `deep-audit`'s "under evaluation" roadmap marker;
  confirm the stale "three loop skills" phrasing is gone. (Purpose/roadmap *semantics* are
  review-judged, not phrase-pinned — DR-2.)
- **AC2** — **gate-enforced by the AC6 linter** (every `ARTIFACTS` skill appears in README +
  ARCHITECTURE), plus inspection that each role line reads accurately.
- **AC4** — `ROADMAP.md` exists, is theme-organized, carries directions + the open decisions, and
  **references** `BACKLOG.md` (`OPS-` ids/links) + git for status rather than re-asserting per-item
  lifecycle labels (inspection).
- **AC6** — run `tests/docs_test.sh`; add a throwaway skill name to a copy of the `ARTIFACTS` set with
  no doc mention → it must **fail**; the real tree → **pass**. `shellcheck` + `shfmt -d -i 2 -ci`
  clean.
- **AC7** — `git diff --name-only main...HEAD` shows only the enumerated files plus `reviews/`.

## Open questions (for the consult)

1. **Add a docs-consistency linter?** *(Recommended.)* A `tests/docs_test.sh` (kin to the existing
   `dev_audit_test.sh` doc-presence checks) that pins the invariants — **every skill in
   `.claude/skills/` appears in README + ARCHITECTURE**, the purpose claims are present, `ROADMAP.md`
   exists and references `BACKLOG.md` — wired into the gate. **Win:** prevents recurrence — the next
   shipped-but-undocumented skill *fails the gate* (this whole story exists because `deep-audit`
   slipped through undocumented). **Cost:** one more linter to maintain, and it makes "the docs" a
   gated artifact. If you'd rather keep this docs-only, the ACs fall back to inspection (Test notes).
2. **Purpose statement's authoritative home** — README opening (lean) vs a short `PURPOSE`/§1 block in
   ARCHITECTURE that README quotes. Either way it lives in one place; confirm which is canonical.
3. **Does `workflow-protocol.md` need a purpose pointer?** Lean **no** — it is normative loop rules,
   not a product overview; a one-line "what this is / see README" pointer at most.

## Design sketch — HOW

- **Single-source the purpose.** Write the authoritative purpose paragraph **once** (README opening),
  and have ARCHITECTURE §1.2 (“The goal”) align to it / point at it — avoiding the two-drifting-copies
  failure mode this repo keeps fighting (OPS-17). The paragraph names: *meta-repo · authored here ·
  `install.sh` deploys to `~/.claude` → every project · loop skills act on the current repo, recon
  tools inspect a target · self-hosting caveat · personal-now / shareable-ready.*
- **Feature map = derived from reality.** README's command table and ARCHITECTURE §§2.2/3.1 list the
  **five** skills present in `.claude/skills/`. `deep-audit` joins `dev-audit` under recon; its row
  says "plan stage shipped; execution engine on the roadmap (under evaluation)."
- **`ROADMAP.md` = strategic view (DR-1), not a status dashboard.** Grouped by the three themes (the
  loop · recon · deployment/tooling), each theme states its **intended direction** and any **open
  decision** (the standout: deep-audit core/plugin/park) — the strategic layer nothing else owns. For
  *status* it **points**: shipped capability → git/README, operational items → `BACKLOG.md` `OPS-`
  ids, in-flight/parked detail → the story files. No per-item lifecycle label is hand-asserted, so it
  cannot disagree with git or BACKLOG. It names the reality it should reference: the shipped loop +
  recon skills; the in-flight `deep-audit-lib`; the parked `deep-audit-engine` prose; the
  evaluate-and-decide `OPS-` items; and the live core/plugin/park question.
- **`tests/docs_test.sh` (DR-2 form).** Parse the **deployed** skill names out of `install.sh`'s
  `ARTIFACTS` entries (`.claude/skills/<name>::…`) — the deployment source of truth — and assert each
  `<name>` appears in README **and** ARCHITECTURE. **No** purpose/roadmap phrase pins. Wired into
  `workflow.json` `testCommand` + `ci.yml`; same drift-linter idiom as the repo's others.
- **Leans on / reuses:** the existing doc structure (README sections, ARCHITECTURE §§1–3), the
  `dev_audit_test.sh` doc-presence-check pattern, `BACKLOG.md` as the item store. **New:** `ROADMAP.md`
  and (optionally) `tests/docs_test.sh`.

## Codex design review (2026-07-29)

Artifact: `reviews/docs-purpose-roadmap.design.json`.

**Verdict:** *"A dedicated ROADMAP.md and README-canonical purpose statement are modern, appropriate
choices, but I would not build the roadmap and optional linter exactly as sketched. ARCHITECTURE
should point explicitly to README's purpose and state only architecture-specific consequences;
workflow-protocol.md needs no additional copy."*

Purpose single-sourcing **confirmed** (README canonical, ARCHITECTURE points-and-adds-consequences,
protocol needs nothing). Two IMPORTANT findings — both the *same* duplication/drift disease this
estate fights, aimed at my sketch:

- **DR-1 — ROADMAP would hand-copy lifecycle state** — *one-way · kludgy.* The four hand-maintained
  buckets (shipped/in-progress/parked) **duplicate status already owned by `BACKLOG.md` and — for
  shipped — by git** (the declared-vs-observed doctrine: shipped is the merge commit, read back, never
  hand-written). Links avoid copying item *bodies*, but the **labels still copy the mutable fact**, and
  partially-delivered work (OPS-12, OPS-13) makes that shadow-status drift-prone. **Alternative:** keep
  `ROADMAP.md` a **strategic** view — themes, intended directions, **unresolved decisions** — and
  **link** to `BACKLOG.md` for operational state + README/git for shipped capability; if exact bucket
  status is ever mandatory, **generate** it, don't hand-maintain. **Win:** no second writer of
  lifecycle state; ROADMAP can't disagree with BACKLOG or the merge history.
- **DR-2 — the linter pins prose shadows, not authoritative invariants** — *two-way · kludgy.*
  Iterating `.claude/skills/*` treats source dirs as the shipped inventory, but **`install.sh`'s
  `ARTIFACTS` set is the deployment source of truth**; and pinning purpose *phrases* / "ROADMAP
  mentions BACKLOG" are wording-coupled assertions (the OPS-17 drift source) — they pass while prose
  is wrong and fail on an accurate rephrase. **Alternative:** if adopted, keep it drift-only and
  enforce **one** real invariant — derive deployed skill names from **`ARTIFACTS`** and assert each
  appears in README + ARCHITECTURE (optionally cross-check `ARTIFACTS` vs skill dirs); leave purpose/
  roadmap *semantics* to review. **Win:** still stops the next deployed-but-undocumented skill (the
  exact trigger for this story), without brittle phrase pins or false confidence.

## Codex approach review (2026-07-29, base main, HEAD 6a14c5f)

Artifact: `reviews/docs-purpose-roadmap.approach.json`.

**Verdict:** *"The purpose shape is sound: README is canonical and ARCHITECTURE points to it while
recording architectural consequences. However, I would not ship the roadmap or linter in their
current shapes: ROADMAP recreates shadow lifecycle state, and the linter can pass on incidental name
occurrences."*

Purpose single-sourcing **confirmed**. Two findings:

### BLOCKER

- **AP-1 — ROADMAP is still a hand-maintained status dashboard** — *one-way · kludgy.*
  (`ROADMAP.md`.) Despite the "strategic view" reframe, it **re-asserts mutable lifecycle facts** —
  "shipped," "parked," "stable," "in-flight," "being rebuilt," + a curated open-work list — which
  DR-1 assigned to git/BACKLOG/story files. Links don't remove the duplication when the surrounding
  prose copies status; this is the **second-writer model the story exists to prevent**, recreated in
  the roadmap itself. (Self-check confirms: shipped×5, parked×3, stable×2, in-flight, staged.)
  **Alternative:** keep **only durable strategic direction + unresolved choices** (lightweight-loop
  direction, reviewer diversification, deep-audit core/plugin/park); **remove lifecycle labels,
  delivery narratives, and the curated OPS inventory**; link once to README/git + BACKLOG + stories
  for state. **Win:** removes ~15–20 lines of shadow status and the obligation to update ROADMAP on
  every merge/OPS/story change.

### IMPORTANT

- **AP-2 — the linter checks incidental substrings, not documented commands** — *two-way · kludgy.*
  (`tests/docs_test.sh`.) Extraction greps the **whole** install script (a skill name in a
  comment/example outside `ARTIFACTS` would count), and coverage matches the **bare** skill name
  anywhere — so a skill named `audit` "passes" via "audit trail" prose, with no real feature entry.
  The gate doesn't reliably enforce its sole invariant. **Alternative:** extract only from **inside
  the `ARTIFACTS` array**, and require the **structural command token** (`/name`, with delimiters) in
  both docs — pinning command identity, not prose wording. **Win:** kills both false-green paths while
  staying minimal + phrase-independent.

## Decisions (2026-07-29, approach round 1)

Thomas: **"Fix both."** Both reshape a deliverable (approach short-circuit — correctness did not run;
redesign goes through `/close`, then re-reviews). Exact scope:

- **AP-1 → FIX.** Strip `ROADMAP.md` to only the **durable** layer: per-theme **direction** (keep the
  loop lightweight; the reviewer layer diversifies; deep-audit is the big bet) and the **open
  decisions** (deep-audit core/plugin/park; the `OPS-` prefix taxonomy), plus the one "where current
  status lives" pointer (git/README + BACKLOG + `reviews/`). **Remove** all lifecycle labels
  (shipped/parked/stable/in-flight/staged/being-rebuilt), delivery narratives, and the curated `OPS-`
  inventory — those are git/BACKLOG's to own.
- **AP-2 → FIX.** `tests/docs_test.sh`: extract skill names **only from inside the `ARTIFACTS=( … )`
  block** (not the whole file), and require the **structural command token `/<name>`** (with a
  delimiter) in README **and** ARCHITECTURE — pinning command identity, not incidental prose.

## Codex approach review (2026-07-29, base main, HEAD a45dd77 — re-review round 2)

Artifact: `reviews/docs-purpose-roadmap.approach.json`. Re-review after the AP-1/AP-2 redesign.

**Verdict (empty findings — CLEAN):** *"The reshaped approach is sound. ROADMAP.md now contains
durable strategic direction, authority pointers, and open decisions without recreating per-item
lifecycle status. The docs linter derives deployed skills solely from install.sh's ARTIFACTS block
and checks delimited /command tokens without coupling to prose wording. AP-1 and AP-2 are verified as
fixed and remain settled; no genuinely new high-leverage shape concerns were found."*

Shape **blessed** — correctness runs in the same round.

## Codex review (2026-07-29, base main, HEAD 8a3b116)

Artifact: `reviews/docs-purpose-roadmap.codex.json`. First correctness pass (round 1 short-circuited
at approach). All four verified against the sources.

**Summary:** *"The deep-audit plan/execution boundary and roadmap status are honest, but the story
does not meet its accuracy and linter ACs. Canonical docs retain stale inventories, and the linter
has reproducible false-green paths despite passing shellcheck and shfmt."*

### BLOCKER

- **CR-1 — stale four-skill inventories remain** (`ARCHITECTURE.md:216`, `§3.5–3.6`; `README.md`
  stand-down). AC2 required removing the "three loop skills plus `/dev-audit`" framing, but
  `ARCHITECTURE.md:216` still has it, and the **stand-down lists** omit `/deep-audit` while the new
  recon sections correctly say both recon skills stand down — internally inconsistent, and omits a
  shipped skill in multiple inventories. *Fix:* update the README + ARCHITECTURE stand-down/inventory
  spots to "three loop skills + two recon skills" incl. `/deep-audit`.

### IMPORTANT

- **CR-2 — the linter fails OPEN** (`tests/docs_test.sh`, the `<<<` here-string). If the here-string's
  temp file can't be created (unwritable/exhausted `/tmp` — Codex reproduced it), the per-skill loop
  is **skipped**, and the script prints `passed=2 failed=0` and exits **0** — enforcing none of its
  core invariant. *Fix:* feed the loop without a here-string (process substitution) **and** fail
  closed if enumeration didn't run (assert every parsed skill was checked).
- **CR-3 — the command regex accepts file paths** (`tests/docs_test.sh`). The trailing boundary
  excludes only alnum + hyphen, so `/frame/SKILL.md` and `/deep-audit.md` match — a skill mentioned
  only as a **path/filename** satisfies the "documented as a `/command`" claim (contra AP-2).
  *(Confirmed: `/deep-audit.md` matches.)* *Fix:* require the docs' actual command form (backtick-
  wrapped `` `/name` ``) and exclude path separators + extensions from the boundary.
- **CR-4 — CI suite count is stale** (`README.md:114`, `ARCHITECTURE.md:190`). Both say the gate runs
  "the three test suites," but this branch wired a **fifth** (`docs_test.sh`). *Fix:* replace the
  brittle number with an accurate, count-free description ("the configured workflow test suites").

## Decisions (2026-07-29, correctness round 2)

Approach pass was clean (no approach decisions). Correctness — Thomas: **"Fix all 4."** Line-level
fixes (not redesigns); `/close` reaches the re-review-or-merge fork. Exact scope:

- **CR-1 → FIX.** `ARCHITECTURE.md:216`: reword "the three loop skills plus `/dev-audit`" → the loop's
  three skills **+ two recon skills** (incl. `/deep-audit`). Add `/deep-audit` to the stand-down lists
  (README stand-down section + `ARCHITECTURE.md §3.5`) so both recon tools are listed consistently.
- **CR-2 → FIX.** `tests/docs_test.sh`: feed the skill loop via **process substitution** (not a
  here-string) and add a **fail-closed count guard** — assert every parsed skill was actually checked;
  `bad` (exit 1) if enumeration didn't run.
- **CR-3 → FIX.** `doc_has_cmd`: require the **backtick command form** (leading `` ` `` before
  `/name`) and a trailing boundary that **excludes path separators + extensions** (`/`, `.`), so a
  filename/path can't satisfy the command check.
- **CR-4 → FIX.** `README.md:114` + `ARCHITECTURE.md:190`: replace "the three test suites" with a
  **count-free** description ("the configured workflow test suites").

## Fixes (2026-07-29, approach round 1)

Applied both approved fixes; gate green.

- **AP-1.** `ROADMAP.md` stripped to the **durable** layer: a "where status lives" pointer, a
  **Direction** section (per-theme trajectory, no status), and **Open decisions** (deep-audit
  core/plugin/park; the `OPS-` prefix taxonomy). Removed all lifecycle labels (shipped/parked/
  stable/in-flight/staged), the delivery narratives, and the curated `OPS-` inventory — those are
  git/BACKLOG's to own. (The two remaining "parked" tokens are the routing-category label and the
  *name* of the core/plugin/**park** decision, not per-item status.)
- **AP-2.** `tests/docs_test.sh` now extracts skill names **only from inside the `ARTIFACTS=( … )`
  block** (quoted skill-dir records), and requires the structural **`/command` token** (delimited)
  in both docs via `doc_has_cmd`. Verified behaviorally: incidental prose ("close") is rejected, the
  real `/close` matches, and `/dev` is not matched inside `/dev-audit`.

## Build note (2026-07-29)

AC → file map:

- **AC1** (purpose explicit + single-sourced) → `README.md` ("## What this repo is"); `ARCHITECTURE.md`
  §1.2 (pointer + arch-specific consequences, not a restatement).
- **AC2** (all five deployed skills documented) → `README.md` (loop table + recon section);
  `ARCHITECTURE.md` (§2.2 loop, §2.2a recon).
- **AC3** (`deep-audit` shipped + roadmap status) → `README.md` recon; `ARCHITECTURE.md` §2.2a;
  `ROADMAP.md`.
- **AC4** (roadmap = strategic view, DR-1) → `ROADMAP.md`.
- **AC5** (accuracy / no stale claims) → `README.md`, `ARCHITECTURE.md`.
- **AC6** (docs linter, DR-2 form) → `tests/docs_test.sh`; `.claude/workflow.json`;
  `.github/workflows/ci.yml`.
- **AC7** (scope containment) → the enumerated set above.

## Design decisions (2026-07-29)

Thomas's frame-consult decisions — **binding on implementation**:

- **Scope — approved** (accurate purpose + all committed features + explicit roadmap), audience
  **"both — personal now, shareable-ready"**, and `deep-audit` **documented as shipped + roadmap
  status** (engine marked under-evaluation).
- **DR-1 — roadmap = strategic view (one-way, ratified, FIX).** `ROADMAP.md` carries themes,
  directions, and the open decisions (core/plugin/park) and **references** BACKLOG/git for status; it
  does **not** hand-maintain per-item lifecycle labels (no second writer of state git/BACKLOG own).
- **DR-2 — docs linter adopted in minimal form (FIX).** `tests/docs_test.sh` enforces one authoritative
  invariant — every `install.sh` `ARTIFACTS` skill is documented in README + ARCHITECTURE — with **no**
  purpose/roadmap phrase pins. (Resolves Open question 1: linter adopted.)
- **Smaller opens (leans, no objection):** purpose home = **README** canonical, ARCHITECTURE points +
  adds only arch-specific consequences (Open question 2); `workflow-protocol.md` gets **no** purpose
  copy (Open question 3).
