# Architecture — claude-light-workflow

What this system is, why it is shaped this way, and how the pieces fit — from requirements through
intended implementation. This is the live design doc for *this* repo. The quick-start and command
table live in [`README.md`](README.md); the normative rules live in
[`.claude/workflow-protocol.md`](.claude/workflow-protocol.md). The heavier parent it was trimmed from
is documented, historically, in [`ai-dev-workflow-architecture.md`](ai-dev-workflow-architecture.md).

Order below: **Requirements** (the problem and the constraints) → **Approach** (the shape of the
solution) → **Intended implementation** (the concrete parts).

---

## 1. Requirements

### 1.1 The failure mode it designs against

The default way to use an AI coding agent is: one model invents the spec, writes the code, reviews its
own code, declares success, and ships. Every step is the same biased actor. A builder — human or AI —
is structurally inclined to see its own work as finished, so the result is plausible-looking work that
drifts from intent, skips edge cases, and accumulates regressions nobody independent ever challenged.

### 1.2 The goal

**Separate doing from judging, and keep a human as the only decider** — without making the human
scribe specs, run the gate, or babysit Git mechanics. The system should turn a casual request into a
reviewed, tested, independently-critiqued change with a small, honest audit trail.

### 1.3 Constraints that shape it

- **Lightweight.** It is a deliberate trim of the parent "AI Protocol v3." Keep only what a good
  Claude↔Codex back-and-forth needs; no dbt/DuckDB gates, no large hook/script suite.
- **Human-controlled at the one-way doors.** The human is consulted at three altitudes —
  requirements, high-level design, implementation tradeoffs — plus the merge. Reversible calls default
  to Claude (logged for veto); only irreversible ones block.
- **No self-grading.** The actor that builds is never the actor that approves.
- **Installs globally, must not hijack other repos.** The skills + hook deploy to `~/.claude` and
  therefore reach every repo on the machine, so a repo running its own heavier workflow must be able
  to make this one stand down.
- **The repo is the source of truth.** Declared state lives in small per-branch files; shipped state
  is owned by git and read back, never hand-written.

---

## 2. Approach

### 2.1 Three actors

| Actor | Role | Constraint |
|---|---|---|
| **Thomas** | Owner / decider | Speaks casually; makes every scope, design, and merge call |
| **Claude** | Builder / scribe | Turns intent into spec + code + trail; never approves its own work |
| **The reviewer** | Independent reviewer (selectable backend; codex today) | Read-only critique; classifies findings; never fixes, never merges |
| **The gate** | Non-LLM judge | `tests/guard_test.sh` (configurable); objective pass/fail |

### 2.2 Three skills, three human gates

The loop is three skills, each ending at a human decision:

| Skill | Does | Human gate |
|---|---|---|
| [`/frame`](.claude/skills/frame/SKILL.md) | request → spec **+ design sketch** → the reviewer design-reviews the sketch → implement AC-by-AC | **approves scope + design** |
| [`/review`](.claude/skills/review/SKILL.md) | gate green → **approach pass** (shape) gates **correctness pass** (diff) → decision menu | **decides per finding** |
| [`/close`](.claude/skills/close/SKILL.md) | apply approved fixes → re-review or merge → cleanup | **approves merge** |

### 2.2a Before the loop: `/dev-audit` (recon)

The three skills above act on *one stated change*. A separate, standalone skill,
[`/dev-audit`](.claude/skills/dev-audit/SKILL.md), acts *before* there is a change: pointed at a
repo, it detects type + maturity, selects analysis tools that fit (with rationale), runs a
zero-dependency core plus any installed heavier tools (installing nothing), and reports findings +
risk + prioritized next steps. It is **not a loop step** and has no merge gate — it is read-only
and report-first. Its single seam to the loop is the backlog: on an explicit instruction it
graduates findings into [`BACKLOG.md`](BACKLOG.md) as `AUDIT-` items, which then flow through
`/frame → /review → /close` like any other line. It honors the same `docs/ai-protocol.md`
stand-down (§3.5) as the loop skills.

### 2.3 Reversibility-gated blocking

Not every decision should stop the loop. Blocking is gated by reversibility: **one-way-door**
decisions (architecture, data model, a public contract, a new dependency, or a cross-cutting pattern
future code will copy) require the human; **two-way** calls default to Claude and are logged for veto.
Independently of reversibility, the reviewer **always** assesses each change against modern best practice and
may flag substandard choices — with guardrails (a concrete win, not novelty; internal consistency
weighed; repo conventions are the local standard).

### 2.4 Declared state vs. observed state

A story header records only *declared* state: `proposed → approved`. `approved` is terminal. Whether
the change actually shipped is *observed* state, owned by git — the `merge: <slug>` commit / the PR's
`MERGED` state — and read back by deriving, never written into the header. This keeps the trail from
lying about what merged.

---

## 3. Intended implementation

### 3.1 The skills

Each skill is a Markdown "skill file" under [`.claude/skills/`](.claude/skills/) that Claude Code loads
on demand and follows step-by-step. `/frame` produces `reviews/<slug>.md` (spec + design sketch),
runs a *design* review of the sketch (via the configured reviewer) before any code exists, stops for scope+design approval,
then implements AC-by-AC on a feature branch. `/review` runs the gate, then an approach pass (shape vs.
best practice) that gates a correctness pass (the diff), each via the reviewer, and presents a decision menu.
`/close` applies only human-approved fixes, re-runs the gate, and — on an explicit, in-session merge
instruction — merges the feature branch and cleans up.

### 3.2 Reviewer invocation (and backend selection)

The independent reviewer is a **selectable backend**, resolved per run as *override → config → default*:
a per-invocation `/review` argument (`/review llm`) beats the `reviewer` field in
[`.claude/workflow.json`](.claude/workflow.json), which beats the default `codex`. The canonical
resolution rule and per-backend dispatch live in [`review/SKILL.md`](.claude/skills/review/SKILL.md)
(→ *Reviewer backend*); `/frame` and `/close`-time re-review use the config default (no override
surface). The role contract, [`AGENTS.md`](AGENTS.md), is tool-neutral and read automatically by
whichever backend runs.

**Codex is the only wired backend.** It is called directly through the `codex` CLI as a read-only
`codex exec -s read-only` run with a structured-output JSON schema — no copy/paste; it never commits,
and Claude captures its structured findings into the trail. Selecting **`llm`** — the
[`llm` CLI](https://llm.datasette.io), the designated second source — is a recognized choice but
**stops with a "not yet wired" message**: a deliberate seam, not a silent fallback. Wiring it is a
follow-up, and `llm` is not a `codex exec` drop-in either, but for the *opposite* reason agy wasn't:
it is **non-agentic** — it cannot run `git diff` or explore the repo, so the harness must assemble the
context (the diff + the spec) and pipe it in — though in exchange it is **inherently read-only** (no
file tools, so no sandbox or worktree) and emits schema-valid JSON natively via `--schema`. Either way
the lesson holds: a backend must *guarantee* read-only execution + schema-valid JSON however it can
(codex via flags, `llm` via harness-fed context + `--schema`), rather than share codex's command shape.
This seam keeps codex byte-for-byte unchanged while making that second backend a contained, additive
change — and the set is extensible to further backends by the same pattern.

(The earlier candidate, Google's Antigravity `agy`, was abandoned: no read-only file sandbox, no
schema output, fragile non-TTY capture — and Google has since folded the headless Gemini CLI into
Antigravity, closing that path. See the story trail for the autopsy.)

### 3.3 The artifact trail

- [`BACKLOG.md`](BACKLOG.md) — staging area in front of the loop: bugs (`BUG-`), tooling
  improvements (`OPS-`), and recon findings (`AUDIT-`, from `/dev-audit`), each graduating into a
  `reviews/<slug>.md` story.
- `reviews/audit-<YYYY-MM-DD>.md` — a `/dev-audit` recon report (standalone; not a loop story).
- `reviews/<slug>.md` — spec + design sketch → reviewer findings → decisions, appended across rounds.
- `reviews/<slug>.design.json` — frame-time design-sketch review.
- `reviews/<slug>.approach.json` / `reviews/<slug>.codex.json` — review-time approach + correctness output.
- [`.claude/workflow.json`](.claude/workflow.json) — per-repo config: `baseBranch`, `branchPrefix`,
  `testCommand`, `reviewer`, `codexModel`.

### 3.4 The one hook — and what it really enforces

A single PreToolUse hook on the Bash tool,
[`block-main-writes.sh`](.claude/hooks/block-main-writes.sh), keeps the feature-branch + merge
discipline. It parses each command's real `git` invocation (argv), not the raw string, so
`git -C <repo> commit` and `git -c k=v commit` are caught while `grep 'git push'` is not.

It is a **cooperative tripwire for ordinary Git usage, not an exhaustive base-branch firewall.** It
trips when the **current branch is literally `main` or `master`** and the command is a `commit` or
`push`, and on any `--no-verify` or force-push. By design it does **not** catch:

- a **configured non-standard base branch** — the trigger set is the literal `{main, master}`, not the
  `baseBranch` from `.claude/workflow.json` (a `trunk` base is unguarded);
- a **destination-refspec push from a feature branch** (`git push origin HEAD:main`) — only the
  current branch is checked, not the target ref;
- **`env`-wrapped or nested-shell git** (`env git commit …`, `bash -lc "git commit …"`).

The point is to stop a fat-fingered commit while sitting on `main`, not to be an adversarial sandbox.
The real backstop is **server-side branch protection**, now **active** (§3.4a); the hook's behavior is
pinned by [`tests/guard_test.sh`](tests/guard_test.sh), the gate. The `/frame`, `/review`, `/close`
rules say "never commit/push to base directly" as a rule Claude follows *regardless* of what the hook
mechanically catches.

### 3.4a CI and the server-side backstop

The cooperative hook is now backed by an authoritative server-side gate. Two workflows under
[`.github/workflows/`](.github/workflows/):
- **`ci.yml`** — on every PR / push to `main`, runs the **gate** (the three test suites) + `shellcheck`
  + a **gitleaks diff** scan. The `gate` job is a **required status check** on `main`.
- **`scheduled.yml`** — weekly, re-scans the **full history** for secrets (a drift check for new rules
  / out-of-band history changes). Advisory.

Branch protection on `main` requires that check, requires a PR to merge, and sets `enforce_admins=true`
so the operator's own token can't bypass it — closing the local-hook gaps (non-standard base,
destination-refspec push, `env`-wrapped git) server-side. Approval stays in the loop, not GitHub
(`required_approving_review_count=0`). Consequently `/close` merges via **auto-merge**
(`allow_auto_merge=true`): its preflight resolves to `MODE=auto`, and GitHub performs the merge once
the required check is green (the OPS-4/5 auto-merge path, now the normal route). Supply-chain posture:
external actions are pinned to full commit SHAs and the gitleaks binary is checksum-verified; workflows
run with minimal `permissions: contents: read`. GitHub-native **secret scanning + push protection** run
continuously as a zero-maintenance first line.

### 3.5 Deferring to a repo's native workflow

Because everything installs globally, a repo that runs its own heavier workflow opts out by placing a
**`docs/ai-protocol.md`** marker at its root. When present, the hook becomes a no-op (the repo's own
hooks govern) and `/frame`, `/review`, `/close` — and `/dev-audit`, before it reads or writes
anything — stop and point at the native skills.

### 3.6 Test here, deploy everywhere

The skills (the three loop skills plus `/dev-audit`) + hook are project-local under `.claude/` so they
can be exercised here with a real `/frame → /review → /close`. [`install.sh`](install.sh) then copies
them — its `ARTIFACTS` set is the single source of truth for the deployed files — to `~/.claude/` and
wires the hook into `~/.claude/settings.json` (idempotent, backs up first); `./install.sh --check`
reports drift.
In each app, the first `/frame` bootstraps that repo's `.claude/workflow.json` + `AGENTS.md`.

### 3.7 Requirements (tooling)

`codex` CLI (`codex exec`), `git`, `python3`, `jq`. `gh` + a remote enable PR mode; without a remote
the loop runs fully local (local `--no-ff` merge).
