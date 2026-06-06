#!/usr/bin/env bash
# Gate test for the workflow guard (.claude/hooks/block-main-writes.sh).
# Feeds JSON payloads matching the PreToolUse stdin contract and asserts the
# hook's exit code: 2 = blocked, 0 = allowed.
# Covers the bypass forms (AC5/AC6) and the false-positive class (AC7).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/.claude/hooks/block-main-writes.sh"
[ -x "$HOOK" ] || { echo "hook not executable: $HOOK"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkrepo() {  # mkrepo <name> <branch> [native]
  local d="$TMP/$1"
  git init -q "$d"
  git -C "$d" symbolic-ref HEAD "refs/heads/$2"
  [ "${3:-}" = "native" ] && { mkdir -p "$d/docs"; : > "$d/docs/ai-protocol.md"; }
  echo "$d"
}

BASE="$(mkrepo base_repo main)"
FEAT="$(mkrepo feat_repo feature/x)"
NATIVE="$(mkrepo native_repo main native)"

pass=0 fail=0
# run <expected_exit> <cwd> <command> <label>
run() {
  local want="$1" cwd="$2" command="$3" label="$4"
  local payload; payload=$(printf '%s' "$command" \
    | /usr/bin/env python3 -c 'import json,sys; print(json.dumps({"tool_input":{"command":sys.stdin.read()}}))')
  ( cd "$cwd" && printf '%s' "$payload" | "$HOOK" >/dev/null 2>&1 )
  local got=$?
  if [ "$got" = "$want" ]; then
    pass=$((pass+1)); printf '  ok   [%s] %s\n' "$got" "$label"
  else
    fail=$((fail+1)); printf 'FAIL  want %s got %s — %s\n     cmd: %s\n' "$want" "$got" "$label" "$command"
  fi
}

echo "== AC5: base-branch commit blocked across git option forms =="
run 2 "$BASE" 'git commit -m x'                         "plain commit on main"
run 2 "$FEAT" "git -C $BASE commit -m x"                "git -C <base-repo> commit (from a feature repo)"
run 2 "$BASE" 'git -c user.name=x commit -m x'          "git -c k=v commit on main"
run 2 "$BASE" 'git --no-pager commit -m x'              "global flag before subcommand on main"

echo "== AC6: force-push forms blocked =="
run 2 "$FEAT" 'git push origin +HEAD:main'             "+refspec force from a feature branch"
run 2 "$FEAT" 'git push --force origin main'           "--force"
run 2 "$FEAT" 'git push --force-with-lease'            "--force-with-lease"
run 2 "$FEAT" 'git push -f origin x'                   "-f"
run 2 "$FEAT" 'git push --mirror origin'              "--mirror"
run 2 "$FEAT" "git -C $BASE push +HEAD:main"          "git -C force +refspec"

echo "== --no-verify never allowed =="
run 2 "$FEAT" 'git commit --no-verify -m x'           "--no-verify on a feature branch"

echo "== AC7 / no false-positives: benign commands allowed =="
run 0 "$BASE" "grep 'git push' notes.txt"             "grep mentioning 'git push' (not a git call)"
run 0 "$BASE" 'echo git commit'                       "echo mentioning git commit"
run 0 "$BASE" 'git status'                            "git status on main"
run 0 "$FEAT" 'git commit -m x'                       "commit on a feature branch"
run 0 "$FEAT" 'git push origin HEAD'                  "non-force push from a feature branch"
run 0 "$NATIVE" 'git commit -m x'                     "commit on main in a native-protocol repo (stand down)"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL GUARD TESTS PASSED"
