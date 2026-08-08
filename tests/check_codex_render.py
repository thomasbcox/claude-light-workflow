#!/usr/bin/env python3
"""Behavioral check: what the codex backend is HANDED, not what the skill spells.

The property under test is `single-source-rules` AC7 — the codex blocks resolve the
schema's contract markers before invoking, so codex never reviews against raw
`{{contract:...}}` text. A grep for `--render-schema` cannot establish that: it passes
if the render call sits in a comment, runs *after* the invocation, or writes to a path
a later assignment overrides. All three are realistic, and the failure they hide is
silent — a reviewer told nothing about severity or reversibility still returns
confident, schema-valid findings.

So this runs the block for real, with a stub `codex` on PATH that records the file it
was handed via `--output-schema`, and asserts on that file's CONTENT.

Self-contained: it builds a throwaway `$HOME` holding the skills and the contract, the
way `install.sh` deploys them, so it runs identically on a developer machine and in CI
(where no `~/.claude` exists). Prints one line per block and exits non-zero on any
failure.

Usage: check_codex_render.py <repo-root>
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Anchors the rendered schema must actually contain, proving resolution happened
# rather than merely that markers vanished. Derived from the contract at run time,
# not retyped: a hardcoded phrase drifts the moment the contract is reworded.
#
# TWO anchors, not one. With only "Severity labels", the correctness altitude's block
# was checked solely for the ABSENCE of markers: neither schema it renders carries a
# severity marker, so no capture from that block could ever contribute positive
# evidence that resolution ran. The hidden-failure anchor is the one that block does
# resolve. Added at the correctness review, 2026-08-07.
SENTINEL_ANCHORS = (("Severity labels", None), ("Your role", "Hidden failure:"))

STUB_CODEX = """#!/usr/bin/env bash
# Records EVERY schema it is handed — one file per invocation, never overwriting.
# The correctness block invokes codex twice with two different schemas; a single
# capture path would silently keep only the second and assert on half the evidence.
prev=""
for a in "$@"; do
  if [ "$prev" = "--output-schema" ]; then
    cp "$a" "$CODEX_CAPTURE_DIR/$$-$RANDOM.json"
  fi
  if [ "$prev" = "-o" ]; then printf '{}' > "$a"; fi
  prev="$a"
done
exit 0
"""


def bash_blocks(text: str) -> list[str]:
    return re.findall(r"```bash\n(.*?)```", text, re.S)


def main() -> int:
    root = Path(sys.argv[1]).resolve()
    skills = root / ".claude" / "skills"
    targets = [
        (skills / "frame" / "SKILL.md", "frame"),
        (skills / "review" / "SKILL.md", "review"),
    ]

    failures = 0
    contract_text = (root / "workflow-AGENTS.md").read_text()
    expected = []
    lines = contract_text.splitlines()
    for name, term in SENTINEL_ANCHORS:
        i = next(
            (k for k, s in enumerate(lines)
             if s.startswith("## ") and re.sub(r"\s*\([^)]*\)\s*$", "", s[3:]).strip() == name),
            None,
        )
        if i is None:
            print(f"FAIL  contract has no section '{name}' — nothing to assert against")
            return 1
        j = next(
            (k for k in range(i + 1, len(lines)) if lines[k].startswith("## ")),
            len(lines),
        )
        body_lines = lines[i + 1 : j]
        if term is not None:
            body_lines = [
                s for s in body_lines
                if re.match(r"^\s*(?:-|\d+\.)\s+\*\*" + re.escape(term) + r"\*\*", s)
            ]
            if not body_lines:
                print(f"FAIL  contract section '{name}' has no '{term}' item")
                return 1
        body = "\n".join(body_lines).strip()
        if not body:
            print(f"FAIL  contract anchor '{name}' is empty — nothing to assert against")
            return 1
        expected.append(body.splitlines()[0].strip())

    resolved_seen: list[str] = []
    home = Path(tempfile.mkdtemp())
    try:
        # Mirror what install.sh deploys, so the block runs against a realistic $HOME.
        (home / ".claude").mkdir()
        shutil.copytree(skills / "review", home / ".claude" / "skills" / "review")
        shutil.copy(root / "workflow-AGENTS.md", home / ".claude" / "workflow-AGENTS.md")
        stub_dir = home / "bin"
        stub_dir.mkdir()
        (stub_dir / "codex").write_text(STUB_CODEX)
        (stub_dir / "codex").chmod(0o755)

        for path, label in targets:
            for n, block in enumerate(bash_blocks(path.read_text())):
                if "--render-schema" not in block and "--output-schema" not in block:
                    continue
                capdir = Path(tempfile.mkdtemp())
                work = Path(tempfile.mkdtemp())
                (work / "reviews").mkdir()
                (work / "reviews" / "demo.md").write_text("# demo\n")
                script = block.replace("<slug>", "demo").replace("<base>", "main")
                env = {
                    **os.environ,
                    "HOME": str(home),
                    "PATH": f"{stub_dir}:{os.environ['PATH']}",
                    "CODEX_CAPTURE_DIR": str(capdir),
                    "codexModel": "",
                }
                proc = subprocess.run(
                    ["bash", "-c", script],
                    cwd=work, env=env, capture_output=True, text=True,
                )
                caps = sorted(capdir.glob("*.json"))
                if proc.returncode != 0:
                    print(f"FAIL  {label} block {n}: exited {proc.returncode} — "
                          f"{proc.stderr.strip()[:160]}")
                    failures += 1
                elif not caps:
                    print(f"FAIL  {label} block {n}: codex was never handed a schema")
                    failures += 1
                else:
                    for cap in caps:
                        # Parse rather than grep: json.dumps escapes non-ASCII (the
                        # contract is full of em-dashes), so a substring match against
                        # raw contract text fails on a correctly-rendered file.
                        try:
                            parsed = json.loads(cap.read_text())
                        except json.JSONDecodeError as exc:
                            print(f"FAIL  {label} block {n}: invalid JSON ({exc})")
                            failures += 1
                            continue
                        descs = []

                        def _walk(node):
                            if isinstance(node, dict):
                                for k, v in node.items():
                                    if k == "description" and isinstance(v, str):
                                        descs.append(v)
                                    else:
                                        _walk(v)
                            elif isinstance(node, list):
                                for x in node:
                                    _walk(x)

                        _walk(parsed)
                        blob = "\n".join(descs)
                        # THE hazard: codex reviewing against raw marker text.
                        if "{{" in blob:
                            print(f"FAIL  {label} block {n}: codex was handed "
                                  f"UNRESOLVED markers")
                            failures += 1
                        else:
                            if any(e in blob for e in expected):
                                resolved_seen.append(f"{label}/{n}")
                            print(f"  ok   {label} block {n}: no unresolved markers "
                                  f"in the consumed schema")
                shutil.rmtree(capdir, ignore_errors=True)
                shutil.rmtree(work, ignore_errors=True)
    finally:
        shutil.rmtree(home, ignore_errors=True)

    # Absence of markers alone is vacuous — a schema with no markers trivially has
    # none left. At least one consumed schema must carry the CONTRACT's text, which
    # only happens if resolution really ran end to end through a real codex block.
    if not resolved_seen:
        print("FAIL  no consumed schema carried the contract's text — resolution "
              "never demonstrably ran (an absence-of-markers check alone is vacuous)")
        failures += 1
    else:
        print(f"  ok   resolution demonstrably ran end to end ({', '.join(resolved_seen)})")

    if failures:
        print(f"FAIL  {failures} codex render check(s) failed")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
