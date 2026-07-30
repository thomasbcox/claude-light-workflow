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

echo "== every deployed skill (install.sh ARTIFACTS) is documented as a /command in README + ARCHITECTURE =="
# Extract skill names ONLY from inside the ARTIFACTS=( … ) block (not the whole file), and only from
# quoted skill-DIRECTORY records ".claude/skills/<name>::…" — so a name in a comment/example elsewhere
# can't create a phantom skill (AP-2), and the standalone deep-audit-lib.sh library (a ".sh" entry,
# not a command) is excluded.
artifacts="$(sed -n '/^ARTIFACTS=(/,/^)/p' "$INSTALL")"
skills="$(printf '%s\n' "$artifacts" | grep -oE '"\.claude/skills/[a-z0-9-]+::' | sed -E 's#"\.claude/skills/([a-z0-9-]+)::#\1#' | sort -u)"
[ -n "$skills" ] && ok "parsed deployed skills from the ARTIFACTS block" || bad "no skills parsed from the ARTIFACTS block"

# Require the structural COMMAND token /<name> — delimited on BOTH sides by a non-path, non-name char
# (AP-2, CR-3). The symmetric boundary [^[:alnum:]/._-] rejects incidental prose ("close"), path
# segments (skills/deep-audit/, /frame/SKILL.md), and filenames (/deep-audit.md) — only a real
# /command reference passes.
doc_has_cmd() { grep -qE "(^|[^[:alnum:]/._-])/$1([^[:alnum:]/._-]|\$)" "$2"; }
checked=0
while IFS= read -r s; do
  [ -n "$s" ] || continue
  doc_has_cmd "$s" "$README" && ok "README documents /$s" || bad "README missing deployed command: /$s"
  doc_has_cmd "$s" "$ARCH" && ok "ARCHITECTURE documents /$s" || bad "ARCHITECTURE missing deployed command: /$s"
  checked=$((checked + 1))
done < <(printf '%s\n' "$skills")
# Fail CLOSED (CR-2): the loop MUST have run for every parsed skill. A here-string / process-sub
# failure that silently skipped enumeration would otherwise leave the core invariant unenforced while
# still exiting 0. Assert the count instead of trusting the loop ran.
n="$(printf '%s\n' "$skills" | grep -c .)"
{ [ "$n" -gt 0 ] && [ "$checked" -eq "$n" ]; } && ok "enumerated + checked all $n deployed skills" || bad "skill enumeration did not run (checked=$checked of $n) — fail-closed"

echo "== ROADMAP.md exists =="
[ -f "$ROADMAP" ] && ok "ROADMAP.md present" || bad "ROADMAP.md missing"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL DOCS-CONSISTENCY CHECKS PASSED (drift only — deployed skills must be documented)"
