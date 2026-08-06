# claude-light-workflow

A lightweight, human-controlled development loop where **Claude builds, an independent reviewer critiques, and the
human decides** — with a small per-branch audit trail. A trimmed-down port of the heavier "AI
Protocol v3" (kept as a historical reference in
[`ai-dev-workflow-architecture.md`](ai-dev-workflow-architecture.md)), keeping only what's needed for
a good Claude↔Codex back-and-forth.

For the full picture of *this* system — requirements through intended implementation — see
[`ARCHITECTURE.md`](ARCHITECTURE.md). The normative rules live in
[`.claude/workflow-protocol.md`](.claude/workflow-protocol.md). Where things stand and where they're
headed is in [`ROADMAP.md`](ROADMAP.md).

## What this repo is

**This repo is where the workflow itself is authored — then deployed to run everywhere else.** The
skills (`/frame` `/review` `/close`, plus the recon tool `/dev-audit`) and the
guard hook live here as project-local files under `.claude/`; [`install.sh`](install.sh) copies them
to `~/.claude/`, so they operate across **every project on your machine**. The **loop** skills act on
whatever repo you're working in; the **recon** tools inspect a *target* repo you point them at.

This repo is the one **atypical** case: it *self-hosts* the workflow, so its own product is the
prompt-instructions you see here — which is why auditing *this* repo is a special case, not the norm
(the deploy targets are ordinary codebases). It's written for its owner first, but structured so
anyone could adopt it — clone, `./install.sh`, and run `/frame` in any project.

## The loop

| Skill | Does | Human gate |
|---|---|---|
| `/frame`  | request → spec **+ design sketch** → the reviewer design-reviews the sketch → implement AC-by-AC | **approves scope + design** |
| `/review` | gate green → **approach pass** (shape, best-practice) gates **correctness pass** (diff) → decision menu | **decides per finding** |
| `/close`  | apply approved fixes → re-review or merge → cleanup | **approves merge** |

**Who decides what.** The human is consulted at three altitudes — **requirements**, **high-level
design** (the `/frame` design sketch), and **implementation tradeoffs** (the `/review` approach pass)
— plus the merge. Blocking is gated by reversibility: only **one-way-door** decisions (architecture,
data model, a new dependency, or a cross-cutting pattern future code will copy) stop you; reversible
calls default to Claude, logged for veto. Independently, the reviewer **always** assesses each change against
modern best practice and flags substandard choices — even reversible ones — with guardrails (a
concrete win, not novelty). Full rules in [`.claude/workflow-protocol.md`](.claude/workflow-protocol.md).

On a first review both passes run; scope it with **`/review approach`** (force the approach pass) or
**`/review correctness`** (skip straight to the line-level pass). Re-reviews that only verify fixes are
correctness-only by default.

### Before the loop: recon (`/dev-audit`)
`/dev-audit [path]` is a standalone **pre-loop recon** step. It inspects a repo's languages,
frameworks, manifests, tests, CI, and secret-handling; classifies its type and maturity tier;
selects analysis tools that fit *that* repo (via a declarative ecosystem→tool table, **with
rationale**); runs a zero-dependency core plus any heavier tools already installed (it installs
nothing); and returns a brief report — findings, **risk level**, best-practice gaps, and prioritized
next steps — flagging missing safeguards (CI, tests, pinned deps, secret handling). It is read-only
and **report-first**: it graduates findings into [`BACKLOG.md`](BACKLOG.md) as `AUDIT-` items only on
an explicit instruction, and honors the same `docs/ai-protocol.md` stand-down as the loop skills.

A heavier whole-app, multi-lens audit was built and then stood down — the execution engine and its
library in August 2026, the surviving plan stage with it. Nothing is lost: the trees are preserved as
`retired/deep-audit-*` tags, recorded in [`BACKLOG.md`](BACKLOG.md) under OPS-13. The loop stays
diff-scoped by design; a whole-app sweep remains an open direction, not a shipped capability.

**The reviewer is selectable, per pass.** `.claude/workflow.json`'s `reviewer` field — or a
per-invocation override on `/review` (`/review fireworks`, `/review approach codex`) — picks the
backend. It takes either a bare string (that backend everywhere; the default is `codex`) or a
purpose→backend map, because a backend can be wired for some altitudes and not others:

```json
"reviewer": { "design": "fireworks", "approach": "fireworks",
              "correctness": "fireworks", "hidden-failure": "fireworks" }
```

Two backends are wired, both at **every** pass. **`codex`** is agentic — it explores the repo
itself. **`fireworks`** runs open-weight models through the Fireworks API. Selecting a pass/backend
pair that is *not* wired stops loudly rather than falling back — no such pair exists today, and the
rule stays as the guard every future backend inherits. `fireworks` is non-agentic, so a
vendored runner *pushes* the context and owns fan-out, joining, and all-or-nothing promotion; its
output is schema-enforced at the API and validated again before anything is written. Which model
serves which purpose lives in
[`fireworks-models.json`](.claude/skills/review/fireworks-models.json) — edit it to re-route, and
check it against your account with `fireworks_runner.py --check-models`. One-time setup is a
user-local venv from [`requirements.txt`](.claude/skills/review/requirements.txt); no admin needed.

Running two different models over one branch is the point, not a side effect — cross-model critics
are a defense against a single model's blind spots. The resolution rule and dispatch live in
[`review/SKILL.md`](.claude/skills/review/SKILL.md) → *Reviewer backend*; the role contract is the tool-neutral
[`workflow-AGENTS.md`](workflow-AGENTS.md) — **shared by every repo**, deployed once to
`~/.claude/workflow-AGENTS.md`, and delivered to whichever backend runs (the runner pushes it; the
codex prompts interpolate it inline).

The `codex` backend is called directly via the `codex` CLI — a read-only `codex exec -s read-only` run with a
structured-output schema (the canonical command lives in [`review/SKILL.md`](.claude/skills/review/SKILL.md)),
no copy/paste. It runs read-only and never commits; Claude captures its structured findings and commits the trail.

## Artifacts (the audit trail)
- [`BACKLOG.md`](BACKLOG.md) — staging area in front of the loop: bugs (`BUG-`), tooling improvements (`OPS-`), and recon findings (`AUDIT-`, from `/dev-audit`), each graduating to a `reviews/<slug>.md` story.
- `reviews/audit-<YYYY-MM-DD>.md` — a `/dev-audit` recon report (standalone; not a loop story).
- `reviews/<slug>.md` — spec + design sketch → reviewer findings → decisions, appended across rounds.
- `reviews/<slug>.design.json` — frame-time design-sketch review, plus the reviewer's per-criterion regression list.
- `reviews/<slug>.approach.json` — review-time approach-pass output.
- `reviews/<slug>.codex.json` — review-time correctness output per round.
- `.claude/workflow.json` — per-repo config: `baseBranch`, `branchPrefix`, `testCommand`, `reviewer`, `codexModel`.
- `AGENTS.md` — **optional**, and repo-specific **additions only** — never a copy of the shared contract. Most repos have none; that is the normal case. The shared contract is global, not per-repo (below).

The story header records only declared state (`proposed → approved`). Whether it shipped is owned by git — the `merge: <slug>` commit / PR-`MERGED` state — and read back by deriving (`git log <base> --grep "^merge: <slug>"`), never stored in the header.

## Guardrail
One hook, [`block-main-writes.sh`](.claude/hooks/block-main-writes.sh), parses each command's real
`git` invocation (so `git -C <repo> commit` and `git -c k=v commit` are caught, and a `grep 'git push'`
is not). It trips when **the current branch is literally `main` or `master`** and the command is a
`commit` or `push`, and on any `--no-verify` or force-push
(`--force` / `--force-with-lease` / `-f` / `--mirror` / `+refspec`).

It is a **cooperative tripwire for ordinary Git usage, not an exhaustive base-branch firewall.** By
design it does **not** catch:
- a **configured non-standard base branch** — the trigger set is the literal `{main, master}`, not the
  `baseBranch` from `.claude/workflow.json` (so a `trunk` base is not guarded);
- a **destination-refspec push from a feature branch** — `git push origin HEAD:main` writes to `main`
  but only the *current* branch is checked, not the target ref;
- **`env`-wrapped or nested-shell git** — `env git commit …` and `bash -lc "git commit …"` route around
  the top-level-`git` parse.

So the hook keeps you from *fat-fingering* a commit while sitting on `main`; it is not an adversarial
sandbox. The real backstop is **server-side branch protection**: `main` requires the CI `gate` check
to pass, requires a PR to merge, and enforces this for admins too (`enforce_admins=true`) — closing
the gaps the cooperative hook can't cover server-side. That protection is **repo setup, configured
once** with `gh api` after observing the CI check's context name — not something `/close` performs.
`/close` only *reads* whether required checks exist, to pick its merge strategy, and then merges via
auto-merge. The hook's own behavior is still pinned by
[`tests/guard_test.sh`](tests/guard_test.sh) (the gate).

## Continuous integration
[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the **gate** (the configured workflow test suites) plus
`shellcheck` and a **gitleaks** diff scan on every PR and push to `main`; it is the required status
check enforced by branch protection. [`.github/workflows/scheduled.yml`](.github/workflows/scheduled.yml)
re-scans the **full history** for secrets weekly (drift check). GitHub-native **secret scanning +
push protection** are enabled as a continuous first line. External actions are pinned to full commit
SHAs and the gitleaks binary is checksum-verified. Because `main`'s branch protection requires the
`gate` check, `/close` merges via **auto-merge** (`allow_auto_merge`) — GitHub waits for the check,
then merges.

## Deferring to a repo's native workflow
Because the skills + hook install globally (`~/.claude`), they reach every repo. A repo that already
runs a heavier/native workflow signals it with a **`docs/ai-protocol.md`** marker at its root. When
that marker is present, the light workflow **stands down**: the guard hook becomes a no-op (the
repo's own hooks govern) and `/frame`, `/review`, `/close` — and the recon tool `/dev-audit`, before it reads or writes anything — stop and point you at the native skills.
Repos without the marker are governed by the light workflow as normal.

## Test here, then deploy everywhere
1. **Test** in this repo (skills/hook are project-local under `.claude/`). Run a real `/frame → /review → /close`.
2. **Deploy** to every Claude Code app on this machine: `./install.sh` copies the skills + hook to
   `~/.claude/` and wires the hook into `~/.claude/settings.json` (idempotent, backs up first).
3. In each app, run `/frame` once — it bootstraps that repo's `.claude/workflow.json` + `AGENTS.md`.

## Requirements
`codex` CLI (`codex exec`), `git`, `python3`, `jq`. `gh` + a remote enable PR mode; without a
remote the loop runs fully local (local `--no-ff` merge).

## License
MIT — Copyright (c) 2026 Thomas B. Cox. See [LICENSE](LICENSE) for the full text.
