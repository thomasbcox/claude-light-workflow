#!/usr/bin/env bash
# Gate entry point for the fireworks reviewer backend's behavioral suite.
#
# The suite itself is Python (tests/fireworks_runner_test.py) because its target
# is Python. This wrapper exists so the gate stays a list of *.sh, and so a
# missing runtime fails LOUDLY with the fix rather than skipping quietly — a
# silently-skipped test that reports pass is the exact hidden-failure pattern
# this repo's second review critic exists to catch.
set -uo pipefail

VENV="$HOME/.claude/fireworks-venv/bin/python"
SUITE="$(cd "$(dirname "$0")" && pwd)/fireworks_runner_test.py"

if [ ! -x "$VENV" ]; then
  cat >&2 <<EOF
FAIL  fireworks runner suite cannot run: no interpreter at $VENV

  The runner's dependencies are declared in .claude/skills/review/requirements.txt.
  Bootstrap them once (user-local, no admin required):

    python3 -m venv ~/.claude/fireworks-venv
    ~/.claude/fireworks-venv/bin/pip install -r .claude/skills/review/requirements.txt

  This is a hard failure, not a skip: the suite carries the only real oracles for
  the fireworks backend's fail-closed behaviour.
EOF
  exit 1
fi

# -B for the same reason the skill's invocation carries it: bytecode written into
# .claude/skills/review would be deployed by install.sh and then read as drift.
exec "$VENV" -B "$SUITE"
