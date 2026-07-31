#!/usr/bin/env bash
# ── Behavioral test suite for deep-audit-lib.sh ──
# Unlike the drift linters (which pin PROSE presence), this is a REAL behavioral
# gate. It drives the library as a BLACK BOX (subprocess), so the contract is
# language-independent — these same assertions validated the bash->Python port.
# gate: it builds fixtures + tampered inputs, invokes the library, and asserts exit
# status / output. Tampered-input REJECTION is the acceptance signal — the thing
# prose-presence checks structurally cannot verify. This is the net the deep-audit
# review loop lacked (the story: claims-without-enforcement).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/.claude/skills/deep_audit_lib.py"

pass=0 fail=0
ok() {
  pass=$((pass + 1))
  printf '  ok   %s\n' "$1"
}
bad() {
  fail=$((fail + 1))
  printf 'FAIL  %s\n' "$1"
}
# assert_exit <desc> <expected-code> <cmd…>
assert_exit() {
  local desc="$1" want="$2"
  shift 2
  local got=0
  "$@" >/dev/null 2>&1 || got=$?
  [ "$got" = "$want" ] && ok "$desc" || bad "$desc (exit $got, want $want)"
}
# assert_eq <desc> <got> <want>
assert_eq() {
  [ "$2" = "$3" ] && ok "$1" || bad "$1 (got '$2', want '$3')"
}

# Build a throwaway git repo fixture; echo its path.
make_fixture_repo() {
  local d
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  printf '#!/bin/sh\necho hi\n' >"$d/run.sh"
  chmod +x "$d/run.sh"
  printf 'body\n' >"$d/a.txt"
  mkdir -p "$d/reviews"
  printf 'note\n' >"$d/reviews/x.md"
  git -C "$d" add -A
  git -C "$d" commit -qm init
  echo "$d"
}

echo "== AC1: dispatch =="
assert_exit "unknown subcommand → nonzero" 2 python3 "$LIB" bogus
assert_exit "no subcommand → nonzero" 2 python3 "$LIB"

echo "== AC2: fingerprint =="
FX="$(make_fixture_repo)"
fp() { python3 "$LIB" fingerprint "$FX"; }
A="$(fp)"
B="$(fp)"
[ -n "$A" ] && ok "emits a digest" || bad "digest empty"
assert_eq "deterministic" "$A" "$B"
printf 'more\n' >>"$FX/a.txt"
C="$(fp)"
git -C "$FX" checkout -- a.txt
[ "$A" != "$C" ] && ok "content edit changes digest" || bad "content edit missed"
chmod -x "$FX/run.sh"
D="$(fp)"
chmod +x "$FX/run.sh"
[ "$A" != "$D" ] && ok "exec-bit flip changes digest" || bad "exec-bit flip missed (fail-open)"
printf 'changed\n' >>"$FX/reviews/x.md"
E="$(fp)"
git -C "$FX" checkout -- reviews/x.md
assert_eq "reviews/ change is ignored" "$A" "$E"
NONREPO="$(mktemp -d)"
assert_exit "fingerprint on a non-repo → nonzero" 2 python3 "$LIB" fingerprint "$NONREPO"
rm -rf "$FX" "$NONREPO"

echo "== AC3: resolve-units =="
assert_eq "standard = full ordered" "$(python3 "$LIB" resolve-units standard a b c d)" "$(printf 'a\nb\nc\nd')"
assert_eq "deep = full ordered" "$(python3 "$LIB" resolve-units deep a b c d)" "$(printf 'a\nb\nc\nd')"
assert_eq "light = every-3rd (0,3,6)" "$(python3 "$LIB" resolve-units light a b c d e f g)" "$(printf 'a\nd\ng')"
assert_eq "light single unit" "$(python3 "$LIB" resolve-units light a)" "a"
assert_exit "unknown depth → nonzero" 2 python3 "$LIB" resolve-units bogus a b
assert_eq "empty input → empty output" "$(python3 "$LIB" resolve-units standard)" ""

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL DEEP-AUDIT-LIB BEHAVIORAL TESTS PASSED"
