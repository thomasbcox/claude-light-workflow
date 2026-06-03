Date: 2026-06-03 · Branch: claude/defer-to-native · Status: approved

> Approved by Thomas (2026-06-03): "yes build then review"

## Problem
The light workflow is installed globally (`~/.claude`), so its guard hook and `/frame /review
/close` skills now reach into *every* repo — including `hw-biz-model`, which runs the older, heavier
v3 workflow with its own hooks and `/start-story…` skills. The result is harmless but messy: the
global guard hook double-fires next to the repo's native hooks (duplicate "blocked" messages), and
the light slash-commands appear alongside the native ones (risk of invoking the wrong loop). The
light workflow should recognize a repo that already has a native workflow and **stand down** there.

## In scope
- Marker-based detection: a repo "has a native workflow" iff `docs/ai-protocol.md` exists at the repo
  root (the canonical v3 protocol file).
- `.claude/hooks/block-main-writes.sh`: early `exit 0` (no-op) when the marker is present, so the
  repo's own hooks govern unopposed.
- `.claude/skills/{frame,review,close}/SKILL.md`: a guard at the very top — if the marker is present,
  stop immediately and tell the user to use the repo's native workflow instead of this skill.
- README note documenting the deferral behavior.

## Non-goals
- No change to behavior in repos *without* the marker (the light workflow governs as today).
- No attempt to hide/unregister the global skills per-repo (Claude Code has no per-repo skill
  disable); self-deferral via the in-skill guard is the chosen mechanism.
- No change to the heavy workflow in `hw-biz-model`.
- No new config knobs; the marker filename is fixed.

## Acceptance criteria
1. `block-main-writes.sh` exits 0 immediately (allowing the action, deferring to native hooks) when
   `docs/ai-protocol.md` exists at the git repo root — checked before any commit/push/force logic.
2. In a repo WITHOUT the marker, `block-main-writes.sh` behaves exactly as before (still blocks
   commit/push to base, `--force`, `--no-verify`).
3. Each of `frame/review/close` SKILL.md begins with a deferral guard step: "if `docs/ai-protocol.md`
   exists at the repo root, stop and direct the user to the native workflow."
4. The marker check is resolved against the git repo root (so it works regardless of the cwd within
   the repo), and is safe when not in a git repo (no error, normal behavior).
5. README documents the deferral.

## Test notes
- AC1/AC2/AC4: invoke the hook script with crafted stdin JSON in (a) a temp dir containing
  `docs/ai-protocol.md` → expect exit 0 on a `git commit`-on-main payload; (b) this repo (no marker)
  on main → expect exit 2 (still blocked). Also test outside any git repo → no error.
- AC3: read each SKILL.md; confirm the guard step is present and is step 0/1.
- AC5: read README.
- Configured gate (placeholder `true`) is run for process parity.

## Open questions
- None. Marker = `docs/ai-protocol.md`, deferral = full stand-down (hook no-op + skill stop).
