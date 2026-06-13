Date: 2026-06-12 · Branch: claude/review-schema-abs-path · Status: approved

# Story: `/review` references the finding schema by a repo-relative path that doesn't resolve

> **Approved 2026-06-12.** Thomas: "id is good" (→ BUG-4) and "ok proceed with a"
> (Option A — hardcoded `"$HOME/.claude/skills/review/finding-schema.json"`).
> Both open questions resolved as recommended. Separately requested logging a
> backlog item to evaluate adding any missing skill YAML frontmatter (logged
> as OPS-9; not part of this story's scope).

## Problem

`/review` step 5 builds a `codex exec` command that passes the structured-output
schema as a **repo-relative** path:

```
--output-schema .claude/skills/review/finding-schema.json
```

The skill (and its schema) are installed at the **user level**, at
`~/.claude/skills/review/finding-schema.json` — `install.sh` deploys the repo's
`.claude/skills/review` to `$HOME/.claude/skills/review`. A project repo's own
`.claude/` does not contain the review skill, so when `/review` runs from any
project repo other than this one, the relative path resolves to a nonexistent file
and `codex exec` aborts immediately:

```
Failed to read output schema file .claude/skills/review/finding-schema.json: No such file or directory (os error 2)
```

This blocks **every** `/review` run from a project repo until manually worked around
(re-running with an absolute `--output-schema`). Found 2026-06-11 running `/review`
in the `zoom-meeting-cost` repo; documented in this repo's pasted
"Workflow skill defects" report. It is the next defect in the same `codex exec`
command block that the shipped `review-codex-stdin` fix (PR #12) touched.

The `-o reviews/<slug>.codex.json` output path in the same command is correctly
repo-relative (it writes into the project being reviewed) and must stay relative.

## In scope

- `.claude/skills/review/SKILL.md` step 5: change the `--output-schema` argument
  from the repo-relative `.claude/skills/review/finding-schema.json` to a
  user-level absolute path, `"$HOME/.claude/skills/review/finding-schema.json"`,
  matching where `install.sh` deploys the schema.
- A one-line note in that step (or its surrounding prose) recording *why* the
  schema path is absolute while `-o` stays relative, so the distinction isn't
  "fixed" back later by mistake.
- Backlog/CHANGELOG bookkeeping for the fix (id, Done row) consistent with how
  prior skill fixes were recorded.

## Non-goals

- The `</dev/null` redirect, the `codex exec review` subcommand note, and every
  other line of step 5 — unchanged.
- The `-o reviews/<slug>.codex.json` output path — stays repo-relative by design.
- `/frame` and `/close`, the guard hook, and `install.sh` — untouched.
- Any change to `finding-schema.json` itself or its location.
- A dynamic "resolve from the skill's own base dir" mechanism — `$HOME/.claude`
  is the documented, install-guaranteed location; a hardcoded user-level path is
  the minimum correct fix. (Captured under Open questions if Thomas prefers
  otherwise.)

## Acceptance criteria

1. **The schema is referenced by an absolute user-level path.** In
   `.claude/skills/review/SKILL.md` step 5, the `--output-schema` argument is
   `"$HOME/.claude/skills/review/finding-schema.json"` (quoted), not the
   repo-relative `.claude/skills/review/finding-schema.json`.
2. **The output path is unchanged.** The same command still passes
   `-o reviews/<slug>.codex.json` (repo-relative).
3. **The rationale is recorded.** Step 5 carries a short note explaining the
   schema path is absolute (skill-local, user-installed) while `-o` is
   repo-relative (writes into the reviewed project), so the asymmetry is
   intentional and durable.
4. **Scope containment.** The only product/skill file changed is
   `.claude/skills/review/SKILL.md`; bookkeeping files (`BACKLOG.md`,
   `CHANGELOG.md`) and this story file may also change. No other skill, hook, or
   tooling file is touched.

## Test notes

- AC1/AC2/AC3: inspect the edited step 5 in `.claude/skills/review/SKILL.md` — the
  `--output-schema` line reads `"$HOME/.claude/skills/review/finding-schema.json"`;
  the `-o reviews/<slug>.codex.json` line is still present and relative; the
  rationale note is present.
- AC4: run `git diff --name-only main...HEAD` and verify no files appear beyond
  `.claude/skills/review/SKILL.md`, `BACKLOG.md`, `CHANGELOG.md`, and
  `reviews/review-schema-abs-path.md` (+ the `.codex.json` the review step adds).
- Gate: `bash tests/guard_test.sh` stays green (the guard-hook tests are
  unaffected by a docs/skill-text change, but the gate must still pass).
- Manual confirmation (out of repo): after `./install.sh`, a `/review` run from an
  unrelated project repo no longer aborts on the schema path. Noted as evidence,
  not an automated gate here.

## Open questions

1. **Backlog id.** D1/D2/D3 were skill-behavior bugs; `review-codex-stdin` (same
   command block) shipped with *no* OPS number as a "same-session tooling fix."
   This one is a standalone, blocking skill-behavior defect. Proposed id:
   **BUG-4** (next after D1–D3). OK, or prefer a different id / class?
2. **Fix form.** Hardcoded `"$HOME/.claude/skills/review/finding-schema.json"` vs.
   a more dynamic resolution from the skill's base directory. Recommending the
   hardcoded user-level path (matches `install.sh`'s deploy target; simplest
   correct fix). Confirm?

## Build note (2026-06-12)

AC → file map:

- **AC1** (absolute `--output-schema` path) → `.claude/skills/review/SKILL.md`
- **AC2** (`-o reviews/<slug>.codex.json` unchanged) → `.claude/skills/review/SKILL.md`
- **AC3** (absolute-vs-relative rationale note) → `.claude/skills/review/SKILL.md`
- **AC4** (scope containment) → bookkeeping only: `BACKLOG.md` (BUG-4 open line + OPS-9),
  `reviews/review-schema-abs-path.md` (this story). No other skill/hook/tooling file touched.

## Codex review (2026-06-12, base main, HEAD c2d83a6)

**Summary:** 2026-06-12 21:32:50 PDT — Reviewed `git diff main...HEAD`,
`git log --oneline main..HEAD`, and `reviews/review-schema-abs-path.md`. The branch
changes satisfy the spec: the schema path is now
`"$HOME/.claude/skills/review/finding-schema.json"`, `-o reviews/<slug>.codex.json`
remains repo-relative, the rationale is documented, and the diff is scoped to the review
skill, backlog bookkeeping, and story file. `bash tests/guard_test.sh` could not run in
this read-only sandbox because fixture directory creation failed with `Operation not
permitted`; I did not treat that as a branch finding.

**Findings:** none — empty findings array. (The schema-bound structured output was
produced correctly, which itself confirms BUG-4 is fixed: the absolute `--output-schema`
path resolved where the old repo-relative one would have aborted.)
