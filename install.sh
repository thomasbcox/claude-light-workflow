#!/usr/bin/env bash
# Promote the lightweight Claude↔Codex workflow from this repo to user scope (~/.claude),
# so every Claude Code app on this machine gets the skills + guard hook.
#
# Usage:
#   ./install.sh            Deploy (hard-overwrite) + stamp a provenance manifest. Idempotent;
#                           never clobbers your existing settings.json. If a prior deployment
#                           exists, prints what's about to be clobbered first (OPS-3).
#   ./install.sh --check    Read-only. Report drift between this repo and the deployment, and
#                           the deployment's provenance. Exit non-zero if any artifact drifted.
#
# Deploy target defaults to ~/.claude; override with CLAUDE_WORKFLOW_DEST (used for testing).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_WORKFLOW_DEST:-$HOME/.claude}"
MANIFEST="$DEST/workflow-manifest.json"

# Single source of truth for the deployed artifact set — shared by install and --check.
# Each entry is "<src-path-relative-to-repo>::<dest-path-relative-to-DEST>".
ARTIFACTS=(
  ".claude/skills/frame::skills/frame"
  ".claude/skills/review::skills/review"
  ".claude/skills/close::skills/close"
  ".claude/skills/dev-audit::skills/dev-audit"
  ".claude/hooks/block-main-writes.sh::hooks/block-main-writes.sh"
  ".claude/workflow-protocol.md::workflow-protocol.md"
  "AGENTS.md::workflow-AGENTS-template.md"
)

src_commit() { git -C "$SRC" rev-parse HEAD 2>/dev/null || echo "unknown"; }
src_dirty()  {
  if git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1; then
    [ -n "$(git -C "$SRC" status --porcelain 2>/dev/null)" ] && echo true || echo false
  else
    echo false
  fi
}

# Classify a drifted artifact against the deployment's recorded commit:
#   STALE       — deployed copy matches the repo content AT the manifest commit (repo moved
#                 forward; a re-install is safe).
#   HAND-EDITED — matches neither current repo nor the manifest commit (local edits a
#                 re-install would destroy).
#   UNCLASSIFIED — no usable recorded commit.
classify_drift() {  # args: <src-rel> <dest-path> <commit>
  local srcrel="$1" destpath="$2" commit="$3" tmp
  if [ -z "$commit" ] || [ "$commit" = "unknown" ]; then echo "UNCLASSIFIED"; return; fi
  # The recorded commit must be resolvable in THIS checkout, else we can't compare the deployed
  # copy against it — report UNCLASSIFIED rather than guessing HAND-EDITED (a false "you'll lose
  # local edits" alarm). This covers a SHA absent from this clone (e.g. another machine's commit).
  if ! git -C "$SRC" cat-file -e "$commit^{tree}" 2>/dev/null; then echo "UNCLASSIFIED"; return; fi
  tmp="$(mktemp -d)"
  # If the recorded commit resolves but its archive/extract for this path fails, we still have no
  # ground truth to compare against — UNCLASSIFIED, not HAND-EDITED.
  if ! git -C "$SRC" archive "$commit" -- "$srcrel" 2>/dev/null | tar -x -C "$tmp" 2>/dev/null; then
    rm -rf "$tmp"; echo "UNCLASSIFIED"; return
  fi
  if diff -rq "$DEST/$destpath" "$tmp/$srcrel" >/dev/null 2>&1; then
    echo "STALE"
  else
    echo "HAND-EDITED"
  fi
  rm -rf "$tmp"
}

# Scan the deployment: print provenance + per-artifact status. Sets DRIFT_COUNT / HANDEDIT_COUNT.
# arg1: show_insync (1 = list IN SYNC lines too; 0 = only drift).
DRIFT_COUNT=0
HANDEDIT_COUNT=0
scan() {
  local show_insync="$1" rec_commit="" rec_dirty="" rec_time="" cur
  DRIFT_COUNT=0; HANDEDIT_COUNT=0
  cur="$(src_commit)"
  if [ -f "$MANIFEST" ]; then
    rec_commit="$(jq -r '.sourceCommit // "unknown"' "$MANIFEST" 2>/dev/null || echo unknown)"
    rec_dirty="$(jq -r '.dirty // false'        "$MANIFEST" 2>/dev/null || echo false)"
    rec_time="$(jq -r '.installedAt // "?"'     "$MANIFEST" 2>/dev/null || echo '?')"
    local dnote=""; [ "$rec_dirty" = "true" ] && dnote=" (dirty tree)"
    echo "  provenance: deployed from ${rec_commit}${dnote} at ${rec_time}"
    if [ "$rec_commit" = "$cur" ]; then
      echo "              ↳ matches repo HEAD (${cur})"
    else
      echo "              ↳ repo HEAD is now ${cur} — deployment is from an earlier commit (stale provenance)"
    fi
  else
    echo "  provenance: no manifest at $MANIFEST (pre-OPS-2 deployment) — cannot determine source commit"
  fi
  local entry srcrel destpath cls
  for entry in "${ARTIFACTS[@]}"; do
    srcrel="${entry%%::*}"; destpath="${entry##*::}"
    if [ ! -e "$DEST/$destpath" ]; then
      echo "  DRIFT  $destpath — MISSING from deployment"
      DRIFT_COUNT=$((DRIFT_COUNT+1)); continue
    fi
    if diff -rq "$SRC/$srcrel" "$DEST/$destpath" >/dev/null 2>&1; then
      [ "$show_insync" = "1" ] && echo "  IN SYNC  $destpath"
    else
      cls="$(classify_drift "$srcrel" "$destpath" "$rec_commit")"
      if [ "$cls" = "UNCLASSIFIED" ]; then
        echo "  DRIFT  $destpath — UNCLASSIFIED (recorded commit unavailable — cannot tell stale from hand-edited)"
      else
        echo "  DRIFT  $destpath — $cls"
      fi
      DRIFT_COUNT=$((DRIFT_COUNT+1))
      [ "$cls" = "HAND-EDITED" ] && HANDEDIT_COUNT=$((HANDEDIT_COUNT+1))
    fi
  done
  return 0   # status comes from DRIFT_COUNT, never the loop's last short-circuited test
}

do_check() {
  echo "Drift check: repo $SRC  ↔  deployment $DEST"
  scan 1
  echo
  if [ "$DRIFT_COUNT" -eq 0 ]; then
    echo "✓ In sync — all ${#ARTIFACTS[@]} artifacts match the repo."
    exit 0
  fi
  echo "✗ $DRIFT_COUNT artifact(s) drifted ($HANDEDIT_COUNT hand-edited). Run ./install.sh to redeploy."
  exit 1
}

write_manifest() {
  local commit dirty ts arts artjson
  commit="$(src_commit)"; dirty="$(src_dirty)"; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  arts=(); local entry; for entry in "${ARTIFACTS[@]}"; do arts+=("${entry##*::}"); done
  artjson="$(printf '%s\n' "${arts[@]}" | jq -R . | jq -s .)"
  jq -n --arg c "$commit" --argjson d "$dirty" --arg t "$ts" --argjson a "$artjson" \
    '{sourceCommit: $c, dirty: $d, installedAt: $t, artifacts: $a}' > "$MANIFEST"
  echo "→ manifest stamped: $commit$([ "$dirty" = true ] && echo ' (dirty)') @ $ts"
}

do_install() {
  mkdir -p "$DEST/skills" "$DEST/hooks"

  # OPS-3: make the hard-overwrite observable. If a prior deployment + manifest exist, show
  # what currently diverges (and warn about hand-edits that this overwrite will destroy) first.
  if [ -f "$MANIFEST" ]; then
    echo "→ pre-overwrite check (what's about to be clobbered):"
    scan 0
    if [ "$HANDEDIT_COUNT" -gt 0 ]; then
      echo "  ⚠ $HANDEDIT_COUNT hand-edited artifact(s) above will be OVERWRITTEN — local changes lost."
    elif [ "$DRIFT_COUNT" -eq 0 ]; then
      echo "  (deployment already in sync — nothing to clobber)"
    fi
    echo
  fi

  echo "→ deploying ${#ARTIFACTS[@]} artifacts (hard-overwrite)"
  local entry srcrel destpath
  for entry in "${ARTIFACTS[@]}"; do
    srcrel="${entry%%::*}"; destpath="${entry##*::}"
    mkdir -p "$(dirname "$DEST/$destpath")"
    rm -rf "${DEST:?}/$destpath"
    cp -R "$SRC/$srcrel" "$DEST/$destpath"
  done
  chmod +x "$DEST/hooks/block-main-writes.sh"

  echo "→ wiring guard hook into $DEST/settings.json (merge, idempotent)"
  local HOOK_CMD="$DEST/hooks/block-main-writes.sh" tmp
  [ -f "$DEST/settings.json" ] || echo '{}' > "$DEST/settings.json"
  # Back up once per run, then merge the hook entry only if absent.
  cp "$DEST/settings.json" "$DEST/settings.json.bak"
  tmp="$(mktemp)"
  jq --arg cmd "$HOOK_CMD" '
    .hooks //= {} | .hooks.PreToolUse //= [] |
    if any(.hooks.PreToolUse[]?; (.matcher == "Bash") and any(.hooks[]?; .command == $cmd))
    then .
    else .hooks.PreToolUse += [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": $cmd }] }]
    end
  ' "$DEST/settings.json" > "$tmp" && mv "$tmp" "$DEST/settings.json"

  write_manifest

  echo
  echo "✓ Installed to $DEST (backup: settings.json.bak)."
  echo "  Verify any time with: ./install.sh --check"
  echo "  In each app: run /frame once — it bootstraps .claude/workflow.json + AGENTS.md for that repo."
}

case "${1:-}" in
  --check) do_check ;;
  "")      do_install ;;
  *)       echo "usage: $0 [--check]" >&2; exit 2 ;;
esac
