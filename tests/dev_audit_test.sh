#!/usr/bin/env bash
# ── Documentation-consistency linter for the /dev-audit skill ──
# THIS IS A LINTER, NOT A BEHAVIORAL GATE. Read this before adding to it.
#
# /dev-audit is *instructions Claude follows in a Markdown skill*, not code. There is
# no function to call, no exit code, no oracle — so this file CANNOT verify what an
# audit actually does on a real repo. All it can do is catch wording/structure drift:
# that the load-bearing phrases (the step-0 stand-down, the two declarative tables,
# the core-vs-recommend split, the fixed report sections, the AUDIT-/human-gated
# backlog language, the artifact path) still exist where the skill and its wiring
# expect them.
#
# Real verification lives elsewhere, by design: the independent reviewer's diff review,
# and a human reading SKILL.md. DO NOT grow this into a pseudo-behavioral suite (per-repo
# fixtures, fake scanners, output parsers) — that is theater: machinery and coupling
# without an oracle. If you ever need a REAL gate, extract the detection/classification
# into executable code and unit-test THAT. Keep this drift-only. (Same stance as
# reviewer_test.sh.)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/.claude/skills/dev-audit/SKILL.md"
INSTALL="$ROOT/install.sh"
README="$ROOT/README.md"
BACKLOG="$ROOT/BACKLOG.md"
ARCH="$ROOT/ARCHITECTURE.md"
CLOSE="$ROOT/.claude/skills/close/SKILL.md"
WF="$ROOT/.claude/workflow.json"

pass=0 fail=0
ok() {
  pass=$((pass + 1))
  printf '  ok   %s\n' "$1"
}
bad() {
  fail=$((fail + 1))
  printf 'FAIL  %s\n' "$1"
}
has() { grep -qF -- "$3" "$2" && ok "$1" || bad "$1 (missing: $3)"; }

echo "== skill exists with frontmatter name =="
has "frontmatter name=dev-audit" "$SKILL" "name: dev-audit"

echo "== AC7: step-0 native-workflow stand-down (the ratified BLOCKER fix) =="
has "stand-down step present" "$SKILL" "Stand-down (run before anything else)"
has "honors docs/ai-protocol.md" "$SKILL" "docs/ai-protocol.md"
has "read-only / installs nothing" "$SKILL" "Install no tools"

echo "== AC1/AC5: detection signals are enumerated =="
has "detects CI config" "$SKILL" "CI config"
has "detects secret patterns" "$SKILL" "Secret patterns"
has "detects test setup" "$SKILL" "Test setup"

echo "== AC7: secret-evidence redaction invariant (round-2 BLOCKER fix) =="
has "redaction hard constraint" "$SKILL" "Redact secret evidence (never write a secret value)"
has "never quote/persist value" "$SKILL" "quoted or persisted"
has "backlog items value-free" "$SKILL" "value-free"

echo "== AC2: declarative tool-selection table (ecosystem -> toolset) =="
has "Table A present" "$SKILL" "Table A — ecosystem (detection marker) → toolset"
has "arch review reuses design lens" "$SKILL" "design-review-schema.json"
has "read-only/check-mode column" "$SKILL" "Read-only / check mode"
has "Table A Shell row (OPS-10)" "$SKILL" "Shell — \`*.sh\`"
has "Shell row read-only shfmt -d" "$SKILL" "\`shfmt -d\`"
has "Table A Markdown row" "$SKILL" "Markdown / docs — \`*.md\`"
has "Markdown link-check advisory" "$SKILL" "link check is advisory"

echo "== AC1/AC4: declarative classification matrix (tier+risk+flags in one table) =="
has "Table B classification matrix" "$SKILL" "Table B — classification matrix"
has "matrix roll-up: maturity tier" "$SKILL" "Maturity tier"
has "tier: prototype" "$SKILL" "prototype"
has "tier: developing" "$SKILL" "developing"
has "tier: mature" "$SKILL" "mature"

echo "== AC3/AC7: hybrid split + read-only invocation rule =="
has "command -v gate" "$SKILL" "command -v"
has "recommended (not installed)" "$SKILL" "recommended (not installed)"
has "read-only rule (AC7)" "$SKILL" "Read-only rule (AC7"
has "read-only rule allows dry-run" "$SKILL" "--dry-run"

echo "== AC4: fixed report sections + artifact path =="
has "section: Detected profile" "$SKILL" "Detected profile"
has "section: Tools chosen — why" "$SKILL" "Tools chosen — and why"
has "section: Findings" "$SKILL" "Findings"
has "section: Risk level" "$SKILL" "Risk level"
has "section: Best-practice gaps" "$SKILL" "Best-practice gaps"
has "section: Prioritized next steps" "$SKILL" "Prioritized next steps"
has "artifact path token" "$SKILL" "reviews/audit-<YYYY-MM-DD>.md"

echo "== AC6: report-first + human-gated AUDIT- backlog hand-off =="
has "AUDIT- prefix" "$SKILL" "AUDIT-"
has "only on explicit instruction" "$SKILL" "only on an explicit instruction"

echo "== AC8: deploy + gate + docs wiring =="
has "install.sh ships the skill" "$INSTALL" ".claude/skills/dev-audit::skills/dev-audit"
has "gate runs this linter" "$WF" "tests/dev_audit_test.sh"

echo "== AC8 (amended): system-map docs reflect the skill =="
has "README mentions /dev-audit" "$README" "/dev-audit"
has "README artifact trail: AUDIT-" "$README" "recon findings (\`AUDIT-\`"
has "README audit-report artifact" "$README" "reviews/audit-<YYYY-MM-DD>.md"
has "README stand-down: /dev-audit" "$README" "before it reads or writes anything"
has "BACKLOG documents AUDIT- kind" "$BACKLOG" "AUDIT-"
has "BACKLOG names dev-audit inflow" "$BACKLOG" "dev-audit"
has "ARCHITECTURE maps /dev-audit" "$ARCH" "/dev-audit"
has "ARCHITECTURE: AUDIT- in trail" "$ARCH" "AUDIT-"
has "/close lifecycle covers AUDIT-" "$CLOSE" "AUDIT-"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL DEV-AUDIT LINT CHECKS PASSED (drift only — not a behavioral gate)"
