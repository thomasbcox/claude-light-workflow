#!/usr/bin/env bash
# ── Documentation-consistency linter for the /deep-audit-run engine (OPS-13 slice 1) ──
# THIS IS A LINTER, NOT A BEHAVIORAL GATE (same charter as reviewer_test.sh /
# dev_audit_test.sh / deep_audit_plan_test.sh). The skill is Markdown instructions
# with no runtime oracle; these checks catch wording/typo drift in the phrases the
# engine slice depends on (the entry gates, the run manifest, the claim-blind verify
# contract, the execution ledger, failure-vs-omission). Do not grow this into a
# pseudo-behavioral suite. Per OPS-17: each rule is pinned ONCE here; schema
# descriptions must REFERENCE the skill, not restate the rule.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/.claude/skills/deep-audit-run/SKILL.md"
FSCHEMA="$ROOT/.claude/skills/deep-audit-run/hidden-failure-unit-schema.json"
ESCHEMA="$ROOT/.claude/skills/deep-audit-run/evidence-schema.json"
RSCHEMA="$ROOT/.claude/skills/deep-audit-run/audit-report-schema.json"
PLANSKILL="$ROOT/.claude/skills/deep-audit/SKILL.md"
INSTALL="$ROOT/install.sh"
WF="$ROOT/.claude/workflow.json"
CI="$ROOT/.github/workflows/ci.yml"

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
absent() { grep -qF -- "$3" "$2" && bad "$1 (should be gone: $3)" || ok "$1"; }
valid_json() { /usr/bin/env python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$2" 2>/dev/null && ok "$1" || bad "$1 (invalid JSON)"; }

echo "== skill exists with frontmatter name =="
grep -q '^name: deep-audit-run$' "$SKILL" && ok "frontmatter name=deep-audit-run" || bad "frontmatter name"

echo "== AC1: approval guard + stand-down =="
has "step-0 stand-down" "$SKILL" "docs/ai-protocol.md"
has "executes only an approved plan" "$SKILL" "Executes only an APPROVED plan"
has "unapproved plan stops unexecuted" "$SKILL" "unexecuted"
has "no run-it-anyway" "$SKILL" "run it anyway"

echo "== posture (inherited from /dev-audit) =="
has "read-only against the target" "$SKILL" "Read-only against the target"
has "secret redaction: never a value" "$SKILL" "never a value"
has "report-first posture" "$SKILL" "report-first"
has "JSON is canonical" "$SKILL" "JSON is canonical"

echo "== AC2: source-identity gate (deferred AC c) =="
has "source-identity gate present" "$SKILL" "Source-identity gate"
has "refuse a dirty-tree plan" "$SKILL" "Refuse a dirty-tree plan"
has "dirty plan not reproducibly verifiable" "$SKILL" "not reproducibly verifiable"
has "fingerprint excludes generated review artifacts" "$SKILL" "excluding generated plan/review artifacts"
has "excluding reviews stops self-invalidation" "$SKILL" "self-invalidating"
has "fingerprint over non-reviews tracked files" "$SKILL" "non-reviews"
has "fail closed on source mismatch" "$SKILL" "STOP loudly"

echo "== AC3: executability gate (deferred AC b) =="
has "executability gate present" "$SKILL" "Executability gate"
has "re-runs the plan semantic check" "$SKILL" "plan semantic check"
has "scope registry" "$SKILL" "scope registry"
has "per-row run arithmetic" "$SKILL" "runs = |unitIds|"

echo "== AC4: run manifest -> fleet (DR-3) =="
has "run manifest section" "$SKILL" "Run manifest"
has "DR-3 cited" "$SKILL" "DR-3"
has "depth lives in runs not unitIds" "$SKILL" "Depth lives in"
has "iterating unitIds would launch half" "$SKILL" "half"
has "deep => two passes" "$SKILL" "1..(deep ? 2 : 1)"
has "validate manifest before spawning" "$SKILL" "Validate the manifest before spawning"
has "manifest total = in-scope rows' runs" "$SKILL" "in-scope rows"
has "orchestrate on the Workflow engine" "$SKILL" "author a Workflow"
has "finder owns its schema (OPS-12)" "$SKILL" "OPS-12"
has "finder schema referenced" "$SKILL" "hidden-failure-unit-schema.json"
has "fail-closed: fresh temp" "$SKILL" "fresh temp"
has "promote only on clean exit AND valid JSON" "$SKILL" "clean exit AND valid"
has "deep passes de-duplicated" "$SKILL" "de-duplicate by"

echo "== AC5: adversarial verify — evidence record + adjudication (DR-1) =="
has "adversarial verify section" "$SKILL" "Adversarial verify"
has "claim-blind cross-model verifier" "$SKILL" "Claim-blind, cross-model verifier"
has "verifier is a different model from the finder" "$SKILL" "different model from the"
has "verifier never sees the finder's claim" "$SKILL" "lens charter but NEVER"
has "structured evidence record" "$SKILL" "structured evidence record"
has "evidence schema referenced" "$SKILL" "evidence-schema.json"
has "mechanical confirmation first" "$SKILL" "confirmation first"
has "deterministic adjudication" "$SKILL" "Deterministic adjudication"
has "promote/refute decision table" "$SKILL" "promote/refute decision"
has "default refuted on uncertainty" "$SKILL" "default REFUTED"
has "promoted only if adjudication confirms" "$SKILL" "only if adjudication promotes"
has "verify contract is not a per-lens choice" "$SKILL" "claim-blind verification is a contract"

echo "== AC6: synthesis off the execution ledger (DR-2) =="
has "execution ledger" "$SKILL" "execution ledger"
has "per-row ledger" "$SKILL" "per-row execution ledger"
has "omitted = out of this engine slice" "$SKILL" "out of this engine slice"
has "failed is never persisted" "$SKILL" "never persisted"
has "written report is always complete" "$SKILL" "always complete"
has "report artifact path token" "$SKILL" "reviews/audit-report-"
has "no-overwrite collision guard" "$SKILL" "collision guard"
has "coverage derived from ledger, not yield" "$SKILL" "never from finding yield"
has "executed-zero-survivors is covered" "$SKILL" "zero survivors"
has "report schema referenced" "$SKILL" "audit-report-schema.json"

echo "== AC7: failure != planned omission =="
has "failure vs planned omission invariant" "$SKILL" "failure ≠ planned omission"
has "failure writes no report" "$SKILL" "writes no report"
has "partial sweep never presented as whole" "$SKILL" "partial sweep"

echo "== AC8: contract handling =="
has "contract handling section" "$SKILL" "Contract handling"
has "consumes plan-schema v1 unchanged" "$SKILL" "v1 unchanged"
has "C-ledger fields stubbed" "$SKILL" "C-ledger"

echo "== finder schema (hidden-failure at unit scope) =="
valid_json "hidden-failure-unit-schema.json valid" "$FSCHEMA"
has "finder: whole-unit not diff" "$FSCHEMA" "not a diff"
has "finder: additionalProperties false" "$FSCHEMA" '"additionalProperties": false'
has "finder: OPS-17 references SKILL, not restates" "$FSCHEMA" "defined in SKILL.md"

echo "== evidence schema (claim-blind verifier) =="
valid_json "evidence-schema.json valid" "$ESCHEMA"
has "evidence: verifier is claim-blind" "$ESCHEMA" "CLAIM-BLIND"
has "evidence: never the finder's claim" "$ESCHEMA" "NEVER the finder's claim"
has "evidence: errorHandling enum incl swallowed" "$ESCHEMA" '"swallowed"'
has "evidence: uncertainty drives refuted default" "$ESCHEMA" "defaults to REFUTED"
has "evidence: additionalProperties false" "$ESCHEMA" '"additionalProperties": false'
has "evidence: OPS-17 references SKILL, not restates" "$ESCHEMA" "not restated here"

echo "== report schema (execution ledger + verified-only + C-ledger stub) =="
valid_json "audit-report-schema.json valid" "$RSCHEMA"
grep -q '"reportVersion": { "const": 1 }' "$RSCHEMA" && ok "report: pins reportVersion=1" || bad "report: reportVersion const"
has "report: verified-only precision-first" "$RSCHEMA" "Verified-only"
has "report: ledger state enum" "$RSCHEMA" '"enum": ["executed", "omitted"]'
has "report: executed-zero is a negative result not a gap" "$RSCHEMA" "not a gap"
has "report: coverage derived from ledger" "$RSCHEMA" "never off finding yield"
has "report: C-ledger disposition stub" "$RSCHEMA" "C-ledger stub"
has "report: priorReportRef stub" "$RSCHEMA" '"priorReportRef"'
has "report: written only on completed run" "$RSCHEMA" '"const": "complete"'
has "report: additionalProperties false" "$RSCHEMA" '"additionalProperties": false'

echo "== /deep-audit hands off to the engine (no stale 'not built') =="
has "plan skill points at /deep-audit-run" "$PLANSKILL" "/deep-audit-run"
absent "plan skill no longer claims engine unbuilt" "$PLANSKILL" "execution engine is not yet built"

echo "== deploy + gate wiring =="
has "install.sh ships the skill" "$INSTALL" ".claude/skills/deep-audit-run::skills/deep-audit-run"
has "workflow.json testCommand runs this linter" "$WF" "deep_audit_engine_test.sh"
has "ci gate runs this linter" "$CI" "deep_audit_engine_test.sh"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL DEEP-AUDIT-ENGINE LINT CHECKS PASSED (drift only — not a behavioral gate)"
