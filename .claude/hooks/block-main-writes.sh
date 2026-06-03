#!/usr/bin/env bash
# Workflow guard (the one load-bearing hook).
# Keeps the feature-branch + merge discipline by blocking, at the tool-call layer:
#   - git commit / git push on the base branch (main/master)
#   - --no-verify on any git command
#   - force-push
# Wired as a PreToolUse hook on the Bash tool. Exit 2 => block; reason on stderr.
# Bypassing requires editing this file or settings.json — diff-visible by design.
set -uo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | /usr/bin/env python3 -c 'import sys, json
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    pass' 2>/dev/null)

[ -z "${cmd:-}" ] && exit 0
case "$cmd" in *git*) : ;; *) exit 0 ;; esac

# Defer to a repo's native workflow if present: a repo containing the heavy v3
# protocol marker (docs/ai-protocol.md) has its own, stricter hooks. Stand down
# (exit 0) so we don't double-fire. Safe outside a git repo (root stays empty).
root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -n "$root" ] && [ -f "$root/docs/ai-protocol.md" ] && exit 0

deny() { echo "BLOCKED by workflow guard: $1" >&2; exit 2; }

# Never bypass verification.
printf '%s' "$cmd" | grep -Eq -- '--no-verify' \
  && deny "remove --no-verify — commit/push hooks must run."

# Never force-push.
if printf '%s' "$cmd" | grep -Eq -- 'git[[:space:]]+push'; then
  printf '%s' "$cmd" | grep -Eq -- '(--force-with-lease|--force([[:space:]]|=|$)|[[:space:]]-f([[:space:]]|$))' \
    && deny "no force-push."
fi

# symbolic-ref resolves the branch even on an unborn branch (no commits yet),
# where rev-parse --abbrev-ref would return the literal "HEAD".
branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null \
  || git rev-parse --abbrev-ref HEAD 2>/dev/null \
  || echo "")
case "$branch" in
  main|master)
    printf '%s' "$cmd" | grep -Eq -- 'git[[:space:]]+commit' \
      && deny "don't commit on '$branch' — work on a feature branch; the merge is the only path in."
    printf '%s' "$cmd" | grep -Eq -- 'git[[:space:]]+push' \
      && deny "don't push to '$branch' — open a PR / merge a feature branch instead."
    ;;
esac
exit 0
