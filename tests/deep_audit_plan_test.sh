#!/usr/bin/env bash
# ── Documentation-consistency linter for the /deep-audit plan stage ──
# THIS IS A LINTER, NOT A BEHAVIORAL GATE (same charter as reviewer_test.sh /
# dev_audit_test.sh). The skill is Markdown instructions with no runtime oracle;
# these checks catch wording/typo drift in the phrases the OPS-13 first slice
# depends on (determinism table, canonical-JSON rule, loud engine stop). Do not
# grow this into a pseudo-behavioral suite.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/.claude/skills/deep-audit/SKILL.md"
SCHEMA="$ROOT/.claude/skills/deep-audit/plan-schema.json"
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

echo "== skill exists with frontmatter name =="
grep -q '^name: deep-audit$' "$SKILL" && ok "frontmatter name=deep-audit" || bad "frontmatter name"

echo "== stand-down + posture (inherited from /dev-audit) =="
has "step-0 stand-down" "$SKILL" "docs/ai-protocol.md"
has "read-only against the target" "$SKILL" "Read-only against the target"
has "backlog only on explicit instruction" "$SKILL" "only on explicit"
has "secret redaction restated" "$SKILL" "never a value"

echo "== detection is by reference, not duplicated =="
has "references /dev-audit steps 1-2" "$SKILL" "\`/dev-audit\` steps 1–2"
absent "no duplicated Table A ecosystem row" "$SKILL" '| JS/TS — `package.json` |'

echo "== altitude ladder + lens catalog v1 =="
has "L0 reserved" "$SKILL" "L0 — lines"
has "L1 units" "$SKILL" "L1 — units"
has "L2 subsystems" "$SKILL" "L2 — subsystems"
has "L3 application" "$SKILL" "L3 — application"
has "Table L present" "$SKILL" "## Table L — lens catalog v1"
has "lens: hidden-failure" "$SKILL" '`hidden-failure`'
has "lens: security-data-loss" "$SKILL" '`security-data-loss`'
has "lens: test-adequacy" "$SKILL" '`test-adequacy`'
has "lens: architecture-coherence" "$SKILL" '`architecture-coherence`'
has "OPS-12 per-critic rule restated" "$SKILL" "its own schema"
has "prompts/schemas deferred to engine story" "$SKILL" "engine story's scope"
has "approach pass owns simplicity (OPS-12 boundary)" "$SKILL" "approach pass owns it"

echo "== Table P determinism (the F1 BLOCKER fix; phased per the approach-round redesign) =="
has "Table P present (phased)" "$SKILL" "Table P (phased, deterministic)"
has "three declared phases" "$SKILL" "three declared phases"
has "Phase C is the declared extension point" "$SKILL" "Phase C — named post-resolution transforms (declared order): _none in v1_"
absent "no rule reads the unavailable dev-audit tier" "$SKILL" "Table B tier = \`mature\`"
has "transforms run after resolution" "$SKILL" "running **after** resolution"
has "downgrade cannot be a Phase-B upgrade (why the phase exists)" "$SKILL" "can never resolve downward"
has "row identity pinned" "$SKILL" '`(lens, altitude, scope)`'
has "churn window derives from the stored cutoff" "$SKILL" "90 days ending at \`evaluatedAt\`"
has "churn threshold" "$SKILL" "≥ 20 commits"
has "snapshot pinned at compile start" "$SKILL" "Pin the snapshot first"
has "clean-tree evaluatedAt from bound revision" "$SKILL" "the bound revision's committer timestamp"
has "plan replayable from recorded inputs" "$SKILL" "reproducibility comes from the source"
has "engine owns the verification policy (this story records only)" "$SKILL" "it does not define the check"
has "schema requires the source block" "$SCHEMA" '"required": ["revision", "dirty", "evaluatedAt"]'
has "chunk threshold" "$SKILL" "400 LOC"
has "root files form the (root) group" "$SKILL" '`(root)`'
has "non-code groups emit no L1/L2 rows" "$SKILL" "non-code"
has "collision rule: highest depth wins" "$SKILL" "highest** depth wins"
has "whys accumulate" "$SKILL" "accumulates on the row"
has "determinism invariant stated" "$SKILL" "same overrides ⇒ same plan"

echo "== told patch model (the approach-round F2 redesign) =="
has "patch model named" "$SKILL" "patch model"
has "lens off token" "$SKILL" "<lens>:off"
has "set-or-add semantics" "$SKILL" "set-or-add"
has "Table L expansion for absent rows" "$SKILL" "Table L expansion"
has "restrict op (only=)" "$SKILL" "restrict"
has "consult edits use same patch shape" "$SKILL" "source: consult"
has "replayable from repo state + patches" "$SKILL" "replayable"
has "exclude glob token" "$SKILL" "exclude=<glob>"
has "unknown token is an error" "$SKILL" "unknown token is an error"

echo "== per-row pricing (the F3 fix) =="
has "depth factors stated" "$SKILL" "deep \`2×units\`"
has "per-run token assumption" "$SKILL" "60k"
has "omission risk per row" "$SKILL" "omissionRisk"
has "concurrency-batched wall-clock" "$SKILL" "totalRuns / 8"

echo "== canonical JSON contract + semantic check (the F3 redesign) =="
has "JSON is canonical" "$SKILL" "JSON is canonical"
has "artifact path token" "$SKILL" "reviews/audit-plan-"
has "stamped artifact identity (collision-proof)" "$SKILL" "reviews/audit-plan-<YYYY-MM-DD>T<HHMMSS>.json"
has "one stamp per invocation" "$SKILL" "one stamp per invocation"
has "never overwrites an approved plan" "$SKILL" "can never overwrite an earlier"
has "consult edits do not re-mint the stamp" "$SKILL" "never minting a new stamp"
has "schema requires compiledAt" "$SCHEMA" '"compiledAt"'
has "parse-check before use" "$SKILL" "Parse-check"
has "plan semantic check named" "$SKILL" "plan semantic check"
has "uniqueness invariant" "$SKILL" "are **unique**"
has "totals arithmetic invariant" "$SKILL" "totals.runs = Σ rows"
has "view derived from JSON" "$SKILL" "derive"
grep -q '"planVersion": { "const": 1 }' "$SCHEMA" && ok "schema pins planVersion=1" || bad "schema planVersion const"
/usr/bin/env python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$SCHEMA" 2>/dev/null && ok "plan-schema.json is valid JSON" || bad "plan-schema.json invalid"
# (row required-fields pin lives below with unitIds — the round-2 contract)
has "schema pins per-lens altitudes (oneOf)" "$SCHEMA" '"oneOf"'
has "schema: hidden-failure only L1" "$SCHEMA" '{ "properties": { "lens": { "const": "hidden-failure" }, "altitude": { "const": "L1" } } }'
has "schema: discriminated union — set-depth requires depth" "$SCHEMA" '"required": ["token", "selector", "op", "depth", "source"]'
has "schema: set-depth op const" "$SCHEMA" '"const": "set-depth"'
has "schema: add carries complete rowIntent" "$SCHEMA" '"rowIntent"'
has "schema: remove/restrict selector-only branch" "$SCHEMA" '"enum": ["remove", "restrict"]'
has "schema: rows pin unitIds" "$SCHEMA" '"required": ["lens", "altitude", "scope", "depth", "units", "unitIds", "runs", "estTokens", "omissionRisk", "why"]'
has "schema: unitMap pins unitIds" "$SCHEMA" '"required": ["group", "files", "loc", "chunkUnits", "unitIds", "signals"]'
has "skill: rows record resolved unit IDs" "$SKILL" "ordered \`unitIds\` list"
has "skill: pinned every-3rd light sample" "$SKILL" "every 3rd entry"
has "skill: globs act before unit-map compilation" "$SKILL" "before unit-map compilation"
has "skill: semantic check covers unit identity" "$SKILL" 'chunkUnits = |unitIds|'

echo "== consult stop + loud engine stop =="
has "consult-presentation rule invoked" "$SKILL" "consult-presentation rule"
has "approval approves the plan, not execution" "$SKILL" "not execution"
has "loud engine stop" "$SKILL" "execution engine is not yet built"

echo "== deploy + gate wiring =="
has "install.sh ships the skill" "$INSTALL" ".claude/skills/deep-audit::skills/deep-audit"
has "workflow.json testCommand runs this linter" "$WF" "deep_audit_plan_test.sh"
has "ci gate runs this linter" "$CI" "deep_audit_plan_test.sh"

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL DEEP-AUDIT-PLAN LINT CHECKS PASSED (drift only — not a behavioral gate)"
