#!/usr/bin/env python3
"""Structural check: the shared contract deploys to exactly the path the runner reads.

Derived from both authoritative sources rather than a retyped filename — install.sh's
ARTIFACTS block for what gets deployed, and the runner's own CONTRACT_PATH for what gets
read. A retyped name would let the two drift apart while this check kept passing, which is
the failure it exists to prevent: the file installed would not be the file used.
"""
import importlib.util
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
block = re.search(r"ARTIFACTS=\((.*?)\n\)", (root / "install.sh").read_text(), re.S).group(1)
dests = [ln.split("::")[1].strip().strip('"') for ln in block.splitlines() if "::" in ln]

spec = importlib.util.spec_from_file_location(
    "r", root / ".claude/skills/review/fireworks_runner.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

print(
    "deployed" if mod.CONTRACT_PATH.name in dests else "MISSING",
    "no-agents-md" if not any(d.rsplit("/", 1)[-1] == "AGENTS.md" for d in dests) else "AGENTS-DEPLOYED",
    "repo-file-absent" if not (root / "AGENTS.md").exists() else "REPO-FILE-PRESENT",
)
