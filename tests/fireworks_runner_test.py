#!/usr/bin/env python3
"""Behavioral gate for the fireworks reviewer backend.

Unlike tests/reviewer_test.sh — a documentation linter with no oracle, by its own
charter — this suite has a real target. The runner is executable code, so every
check here drives it and asserts on observable behaviour: exit status, what
reached the API, and what did or did not land on disk.

No network and no credential: the API client is stubbed. Each test runs against a
throwaway git repo built in a temp dir, so nothing here touches the real tree.
"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parent.parent
RUNNER_PATH = ROOT / ".claude" / "skills" / "review" / "fireworks_runner.py"

spec = importlib.util.spec_from_file_location("fireworks_runner", RUNNER_PATH)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

PASSED = 0
FAILED = 0


def ok(name: str) -> None:
    global PASSED
    PASSED += 1
    print(f"  ok   {name}")


def bad(name: str, detail: str = "") -> None:
    global FAILED
    FAILED += 1
    print(f"FAIL  {name}" + (f" — {detail}" if detail else ""))


def check(name: str, condition: bool, detail: str = "") -> None:
    ok(name) if condition else bad(name, detail)


# ── Stub client ───────────────────────────────────────────────────────────────


class StubResponse:
    def __init__(self, content, finish_reason="stop"):
        message = SimpleNamespace(content=content)
        self.choices = [SimpleNamespace(message=message, finish_reason=finish_reason)]


class StubClient:
    """Records every request and replies from a per-purpose script."""

    def __init__(self, replies, calls, barrier=None, raise_on=None):
        self._replies = replies
        self._calls = calls
        self._barrier = barrier
        self._raise_on = raise_on or {}
        self.chat = SimpleNamespace(
            completions=SimpleNamespace(create=self._create)
        )

    def _create(self, **kwargs):
        name = kwargs["response_format"]["json_schema"]["name"]
        self._calls.append(kwargs)
        if self._barrier is not None:
            # Both passes must arrive before either returns. If the runner is
            # sequential this raises BrokenBarrierError on timeout.
            self._barrier.wait(timeout=5)
        if name in self._raise_on:
            raise RuntimeError(self._raise_on[name])
        reply = self._replies.get(name, self._replies.get("*"))
        if isinstance(reply, tuple):
            return StubResponse(reply[0], reply[1])
        return StubResponse(reply)


VALID_FINDING = json.dumps({"summary": "no issues", "findings": []})


def stub(replies, calls=None, barrier=None, raise_on=None):
    calls = calls if calls is not None else []
    return lambda _key: StubClient(replies, calls, barrier, raise_on), calls


# ── Fixture ───────────────────────────────────────────────────────────────────


@contextlib.contextmanager
def repo(slug="demo", story="# demo\n\nspec body\n", contract="# contract\n", change=True):
    """A throwaway git repo with a base branch and one commit of change on top."""
    tmp = Path(tempfile.mkdtemp())
    try:
        run = lambda *a: subprocess.run(
            a, cwd=tmp, check=True, capture_output=True, text=True
        )
        run("git", "init", "-q", "-b", "main")
        run("git", "config", "user.email", "t@example.com")
        run("git", "config", "user.name", "T")
        (tmp / "AGENTS.md").write_text(contract)
        (tmp / "reviews").mkdir()
        (tmp / "reviews" / f"{slug}.md").write_text(story)
        (tmp / "seed.txt").write_text("seed\n")
        run("git", "add", "-A")
        run("git", "commit", "-qm", "base")
        run("git", "checkout", "-qb", "feature")
        if change:
            (tmp / "seed.txt").write_text("seed\nchanged\n")
            run("git", "add", "-A")
            run("git", "commit", "-qm", "change")
        yield tmp
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def ctx_for(root: Path, slug="demo", model=None):
    return {
        "root": root,
        "slug": slug,
        "base": "main",
        "api_key": "stub-key",
        "model_override": model,
        "context_length_override": None,
    }


def invoke(root: Path, replies=None, slug="demo", model=None, barrier=None,
           raise_on=None, calls=None):
    """Run the correctness altitude with a stubbed client. Returns (rc, calls, stderr)."""
    replies = replies if replies is not None else {"*": VALID_FINDING}
    factory, recorded = stub(replies, calls, barrier, raise_on)
    original = runner.build_client
    runner.build_client = factory
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            rc = runner.run_altitude(
                "correctness", ctx_for(root, slug, model), runner.load_routes()
            )
    except runner.RunnerError as exc:
        rc, _ = 1, err.write(str(exc))
    except Exception as exc:
        # Mirror main()'s catch-all. Driving run_altitude directly would otherwise
        # let a bug escape as a traceback here while production reports a stopped
        # round — the test must observe the behaviour callers actually get.
        rc, _ = 1, err.write(f"unexpected error: {exc!r}")
    finally:
        runner.build_client = original
    return rc, recorded, err.getvalue()


def artifacts(root: Path):
    return sorted(p.name for p in (root / "reviews").iterdir() if p.name != "demo.md")


# ── AC-2: schema enforcement, fail-closed ─────────────────────────────────────

print("== AC-2: schema enforcement is fail-closed ==")

with repo() as root:
    rc, _, err = invoke(root, {"*": "{}"})
    check("empty object {} is rejected", rc != 0, f"rc={rc}")
    check("  ↳ no artifact written", artifacts(root) == [], str(artifacts(root)))

with repo() as root:
    rc, _, _ = invoke(root, {"*": json.dumps({"nonsense": True, "count": 3})})
    check("wrong-shape JSON is rejected", rc != 0)
    check("  ↳ no artifact written", artifacts(root) == [])

with repo() as root:
    rc, _, err = invoke(root, {"*": (VALID_FINDING, "length")})
    check("finish_reason=length is rejected", rc != 0)
    check("  ↳ names truncation, not bad JSON", "cut off" in err, err[:80])

with repo() as root:
    rc, _, _ = invoke(root, {"*": "not json at all"})
    check("unparseable body is rejected", rc != 0)
    check("  ↳ no artifact and no .tmp sibling", artifacts(root) == [])

with repo() as root:
    calls = []
    invoke(root, calls=calls)
    req = calls[0]
    check("request uses json_schema enforcement",
          req["response_format"]["type"] == "json_schema")
    check("  ↳ carries the caller's schema",
          "findings" in json.dumps(req["response_format"]["json_schema"]["schema"]))
    check("request sets overflow behaviour to error",
          req.get("extra_body", {}).get("context_length_exceeded_behavior") == "error",
          str(req.get("extra_body")))
    check("request reserves an output-token budget",
          isinstance(req.get("max_tokens"), int) and req["max_tokens"] > 0)

with repo() as root:
    real_validate = runner.validate

    def no_jsonschema(payload, schema, purpose):
        raise runner.RunnerError("the 'jsonschema' package is not available")

    runner.validate = no_jsonschema
    try:
        rc, _, err = invoke(root)
    finally:
        runner.validate = real_validate
    check("missing validator fails closed", rc != 0)
    check("  ↳ no artifact written", artifacts(root) == [])

# happy path, to prove the failures above are not vacuous
with repo() as root:
    rc, _, err = invoke(root)
    check("valid schema-conforming reply is promoted", rc == 0, err[:120])
    check("  ↳ both artifacts written",
          artifacts(root) == ["demo.codex.json", "demo.hidden-failure.json"],
          str(artifacts(root)))
    check("  ↳ no .tmp residue",
          not any(p.name.startswith(".") for p in (root / "reviews").iterdir()))


# ── AC-3: model routing by purpose ────────────────────────────────────────────

print("== AC-3: routing resolves by purpose, never by fallback ==")

routes = runner.load_routes()
try:
    runner.resolve_route("no-such-purpose", routes)
    bad("unknown purpose is an error")
except runner.RunnerError:
    ok("unknown purpose is an error")

try:
    runner.resolve_route("correctness", {})
    bad("empty routing table is an error")
except runner.RunnerError:
    ok("empty routing table is an error")

source = RUNNER_PATH.read_text()
check("no model id hardcoded in runner source",
      "accounts/fireworks/models/" not in source)

with repo() as root:
    calls = []
    invoke(root, calls=calls)
    check("table model reaches the request",
          all(c["model"] == routes["correctness"]["model"] for c in calls),
          str({c["model"] for c in calls}))

with repo() as root:
    calls = []
    invoke(root, model="accounts/fireworks/models/override-me", calls=calls)
    check("--model override reaches the request",
          all(c["model"] == "accounts/fireworks/models/override-me" for c in calls))

# An override must be a COMPLETE route. Taking the id from the flag while the size
# guard kept the table's contextLength sourced one model contract from two records.
print("== AC-3: a --model override must carry its own context length ==")
argv = ["--altitude", "correctness", "--slug", "demo", "--base", "main"]


def run_main(extra):
    saved = sys.argv
    sys.argv = ["fireworks_runner.py", *argv, *extra]
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            rc = runner.main()
    finally:
        sys.argv = saved
    return rc, err.getvalue()


os.environ.setdefault("FIREWORKS_API_KEY", "stub-key")
rc, err = run_main(["--model", "accounts/fireworks/models/x"])
check("--model without --context-length is rejected", rc != 0)
check("  ↳ message names the flag it needs", "--context-length" in err, err[:90])
rc, err = run_main(["--context-length", "1000"])
check("--context-length without --model is rejected", rc != 0)
rc, err = run_main(["--model", "accounts/fireworks/models/x", "--context-length", "0"])
check("a non-positive --context-length is rejected", rc != 0)

with repo() as root:
    # The guard must use the OVERRIDE's window, not the routed model's. A tiny
    # override window must trip the guard even though the table's is 1M.
    ctx = ctx_for(root, model="accounts/fireworks/models/tiny")
    ctx["context_length_override"] = 1000
    factory, calls = stub({"*": VALID_FINDING})
    original = runner.build_client
    runner.build_client = factory
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            rc = runner.run_altitude("correctness", ctx, runner.load_routes())
    except runner.RunnerError as exc:
        rc, _ = 1, err.write(str(exc))
    finally:
        runner.build_client = original
    check("the size guard uses the override's window, not the table's", rc != 0)
    check("  ↳ no request was made", calls == [], f"{len(calls)} call(s)")


# ── AC-4: routing table structure ─────────────────────────────────────────────

print("== AC-4: routing table is well-formed and covers every pass ==")

table = json.loads((ROOT / ".claude/skills/review/fireworks-models.json").read_text())
check("table carries an 'updated' date", bool(table.get("updated")))
needed = {spec["purpose"] for spec in runner.PASSES.values()}
check("every pass purpose is routed", needed <= set(table["routes"]),
      f"missing {needed - set(table['routes'])}")
check("every route has a positive integer contextLength",
      all(isinstance(r.get("contextLength"), int) and r["contextLength"] > 0
          for r in table["routes"].values()))
check("every route states why", all(r.get("why") for r in table["routes"].values()))
# Routing ahead of use is allowed (design/approach are routed before they are
# wired); routing a purpose that is not a review purpose at all is a silent typo.
check("no unknown purposes routed",
      set(table["routes"]) <= runner.KNOWN_PURPOSES,
      f"unrecognised: {set(table['routes']) - runner.KNOWN_PURPOSES}")
check("every wired pass purpose is a known purpose",
      {p["purpose"] for p in runner.PASSES.values()} <= runner.KNOWN_PURPOSES)

# Diagnostics must name their cause rather than fall through to the catch-all.
with repo() as root:
    shim = Path(tempfile.mkdtemp())
    (shim / "finding-schema.json").write_text("{ this is not json")
    (shim / "hidden-failure-schema.json").write_text("{ this is not json")
    real_here = runner.HERE
    runner.HERE = shim
    try:
        rc, _, err = invoke(root)
    finally:
        runner.HERE = real_here
        shutil.rmtree(shim, ignore_errors=True)
    check("an unparseable schema file is rejected", rc != 0)
    check("  ↳ named as a schema problem, not 'unexpected error'",
          "not valid JSON" in err, err[:110])
    check("  ↳ nothing promoted", artifacts(root) == [])


# ── AC-5: the runner owns orchestration ───────────────────────────────────────

print("== AC-5: orchestration is concurrent and all-or-nothing ==")

schemas = [p["schema"] for p in runner.PASSES.values()]
arts = [p["artifact"] for p in runner.PASSES.values()]
check("each pass binds a distinct schema", len(set(schemas)) == len(schemas))
check("each pass binds a distinct artifact", len(set(arts)) == len(arts))

with repo() as root:
    barrier = threading.Barrier(2)
    rc, _, err = invoke(root, barrier=barrier)
    check("passes at one altitude run concurrently", rc == 0,
          "barrier timed out — passes ran sequentially")

with repo() as root:
    rc, _, err = invoke(root, raise_on={"hidden_failure": "boom"})
    check("one failed pass stops the round", rc != 0)
    check("  ↳ NEITHER artifact promoted", artifacts(root) == [], str(artifacts(root)))
    check("  ↳ stderr names the failing pass", "hidden-failure" in err, err[:120])

# Regression oracle for the defect both correctness critics found on the live run:
# promote() renamed as it went, so a failure on the second artifact left the first
# already promoted. Staging must complete for every artifact before any is committed.
with repo() as root:
    real_mkstemp = tempfile.mkstemp
    calls = {"n": 0}

    def failing_mkstemp(**kwargs):
        calls["n"] += 1
        if calls["n"] == 2:  # second artifact fails while staging
            raise OSError("no space left on device")
        return real_mkstemp(**kwargs)

    tempfile.mkstemp = failing_mkstemp
    try:
        rc, _, err = invoke(root)
    finally:
        tempfile.mkstemp = real_mkstemp
    check("a failure staging the 2nd artifact promotes NEITHER", artifacts(root) == [],
          f"partial promotion: {artifacts(root)}")
    check("  ↳ round reports failure", rc != 0)
    check("  ↳ no temp left behind",
          not any(p.name.startswith(".") for p in (root / "reviews").iterdir()))

with repo() as root:
    stale_c = root / "reviews" / "demo.codex.json"
    stale_h = root / "reviews" / "demo.hidden-failure.json"
    stale_c.write_text('{"summary":"STALE","findings":[]}')
    stale_h.write_text('{"summary":"STALE","findings":[]}')
    rc, _, _ = invoke(root, raise_on={"correctness": "boom"})
    check("a failed round leaves stale artifacts untouched", rc != 0)
    check("  ↳ stale content not overwritten with a partial result",
          json.loads(stale_c.read_text())["summary"] == "STALE"
          and json.loads(stale_h.read_text())["summary"] == "STALE")


# ── AC-6: declarative context profile, fail-closed ────────────────────────────

print("== AC-6: pushed context is complete or the round stops ==")

for missing, remove in (
    ("contract", lambda r: (r / "AGENTS.md").unlink()),
    ("story", lambda r: (r / "reviews" / "demo.md").unlink()),
):
    with repo() as root:
        remove(root)
        rc, calls, err = invoke(root)
        check(f"missing {missing} aborts the round", rc != 0)
        check(f"  ↳ no request was made", calls == [], f"{len(calls)} call(s)")
        check(f"  ↳ no artifact written", artifacts(root) == [])

with repo(contract="") as root:
    rc, calls, err = invoke(root)
    check("empty contract aborts (present is not enough)", rc != 0)
    check("  ↳ names the empty input", "empty" in err.lower(), err[:100])

with repo(change=False) as root:
    rc, calls, err = invoke(root)
    check("empty diff aborts (nothing to review)", rc != 0)
    check("  ↳ no request was made", calls == [])

with repo(story="x" * 200_000) as root:
    original = runner.load_routes
    runner.load_routes = lambda: {
        "correctness": {"model": "m", "contextLength": 1000},
        "hidden-failure": {"model": "m", "contextLength": 1000},
    }
    try:
        rc, calls, err = invoke(root)
    finally:
        runner.load_routes = original
    check("oversized payload aborts", rc != 0)
    check("  ↳ before any request is made", calls == [], f"{len(calls)} call(s)")
    check("  ↳ names the size budget", "too large" in err, err[:100])

with repo() as root:
    calls = []
    invoke(root, calls=calls)
    contexts = [c["messages"][1]["content"] for c in calls]
    check("both passes receive byte-identical context",
          len(contexts) == 2 and contexts[0] == contexts[1])
    check("  ↳ context carries every declared input",
          all(tok in contexts[0] for tok in ("AGENTS.md", "story file", "git diff", "git log")))
    check("  ↳ passes differ only in the question asked",
          calls[0]["messages"][0]["content"] != calls[1]["messages"][0]["content"])

# Amended row (see the story's Falsification-plan amendments): the runner uses
# tempfile.mkstemp, not shell mktemp, so temp paths are unique by construction.
with repo() as root:
    seen = set()
    real_mkstemp = tempfile.mkstemp

    def recording_mkstemp(**kwargs):
        fd, path = real_mkstemp(**kwargs)
        seen.add(path)
        return fd, path

    tempfile.mkstemp = recording_mkstemp
    try:
        invoke(root)
    finally:
        tempfile.mkstemp = real_mkstemp
    check("each promoted artifact used a unique temp path", len(seen) == 2, str(seen))
    check("  ↳ no temp survives a successful promote",
          not any(Path(p).exists() for p in seen))


print()
print(f"passed={PASSED} failed={FAILED}")
if FAILED:
    sys.exit(1)
print("ALL FIREWORKS RUNNER CHECKS PASSED (behavioral — stubbed client, no network)")
