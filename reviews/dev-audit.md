# dev-audit

Date: 2026-06-28 · Branch: claude/dev-audit · Status: approved

## Problem
The light workflow has a *change* loop (`/frame → /review → /close`) but no *intake/recon*
step. When pointed at an unfamiliar repo, the assistant has no codified way to inspect what the
repo actually is — its languages, framework files, dependency manifests, test setup, CI config,
secret-handling patterns, and domain — and then choose analysis tools that fit *that* repo
instead of running a generic checklist. The result is either guesswork or a one-size-fits-all
pass that misses the repo's real gaps.

We want a new skill, `/dev-audit`, that detects repo type + maturity, selects the right mix of
analysis tools **and explains why**, runs a zero-dependency core (plus any heavier tools that
happen to be installed), and returns a brief report: findings, risk level, best-practice gaps,
and prioritized next steps — flagging missing safeguards (CI, tests, pinned deps, secret
handling) and recommending practical moves toward mature, secure delivery.

It is a **pre-loop recon** skill, standalone from `frame/review/close`, that can hand
prioritized findings into `BACKLOG.md` (report-first, human-gated) so they flow into the loop.

## In scope
- A new skill `.claude/skills/dev-audit/SKILL.md` — a procedure Claude follows (same kind of
  artifact as `frame/review/close`: Markdown instructions, `name` + `description` frontmatter only,
  per OPS-9 status quo). Invoked `/dev-audit [path]`; default target is the current repo root.
- **Step-0 stand-down** (AC7): resolve the target repo root; if `docs/ai-protocol.md` is present,
  STOP before any write and defer to that repo's native workflow.
- **Detection** (AC1): languages, framework files, dependency manifests, test setup, CI config,
  secret patterns, domain signal → a repo *type* and a *maturity tier* from a **declarative rubric
  table** (safeguard signals → tier).
- **Tool selection with rationale** (AC2): a single declarative mapping (ecosystem → linters,
  dep scan, secret scan, security check, test runner, architecture-review lens). The report must
  state *why* each chosen tool fits the detected profile.
- **Hybrid execution** (AC3): always run a zero-dependency **core** (manifest/dep-pinning read,
  CI presence, test presence, grep-based secret patterns, git hygiene); for heavier tools run
  **only if already present** (`command -v`), otherwise mark *recommended (not installed)*. Never
  installs tools.
- **Report** (AC4): fixed-section brief — detected profile, tools chosen + why, findings, risk
  level, best-practice gaps, prioritized next steps. Printed to chat and written to
  `reviews/audit-<YYYY-MM-DD>.md` in the target repo.
- **Safeguard flags** (AC5): explicitly call out missing CI, missing/weak tests, unpinned
  dependencies, and weak secret handling.
- **Backlog hand-off, report-first + human-gated** (AC6): always report first; only on an
  explicit human go-ahead append selected findings to `BACKLOG.md` under a new `AUDIT-` id prefix
  (documented in `BACKLOG.md`'s taxonomy); never automatic; never create `BACKLOG.md` unprompted.
- **Non-destructive** (AC7): read-only against the target repo; the only writes are the audit
  report artifact and, on approval, `BACKLOG.md`.
- **Deploy + gate + discoverability** (AC8): wire the skill into `install.sh` ARTIFACTS; add a
  drift-only linter `tests/dev_audit_test.sh` and include it in the gate (`.claude/workflow.json`
  `testCommand`); mention the skill in `README.md`.

## Non-goals
- Not a CI service, scheduled scanner, or daemon — it runs on demand.
- Does **not install** tools or add runtime dependencies beyond what the repo already assumes
  (`git`, `grep`, `python3`, `jq`).
- Does **not auto-fix** anything, and never modifies target-repo code.
- Does **not** replace or alter `/frame`, `/review`, `/close`; it feeds the backlog, nothing more.
- No numeric maturity *score* / false-precision rubric — maturity is a small set of named tiers
  driven by which safeguards are present (avoids "scoring theater").
- The linter test is **drift-only**, not a behavioral gate (a skill is instructions Claude
  follows — there is no oracle; same stance as `tests/reviewer_test.sh`).

## Acceptance criteria
1. **Detection.** `SKILL.md` directs Claude to inspect languages, framework files, dependency
   manifests, test setup, CI config, secret patterns, and domain signal, and to classify the repo
   into a *type* and a named *maturity tier* (prototype / developing / mature) via a **declarative
   rubric table** mapping explicit present/absent safeguard signals → tier (not prose).
2. **Tool selection + rationale.** A single declarative mapping table drives tool choice per
   detected ecosystem (linter, dep scan, secret scan, security check, test runner,
   architecture-review lens); the report explains *why* each chosen tool fits the profile.
3. **Hybrid execution.** The procedure always runs a zero-dependency core and gates heavier tools
   on `command -v`, running them only if present and otherwise listing them as *recommended (not
   installed)*; it installs nothing.
4. **Report shape.** The skill produces a brief report with fixed sections: detected profile,
   tools chosen + why, findings, **risk level** (derived from the same rubric table as the maturity
   tier), best-practice gaps, and **prioritized next steps**, written to `reviews/audit-<YYYY-MM-DD>.md`.
5. **Safeguard flags.** The report explicitly flags missing CI, missing/weak tests, unpinned
   dependencies, and weak secret handling whenever those gaps are detected.
6. **Backlog hand-off.** The skill reports first and only appends selected findings to
   `BACKLOG.md` on an explicit human instruction — never automatically. Audit-sourced items use a
   new **`AUDIT-`** id prefix; the `AUDIT-` kind is documented in `BACKLOG.md`'s taxonomy. If a
   target repo has no `BACKLOG.md`, the skill reports suggested entries and requires explicit
   instruction before creating it.
7. **Non-destructive + stand-down.** The skill runs read-only against the target repo; its only
   writes are the audit report artifact and, on approval, `BACKLOG.md` — it modifies no target-repo
   code and installs no tools. **Step 0:** resolve the target repo root and, if `docs/ai-protocol.md`
   exists there, STOP before any write and point at that repo's native workflow (the same
   stand-down every global skill + the guard hook honor).
8. **Deploy + gate + docs.** The skill is listed in `install.sh` ARTIFACTS; `tests/dev_audit_test.sh`
   exists as a drift linter and runs as part of the gate; the **system-map docs reflect the new
   skill** — `README.md`, `ARCHITECTURE.md` (recon skill placed in the map; the now-stale artifact-
   trail / stand-down / deploy mentions corrected), and `BACKLOG.md` (opening + lifecycle name the
   two inflows). *(Amended 2026-06-28 — see Scope decision; the original AC8 required only a README
   mention, which left the canonical system map describing three skills.)*

## Test notes
- **AC1–AC3, AC5–AC7** are properties of *instructions* (Markdown a human/Claude follows), with no
  runtime oracle. They are verified by (a) `tests/dev_audit_test.sh` drift checks asserting the
  key phrases / the mapping table / the core-vs-recommend split / the read-only + human-gated
  backlog language are present, and (b) human reading of `SKILL.md`. Per repo doctrine this linter
  is **drift detection, not a behavioral gate** — it is explicitly *not* grown into a pseudo-
  behavioral suite (mirrors the warning atop `tests/reviewer_test.sh`).
- **AC4** verified by the linter asserting the fixed report-section headings appear in `SKILL.md`,
  plus the `reviews/audit-<date>.md` artifact path token.
- **AC8** verified by: `grep` for the `skills/dev-audit` ARTIFACTS entry in `install.sh`;
  `./install.sh --check` reasoning unaffected; `.claude/workflow.json` `testCommand` includes
  `tests/dev_audit_test.sh`; `bash tests/dev_audit_test.sh` exits 0; `/dev-audit` named in README.
- **Scope containment:** run `git diff --name-only main...HEAD` and verify no files appear beyond
  those these ACs enumerate (`.claude/skills/dev-audit/SKILL.md`, `tests/dev_audit_test.sh`,
  `install.sh`, `.claude/workflow.json`, `README.md`, `BACKLOG.md`, `ARCHITECTURE.md` — the
  system-map docs reflecting the new skill (AC8, amended) — and this story file).
- Full gate: `bash tests/guard_test.sh && bash tests/reviewer_test.sh && bash tests/dev_audit_test.sh`.

## Open questions
_All three resolved at the frame consult (2026-06-28) — see **Design decisions** below._
1. **Report artifact location for a third-party repo** → write to the target repo's
   `reviews/audit-<date>.md`, creating `reviews/` if absent; **but** gated by the step-0
   `docs/ai-protocol.md` stand-down (AC7) so an opted-out repo is never written to.
2. **Backlog item prefix** → **`AUDIT-`** (ratified), documented in `BACKLOG.md`'s taxonomy.
3. **Architecture-review lens** → reuse the existing design-review lens (`AGENTS.md` /
   `design-review-schema.json`); do not invent a parallel prompt set.

## Design sketch — HOW
- **Artifact:** one new `.claude/skills/dev-audit/SKILL.md`, structured like the existing skills —
  numbered steps, `name` + `description` frontmatter only (OPS-9 status quo), tool-neutral prose.
- **Step 0 — stand-down (ratified fix):** resolve the target repo root; if `docs/ai-protocol.md`
  exists there, STOP before any write and defer to the native workflow — the same opt-out the hook
  and the other global skills honor.
- **Detection step:** read well-known manifests/config by filename rather than guessing —
  `package.json`, `pyproject.toml`/`requirements.txt`, `go.mod`, `Cargo.toml`, `Gemfile`,
  `pom.xml`/`build.gradle`, `composer.json`, etc.; CI under `.github/workflows`, `.gitlab-ci.yml`,
  `.circleci/`; test presence by conventional dirs/patterns; secret patterns by grep (common key
  shapes, tracked `.env`, secrets in history). Output: repo *type* + a named *maturity tier* from
  a present/absent signal set (no numeric score). **Maturity tier + risk level come from a second
  declarative rubric table** (safeguard signals: CI, tests, pinned deps, secret handling, git
  hygiene → `prototype`/`developing`/`mature` + risk + required safeguard flags) — the ratified
  fix for finding 2, so the same profile classifies identically across runs.
- **Central data shape — one declarative mapping table** (ecosystem → {linter, dep-scan,
  secret-scan, security-check, test-runner, arch-review-lens}). Tool choice is a table lookup, not
  per-language branching prose — keeps the "why" auditable and the skill small. This is the key
  modern-shape decision; future ecosystems are new rows, not new code paths.
- **Execution model — hybrid:** the **core** uses only already-assumed tools (`git`, `grep`,
  manifest reads, `python3`/`jq`) so it always runs. Heavier tools (semgrep, gitleaks, `npm audit`,
  `pip-audit`, ruff, etc.) are gated on `command -v` — run if present, else surfaced as
  *recommended (not installed)* with the rationale. Nothing is installed; nothing is auto-fixed.
- **Report:** fixed sections — *Detected profile* · *Tools chosen + why* · *Findings* · *Risk
  level* · *Best-practice gaps* · *Prioritized next steps* — written to
  `reviews/audit-<YYYY-MM-DD>.md` (date stamped by Claude at run time) and summarized in chat.
- **Backlog hand-off:** report-first; on explicit human go-ahead, append selected findings to
  `BACKLOG.md` under the new `AUDIT-` prefix (a one-line taxonomy entry is added to `BACKLOG.md` so
  the convention is real). Never automatic; never create `BACKLOG.md` in a target repo unprompted.
- **Architecture review:** reuse the existing design-review lens (`AGENTS.md` /
  `design-review-schema.json`) rather than a parallel prompt set (Open Question 3).
- **Test:** `tests/dev_audit_test.sh` — a drift-only `grep`-based linter with the same explicit
  "this is a linter, not a behavioral gate; do not grow it into theater" preamble as
  `reviewer_test.sh`. It anchors on the stable phrases: the step-0 `docs/ai-protocol.md` stand-down,
  the two table headers (ecosystem→tool, safeguard→tier), the core-vs-`command -v` split, the
  report-section headings, the `AUDIT-`/human-gated backlog language, and the artifact path token.
  Added to the gate via `.claude/workflow.json` `testCommand`.
- **Deploy:** add `".claude/skills/dev-audit::skills/dev-audit"` to `install.sh` ARTIFACTS so it
  ships to `~/.claude`; add a one-line `/dev-audit` mention to `README.md`.

## Scope decision (2026-06-28)
Thomas: **"Approve as written"** — the 8 ACs and non-goals are the binding boundary. Frame consult
answered in one pass: scope approved as written; **fix both** one-way design findings; backlog
namespace = **new `AUDIT-` prefix**.

**Amendment (2026-06-28, post-implementation):** Thomas — *"The scope is too small if we're going
to add a skill to the repo but the docs in the repo don't reflect it."* AC8 widened from "README
mention" to **system-map coherence**: `ARCHITECTURE.md` (the canonical fit doc) and `BACKLOG.md`
(opening + lifecycle inflows) join scope. Deliberately excluded, with reasons:
`ai-dev-workflow-architecture.md` (frozen historical parent doc), `CHANGELOG.md` (owned by `/close`
at merge), `.claude/workflow-protocol.md` (normative *loop* rules — dev-audit is a standalone
non-loop skill).

## Design decisions (2026-06-28)
Disposition per Codex design finding (the approved shape, now binding on implementation):
- **BLOCKER — native-workflow stand-down → FIX.** Add a step-0 `docs/ai-protocol.md` stand-down
  before any write (AC7); the drift linter asserts the phrase.
- **IMPORTANT — maturity/risk rubric → FIX.** Add a second declarative table mapping safeguard
  signals → maturity tier + risk level + required flags (AC1/AC4); replaces the prose derivation.
- **QUESTION — backlog namespace → adopt `AUDIT-`.** Thomas ratified the new prefix over reusing
  `BUG-`/`OPS-`. Direct consequence: a one-line `AUDIT-` entry is added to `BACKLOG.md`'s taxonomy
  so the convention is a real, ratified public record (Codex's stated condition for adopting it),
  and `BACKLOG.md` joins the enumerated scope. The "report first, don't create `BACKLOG.md`
  unprompted in a target repo" half of the finding is also adopted.

## Build note (2026-06-28)
AC → file map:
- AC1 detection + maturity rubric · AC2 tool-selection table · AC3 hybrid core/`command -v` ·
  AC4 report + artifact · AC5 safeguard flags · AC6 `AUDIT-` backlog hand-off · AC7 non-destructive
  + step-0 stand-down → `.claude/skills/dev-audit/SKILL.md`
- AC8 deploy + gate + docs → `install.sh` (ARTIFACTS), `.claude/workflow.json` (gate),
  `tests/dev_audit_test.sh` (drift linter), `README.md`, `ARCHITECTURE.md`, `BACKLOG.md`
  (system-map coherence, AC8 amended)

## Codex design review (2026-06-28)
Verdict: **would not ship the sketch as-is.** Core shape is aligned with the repo (Markdown skill,
frontmatter-only, declarative ecosystem→tool table, `command -v`-gated optional tools, drift-only
shell linting — all match local conventions, no new deps). Three findings to resolve first.

**BLOCKER — Missing native-workflow stand-down** · one-way · nonstandard
- *Claim:* The sketch adds a globally deployed skill that writes `reviews/audit-<date>.md` and
  later `BACKLOG.md` in a *target* repo, but omits the step-0 `docs/ai-protocol.md` opt-out that
  every existing global skill and the hook honor — so `/dev-audit` could write artifacts into a
  repo that explicitly opted out.
- *Alternative:* Resolve the target repo root first; if `docs/ai-protocol.md` exists there, STOP
  and point at that repo's native workflow before any write. Add the phrase to the drift linter.
- *Win:* One small guard preserves the global-skill invariant and prevents wrong-repo writes.

**IMPORTANT — Maturity and risk need a rubric table** · one-way · kludgy
- *Claim:* Tool choice is table-driven, but maturity tier + risk level are left as prose from a
  signal set. AC1/AC4 want *named* tiers and risk from explicit present/absent safeguards; without
  a declarative rubric the same profile can be classified differently across runs.
- *Alternative:* Add a second compact table mapping safeguard signals (CI, tests, pinned deps,
  secret handling, git hygiene) → `prototype`/`developing`/`mature` + risk level + required flags.
- *Win:* Centralizes the classification invariant; gives the linter a stable anchor; no new machinery.

**QUESTION — Backlog namespace is a protocol decision** · one-way · nonstandard
- *Claim:* The `AUDIT-` prefix (Open Question 2) is a public record convention, not local
  formatting — the backlog lifecycle and `/close` only recognize `BUG-`/`OPS-` today.
- *Alternative:* Default audit hand-off to existing `BUG-`/`OPS-` with audit provenance in the item
  text; adopt `AUDIT-` only as an explicit ratified decision. If `BACKLOG.md` is absent in a target
  repo, report suggested entries and require explicit instruction before creating it.
- *Win:* Avoids expanding the ID taxonomy / bookkeeping rules unless intentionally ratified.
