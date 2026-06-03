#!/usr/bin/env bash
# Promote the lightweight Claude↔Codex workflow from this repo to user scope (~/.claude),
# so every Claude Code app on this machine gets the skills + guard hook.
# Idempotent: re-run any time to update. Never clobbers your existing settings.json.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude"
mkdir -p "$DEST/skills" "$DEST/hooks"

echo "→ skills (frame, review, close)"
for s in frame review close; do
  rm -rf "${DEST:?}/skills/$s"
  cp -R "$SRC/.claude/skills/$s" "$DEST/skills/$s"
done

echo "→ guard hook"
cp "$SRC/.claude/hooks/block-main-writes.sh" "$DEST/hooks/block-main-writes.sh"
chmod +x "$DEST/hooks/block-main-writes.sh"

echo "→ protocol + reviewer-contract template"
cp "$SRC/.claude/workflow-protocol.md" "$DEST/workflow-protocol.md"
cp "$SRC/AGENTS.md" "$DEST/workflow-AGENTS-template.md"

echo "→ wiring guard hook into ~/.claude/settings.json (merge, idempotent)"
HOOK_CMD="$DEST/hooks/block-main-writes.sh"
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

echo
echo "✓ Installed to $DEST (backup: settings.json.bak)."
echo "  In each app: run /frame once — it bootstraps .claude/workflow.json + AGENTS.md for that repo."
