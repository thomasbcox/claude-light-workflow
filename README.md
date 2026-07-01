# claude-light-workflow

A lightweight, human-controlled development loop where **Claude builds, Codex critiques, and the
human decides** — with a small per-branch audit trail. A trimmed-down port of the heavier "AI
Protocol v3" (kept as a historical reference in
[`ai-dev-workflow-architecture.md`](ai-dev-workflow-architecture.md)), keeping only what's needed for
a good Claude↔Codex back-and-forth.

For the full picture of *this* system — requirements through intended implementation — see
[`ARCHITECTURE.md`](ARCHITECTURE.md). The normative rules live in
[`.claude/workflow-protocol.md`](.claude/workflow-protocol.md).

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

### Before the loop: `/dev-audit`
`/dev-audit [path]` is a standalone **pre-loop recon** step. It inspects a repo's languages,
frameworks, manifests, tests, CI, and secret-handling; classifies its type and maturity tier;
selects analysis tools that fit *that* repo (via a declarative ecosystem→tool table, **with
rationale**); runs a zero-dependency core plus any heavier tools already installed (it installs
nothing); and returns a brief report — findings, **risk level**, best-practice gaps, and prioritized
next steps — flagging missing safeguards (CI, tests, pinned deps, secret handling). It is read-only
and **report-first**: it graduates findings into [`BACKLOG.md`](BACKLOG.md) as `AUDIT-` items only on
an explicit instruction, and honors the same `docs/ai-protocol.md` stand-down as the loop skills.

**The reviewer is selectable.** `.claude/workflow.json`'s `reviewer` field (default `codex`) — or a
per-invocation override on `/review` (`/review llm`, `/review approach codex`) — picks the backend.
**Codex is the only wired backend today;** selecting `llm` (the [`llm` CLI](https://llm.datasette.io),
the designated second source) stops with a "not yet wired" message (a follow-up will wire it). The set
is extensible to further backends. The resolution rule and dispatch live in
[`review/SKILL.md`](.claude/skills/review/SKILL.md) → *Reviewer backend*; the role contract is the
tool-neutral [`AGENTS.md`](AGENTS.md), read automatically by whichever backend runs.

Codex is called directly via the `codex` CLI — a read-only `codex exec -s read-only` run with a
structured-output schema (the canonical command lives in [`review/SKILL.md`](.claude/skills/review/SKILL.md)),
no copy/paste. It runs read-only and never commits; Claude captures its structured findings and commits the trail.

## Artifacts (the audit trail)
- [`BACKLOG.md`](BACKLOG.md) — staging area in front of the loop: bugs (`BUG-`), tooling improvements (`OPS-`), and recon findings (`AUDIT-`, from `/dev-audit`), each graduating to a `reviews/<slug>.md` story.
- `reviews/audit-<YYYY-MM-DD>.md` — a `/dev-audit` recon report (standalone; not a loop story).
- `reviews/<slug>.md` — spec + design sketch → Codex findings → decisions, appended across rounds.
- `reviews/<slug>.design.json` — frame-time Codex design-sketch review.
- `reviews/<slug>.approach.json` — review-time approach-pass output.
- `reviews/<slug>.codex.json` — review-time correctness output per round.
- `.claude/workflow.json` — per-repo config: `baseBranch`, `branchPrefix`, `testCommand`, `reviewer`, `codexModel`.
- `AGENTS.md` — the (tool-neutral) reviewer contract.

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
the gaps the cooperative hook can't cover server-side. `/close` establishes this protection as part
of the merge flow (using the CI check's observed context) and then merges via auto-merge. The hook's
own behavior is still pinned by [`tests/guard_test.sh`](tests/guard_test.sh) (the gate).

## Continuous integration
[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the **gate** (the three test suites) plus
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
repo's own hooks govern) and `/frame`, `/review`, `/close` — and `/dev-audit`, before it reads or writes anything — stop and point you at the native skills.
Repos without the marker are governed by the light workflow as normal.

## Test here, then deploy everywhere
1. **Test** in this repo (skills/hook are project-local under `.claude/`). Run a real `/frame → /review → /close`.
2. **Deploy** to every Claude Code app on this machine: `./install.sh` copies the skills + hook to
   `~/.claude/` and wires the hook into `~/.claude/settings.json` (idempotent, backs up first).
3. In each app, run `/frame` once — it bootstraps that repo's `.claude/workflow.json` + `AGENTS.md`.

## Requirements
`codex` CLI (`codex exec`), `git`, `python3`, `jq`. `gh` + a remote enable PR mode; without a
remote the loop runs fully local (local `--no-ff` merge).
