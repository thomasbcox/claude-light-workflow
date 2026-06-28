#!/usr/bin/env bash
# Gate test for the pluggable-reviewer seam (reviews/pluggable-reviewer.md).
# The seam lives in the Markdown skills + workflow.json, not in deployed code, so
# the gate asserts OBSERVABLE fixtures: the config field, the documented resolution
# rule, the /review override, the agy loud-stop, the neutral role language, and the
# byte-preserved codex command envelope. (Codex design finding 1: prove the rule via
# fixtures, not a test-only resolver unit.)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW="$ROOT/.claude/skills/review/SKILL.md"
FRAME="$ROOT/.claude/skills/frame/SKILL.md"
AGENTS="$ROOT/AGENTS.md"
WF="$ROOT/.claude/workflow.json"

pass=0 fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; }

# has <label> <file> <literal-substring>     — passes if present
has()  { grep -qF -- "$3" "$2" && ok "$1" || bad "$1 (missing: $3)"; }
# absent <label> <file> <literal-substring>  — passes if NOT present
absent() { grep -qF -- "$3" "$2" && bad "$1 (should be gone: $3)" || ok "$1"; }

echo "== AC1: config carries a valid reviewer; missing⇒codex is documented =="
# workflow.json reviewer must be one of {codex, agy}
rv=$(/usr/bin/env python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("reviewer",""))' "$WF" 2>/dev/null)
case "$rv" in codex|agy) ok "workflow.json reviewer is '$rv' (valid)";; *) bad "workflow.json reviewer invalid/absent: '$rv'";; esac
has "resolution rule documents missing⇒codex" "$REVIEW" "A missing or empty \`reviewer\` field ⇒ \`codex\`"
has "resolution rule validates the value set"  "$REVIEW" "one of \`{codex, agy}\`"
has "precedence: override beats config beats default" "$REVIEW" "**beats** \`reviewer\` in"

echo "== AC2: /review reviewer override, order-independent, composes with the pass arg =="
has "override token documented"      "$REVIEW" "Reviewer override (bare arg, order-independent)"
has "composition example present"    "$REVIEW" "/review approach agy"
has "invalid token is an error"      "$REVIEW" "is an error — report it and stop"

echo "== AC5: agy is recognized but stops loudly — no fallback, no artifact =="
has "agy loud-stop message"          "$REVIEW" "selected but not wired yet"
has "no codex fallback / no artifact" "$REVIEW" "Do **not** fall back to codex"
has "frame routes agy to the stop"   "$FRAME"  "if it is \`agy\`, STOP per that section"

echo "== AC4: codex command envelope preserved (flags / schema split / model / dev-null) =="
has "approach: codex exec read-only" "$REVIEW" "codex exec -s read-only"
has "approach schema abs path"       "$REVIEW" '--output-schema "$HOME/.claude/skills/review/design-review-schema.json"'
has "correctness schema abs path"    "$REVIEW" '--output-schema "$HOME/.claude/skills/review/finding-schema.json"'
has "approach -o repo-relative"      "$REVIEW" "-o reviews/<slug>.approach.json"
has "correctness -o repo-relative"   "$REVIEW" "-o reviews/<slug>.codex.json"
has "codexModel passthrough"         "$REVIEW" '${codexModel:+-m "$codexModel"}'
has "stdin guard </dev/null"         "$REVIEW" "</dev/null"
has "frame design -o repo-relative"  "$FRAME"  "-o reviews/<slug>.design.json"
has "frame design schema abs path"   "$FRAME"  '--output-schema "$HOME/.claude/skills/review/design-review-schema.json"'

echo "== AC6: reviewer role language is tool-neutral in prompts + contract =="
has "approach prompt neutral"        "$REVIEW" "You are the independent reviewer doing an APPROACH review"
has "correctness prompt neutral"     "$REVIEW" "You are the independent reviewer defined in AGENTS.md"
has "design prompt neutral"          "$FRAME"  "You are the independent reviewer doing a DESIGN review"
absent "no 'You are Codex' in review"  "$REVIEW" "You are Codex"
absent "no 'You are Codex' in frame"   "$FRAME"  "You are Codex"
has "AGENTS.md neutral title"        "$AGENTS" "independent reviewer contract"
absent "AGENTS.md drops 'You are Codex'" "$AGENTS" "You are **Codex**"

echo "== frame bootstrap writes the reviewer field for new repos =="
has "bootstrap seeds reviewer=codex" "$FRAME" '"reviewer": "codex"'

echo
echo "passed=$pass failed=$fail"
[ "$fail" = 0 ] || exit 1
echo "ALL REVIEWER TESTS PASSED"
