#!/usr/bin/env bash
# ── Docs-consistency linter ──
# Enforces ONE authoritative, drift-proof invariant: every DEPLOYED skill (parsed from
# install.sh's ARTIFACTS — the deployment source of truth) is documented in README.md AND
# ARCHITECTURE.md. This is exactly the check that would have caught /deep-audit shipping
# undocumented (the trigger for the docs-purpose-roadmap story). Per that story's design
# review (DR-2): NO purpose/roadmap prose pins — those semantics are review-judged, not
# wording-coupled (that coupling is the OPS-17 drift source). This linter only asserts
# structural coverage + the ROADMAP.md's existence.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install.sh"
README="$ROOT/README.md"
ARCH="$ROOT/ARCHITECTURE.md"
ROADMAP="$ROOT/ROADMAP.md"

pass=0 fail=0
ok() {
  pass=$((pass + 1))
  printf '  ok   %s\n' "$1"
}
bad() {
  fail=$((fail + 1))
  printf 'FAIL  %s\n' "$1"
}

echo "== every deployed skill (install.sh ARTIFACTS) is documented in README + ARCHITECTURE =="
# ARTIFACTS entries for skills look like ".claude/skills/<name>::skills/<name>". Match only
# directory-skills (no dot in <name>), so the standalone deep-audit-lib.sh library entry —
# which has no user-facing command to document — is naturally excluded.
skills="$(grep -oE '\.claude/skills/[a-z0-9-]+::' "$INSTALL" | sed -E 's#\.claude/skills/([a-z0-9-]+)::#\1#' | sort -u)"
[ -n "$skills" ] && ok "parsed deployed skills from ARTIFACTS" || bad "no skills parsed from install.sh ARTIFACTS"
while IFS= read -r s; do
  [ -n "$s" ] || continue
  grep -qF "$s" "$README" && ok "README documents /$s" || bad "README missing deployed skill: /$s"
  grep -qF "$s" "$ARCH" && ok "ARCHITECTURE documents /$s" || bad "ARCHITECTURE missing deployed skill: /$s"
done <<<"$skills"

echo "== ROADMAP.md exists =="
[ -f "$ROADMAP" ] && ok "ROADMAP.md present" || bad "ROADMAP.md missing"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL DOCS-CONSISTENCY CHECKS PASSED (drift only — deployed skills must be documented)"
