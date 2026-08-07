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
# A clean reply under design-review-schema, which BOTH the design and approach passes bind.
# `regressions` is required there, so a stub omitting it is rejected by the runner's own
# validation — correctly. Named once so the two altitudes cannot drift apart.
VALID_DESIGN = json.dumps({"verdict": "ok", "findings": [], "regressions": []})


def stub(replies, calls=None, barrier=None, raise_on=None):
    calls = calls if calls is not None else []
    return lambda _key: StubClient(replies, calls, barrier, raise_on), calls


# ── Fixture ───────────────────────────────────────────────────────────────────


@contextlib.contextmanager
def repo(slug="demo", story="# demo\n\nspec body\n", contract="# contract\n", change=True,
         local_contract=None):
    """A throwaway git repo, plus a throwaway SHARED contract the runner is pointed at.

    The shared contract lives OUTSIDE the repo now, so the fixture redirects the module
    constant `runner.CONTRACT_PATH` at a temp file for the duration. It is restored on exit.

    Isolation is not incidental here — a suite that silently read the developer's real
    ~/.claude/workflow-AGENTS.md would pass for the wrong reason and would keep passing on a
    machine where that file does not exist. Every test therefore asserts against a contract
    whose text this fixture chose.

    `local_contract` writes the repo's OWN AGENTS.md — repo-specific add-ons. Default None
    means no such file, which is the normal case for most repositories.
    """
    tmp = Path(tempfile.mkdtemp())
    shared = tmp / "_shared_contract.md"
    shared.write_text(contract)
    saved_contract_path = runner.CONTRACT_PATH
    runner.CONTRACT_PATH = shared
    try:
        run = lambda *a: subprocess.run(
            a, cwd=tmp, check=True, capture_output=True, text=True
        )
        run("git", "init", "-q", "-b", "main")
        run("git", "config", "user.email", "t@example.com")
        run("git", "config", "user.name", "T")
        if local_contract is not None:
            (tmp / "AGENTS.md").write_text(local_contract)
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
        runner.CONTRACT_PATH = saved_contract_path
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

# Only `stop` is a completed reply. A filtered or otherwise abnormal completion can
# be perfectly schema-valid, so validation cannot catch it — the finish_reason is
# the only signal that the review is not what the model would have written.
for reason in ("content_filter", "tool_calls", "", None, "unexpected_new_reason"):
    with repo() as root:
        rc, _, err = invoke(root, {"*": (VALID_FINDING, reason)})
        check(f"finish_reason={reason!r} is rejected", rc != 0)
        check(f"  ↳ nothing promoted", artifacts(root) == [], str(artifacts(root)))

with repo() as root:
    rc, _, err = invoke(root, {"*": (VALID_FINDING, "content_filter")})
    check("  ↳ names filtering as the cause", "altered" in err or "suppressed" in err,
          err[:100])


class NoChoices:
    choices = []


with repo() as root:
    original = runner.build_client
    runner.build_client = lambda _k: SimpleNamespace(
        chat=SimpleNamespace(
            completions=SimpleNamespace(create=lambda **kw: NoChoices())
        )
    )
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            rc = runner.run_altitude("correctness", ctx_for(root), runner.load_routes())
    except Exception as exc:
        rc, _ = 1, err.write(repr(exc))
    finally:
        runner.build_client = original
    check("an empty choices list is rejected", rc != 0)
    check("  ↳ named, not 'unexpected error'", "no choices" in err.getvalue(),
          err.getvalue()[:100])
    check("  ↳ nothing promoted", artifacts(root) == [])

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
    # Per PURPOSE, not one shared model. Asserting a single model across the round
    # held only while the two correctness critics happened to share a route, and it
    # would silently re-couple them if routing ever collapsed — the same-model panel
    # this altitude exists to avoid. The json_schema name is the purpose (see the
    # request builder), so it identifies which critic made each call.
    by_purpose = {c["response_format"]["json_schema"]["name"]: c["model"] for c in calls}
    check("table model reaches the request, per purpose",
          by_purpose == {p.replace("-", "_"): routes[p]["model"]
                         for p in ("correctness", "hidden-failure")},
          str(by_purpose))

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

# BUG-6: a schema file that PARSES but constrains nothing must stop the round.
# This is the hole that made validation vacuous — unrecognised keywords are
# no-ops, so a foreign JSON document substituted for a schema validates anything
# (including {}) and the round promoted an empty body as a clean review. Both
# enforcement layers read this one dict, so they failed together.
print("== BUG-6: a schema that constrains nothing is not a schema ==")

# The exact substitution that surfaced it: a real, valid JSON file from this
# skill that is not a schema. Legal as a schema; every keyword unrecognised.
foreign = (Path(__file__).resolve().parent.parent
           / ".claude/skills/review/fireworks-models.json").read_text()
with repo() as root:
    shim = Path(tempfile.mkdtemp())
    (shim / "finding-schema.json").write_text(foreign)
    (shim / "hidden-failure-schema.json").write_text(foreign)
    real_here = runner.HERE
    runner.HERE = shim
    try:
        rc, calls, err = invoke(root)
    finally:
        runner.HERE = real_here
        shutil.rmtree(shim, ignore_errors=True)
    check("a foreign JSON document used as a schema is rejected", rc != 0)
    check("  ↳ names the empty object, not a generic schema error",
          "ACCEPTS THE EMPTY OBJECT" in err, err[:160])
    check("  ↳ nothing promoted", artifacts(root) == [])
    check("  ↳ rejected BEFORE any request was made", calls == [])

# check_schema's half: illegal AS a schema, which the probe alone would miss.
with repo() as root:
    shim = Path(tempfile.mkdtemp())
    (shim / "finding-schema.json").write_text('{"type": 123}')
    (shim / "hidden-failure-schema.json").write_text('{"type": 123}')
    real_here = runner.HERE
    runner.HERE = shim
    try:
        rc, calls, err = invoke(root)
    finally:
        runner.HERE = real_here
        shutil.rmtree(shim, ignore_errors=True)
    check("a file that is illegal as a schema is rejected", rc != 0)
    check("  ↳ named as an invalid schema", "not a valid JSON Schema" in err, err[:160])
    check("  ↳ nothing promoted", artifacts(root) == [])

# The standing guarantee the probe rests on: every SHIPPED schema rejects {}.
# If one ever stops carrying a non-empty `required`, the probe would fail the
# round at runtime — catch that here, in the gate, not mid-review.
for pass_name, spec in sorted(runner.PASSES.items()):
    path = runner.HERE / spec["schema"]
    try:
        runner.load_schema(pass_name, path)
        bites = True
    except runner.RunnerError:
        bites = False
    check(f"  ↳ shipped schema for '{pass_name}' rejects the empty object", bites)


# ── AC-5: the runner owns orchestration ───────────────────────────────────────

print("== AC-5: orchestration is concurrent and all-or-nothing ==")

arts = [p["artifact"] for p in runner.PASSES.values()]
# Artifacts must be distinct GLOBALLY — two passes writing one path clobber each
# other whenever they run, altitude notwithstanding.
check("each pass binds a distinct artifact", len(set(arts)) == len(arts))

# Schemas must be distinct WITHIN AN ALTITUDE, which is what OPS-12's standing
# rule governs: concurrent critics are told apart structurally, by their own
# schema and their own artifact, with no `lens` field to read. Passes at
# different altitudes never run together, so `design` and `approach` sharing
# design-review-schema.json is not ambiguity — both judge shape and emit the same
# tagged finding shape, and the codex path has fed them the same schema since
# before this backend existed. Scoping the check here rather than dropping it
# keeps the guard that matters: two passes fanned out at once staying separable.
for altitude, names in runner.ALTITUDES.items():
    at_altitude = [runner.PASSES[n]["schema"] for n in names]
    check(f"  ↳ {altitude}: concurrent passes bind distinct schemas",
          len(set(at_altitude)) == len(at_altitude), str(at_altitude))

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
    ("contract", lambda r: runner.CONTRACT_PATH.unlink()),
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
    # Derived from the pass's DECLARED inputs, not a hand-typed token list: a hand-typed
    # list silently stops covering what it names the moment a source is added, which is
    # exactly how `contract_local` could have been declared and never actually assembled.
    declared = runner.PASSES["correctness"]["context"]
    titles = [runner.CONTEXT_SOURCES[n]["title"] for n in declared]
    check("  ↳ context carries every declared input",
          all(t in contexts[0] for t in titles),
          f"missing: {[t for t in titles if t not in contexts[0]]}")
    check("  ↳ passes differ only in the question asked",
          calls[0]["messages"][0]["content"] != calls[1]["messages"][0]["content"])

# ── Approach altitude: shape-level context ────────────────────────────────────

print("== approach altitude pushes whole files, read at HEAD ==")


def invoke_approach(root, replies=None, calls=None):
    replies = replies if replies is not None else {"*": VALID_DESIGN}
    factory, recorded = stub(replies, calls)
    original = runner.build_client
    runner.build_client = factory
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            rc = runner.run_altitude("approach", ctx_for(root), runner.load_routes())
    except Exception as exc:
        rc, _ = 1, err.write(repr(exc))
    finally:
        runner.build_client = original
    return rc, recorded, err.getvalue()


with repo() as root:
    calls = []
    rc, calls, err = invoke_approach(root, calls=calls)
    check("approach altitude runs", rc == 0, err[:120])
    body = calls[0]["messages"][1]["content"]
    check("  ↳ pushes whole changed files, not just the diff",
          "seed.txt (at HEAD)" in body and "seed\nchanged" in body, body[-300:])
    check("  ↳ states manifest absence explicitly rather than omitting it",
          "stated absence" in body or "none present" in body)
    check("  ↳ writes the approach artifact",
          artifacts(root) == ["demo.approach.json"], str(artifacts(root)))

# The approach reviewer's finding: _manifests read the working tree while
# _changed_files read HEAD. The invariant is uniform now — EVERY context source
# reads at HEAD — so this asserts it for manifests specifically.
with repo() as root:
    subprocess.run(["git", "add", "-A"], cwd=root, check=True, capture_output=True)
    (root / "requirements.txt").write_text("committed-dep==1.0\n")
    subprocess.run(["git", "add", "-A"], cwd=root, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-qm", "add manifest"], cwd=root, check=True,
                   capture_output=True)
    (root / "requirements.txt").write_text("committed-dep==1.0\nUNCOMMITTED-DEP==9.9\n")
    (root / "package.json").write_text('{"name":"never-committed"}\n')
    calls = []
    invoke_approach(root, calls=calls)
    body = calls[0]["messages"][1]["content"]
    check("manifests are read at HEAD", "committed-dep==1.0" in body)
    check("  ↳ uncommitted manifest edits never reach the reviewer",
          "UNCOMMITTED-DEP" not in body,
          "working-tree manifest content leaked")
    check("  ↳ an untracked manifest is named, not silently omitted",
          "package.json" in body and "PRESENT BUT UNCOMMITTED" in body)
    check("  ↳ but its contents are withheld",
          "never-committed" not in body, "untracked manifest contents leaked")

# Rule 2 for manifests: a manifest that ls-tree found but git show cannot read
# must be NAMED, not dropped — "unreadable" must never look like "absent".
with repo() as root:
    (root / "requirements.txt").write_text("dep==1.0\n")
    subprocess.run(["git", "add", "-A"], cwd=root, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-qm", "manifest"], cwd=root, check=True,
                   capture_output=True)
    real_run = subprocess.run

    def failing_show(cmd, **kw):
        if isinstance(cmd, list) and cmd[:2] == ["git", "show"] and "requirements" in cmd[-1]:
            return SimpleNamespace(returncode=128, stdout="", stderr="fatal: bad object")
        return real_run(cmd, **kw)

    runner.subprocess.run = failing_show
    try:
        calls = []
        invoke_approach(root, calls=calls)
        body = calls[0]["messages"][1]["content"]
    finally:
        runner.subprocess.run = real_run
    check("an unreadable manifest is named, not silently dropped",
          "requirements.txt" in body and "NOT READABLE" in body,
          "a manifest vanished with no accounting")
    check("  ↳ the reviewer is told it is missing something",
          "you are missing these" in body.lower())

# THE bug the first live run exposed: reading the working tree while the diff is
# computed against HEAD splices two snapshots into one payload, letting
# uncommitted work leak into a review of committed work.
with repo() as root:
    (root / "seed.txt").write_text("seed\nchanged\nUNCOMMITTED LEAK\n")
    calls = []
    invoke_approach(root, calls=calls)
    body = calls[0]["messages"][1]["content"]
    check("uncommitted working-tree edits never reach the reviewer",
          "UNCOMMITTED LEAK" not in body,
          "working tree leaked into a review of committed work")

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


# ── Design altitude: judged before any code exists ────────────────────────────

print("== design altitude reviews the sketch, with no diff to read ==")


def invoke_design(root, base=None, calls=None):
    factory, recorded = stub({"*": VALID_DESIGN}, calls)
    original = runner.build_client
    runner.build_client = factory
    ctx = ctx_for(root)
    ctx["base"] = base  # frame time: there is nothing to diff against
    err = io.StringIO()
    try:
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            rc = runner.run_altitude("design", ctx, runner.load_routes())
    except Exception as exc:
        rc, _ = 1, err.write(repr(exc))
    finally:
        runner.build_client = original
    return rc, recorded, err.getvalue()


with repo() as root:
    rc, calls, err = invoke_design(root)
    check("design altitude runs with no base", rc == 0, err[:140])
    check("  ↳ writes the design artifact", "demo.design.json" in artifacts(root))
    body = calls[0]["messages"][1]["content"]
    design_titles = [runner.CONTEXT_SOURCES[n]["title"] for n in runner.PASSES["design"]["context"]]
    check("  ↳ pushes the contract and the story",
          all(t in body for t in design_titles),
          f"missing: {[t for t in design_titles if t not in body]}")
    # The whole point of the altitude: it judges intent. Handing it a diff would
    # invite findings about an implementation that does not exist yet.
    check("  ↳ pushes NO diff and NO commit log",
          "git diff" not in body and "git log" not in body, body[:160])
    check("  ↳ tells the reviewer no code exists yet",
          "NO CODE HAS BEEN WRITTEN YET" in calls[0]["messages"][0]["content"])

# --base is required where a pass reads it, and only there. Derived from the pass
# table, so this checks the derivation rather than a hardcoded altitude name.
check("design declares no base-dependent context source",
      not any(runner.CONTEXT_SOURCES[s].get("needs_base")
              for s in runner.PASSES["design"]["context"]))
for altitude in ("approach", "correctness"):
    check(f"  ↳ {altitude} still declares one (so --base stays required there)",
          any(runner.CONTEXT_SOURCES[s].get("needs_base")
              for n in runner.ALTITUDES[altitude]
              for s in runner.PASSES[n]["context"]))

# OPS-19: artifacts end with a newline, like the repo's hand-maintained JSON.
with repo() as root:
    invoke_design(root)
    written = (root / "reviews" / "demo.design.json").read_text()
    check("promoted artifacts end with a trailing newline", written.endswith("}\n"),
          repr(written[-12:]))




# ── Shared contract + repo-local add-ons (user-level-contract) ────────────────

print("== shared contract is required; repo AGENTS.md is optional add-ons ==")

# AC-2: the SHARED contract is required. Missing and empty are DIFFERENT failures and
# both must stop the round — "empty" is the one an optional-flag refactor could silently
# start tolerating, so it is asserted directly rather than assumed.
with repo() as root:
    runner.CONTRACT_PATH.unlink()
    rc, calls, err = invoke(root)
    check("missing shared contract stops the round", rc != 0, f"rc={rc}")
    check("  ↳ no artifact written", artifacts(root) == [], str(artifacts(root)))
    check("  ↳ no request was made", calls == [], f"{len(calls)} call(s)")

with repo() as root:
    runner.CONTRACT_PATH.write_text("   \n\n")
    rc, calls, err = invoke(root)
    check("EMPTY shared contract stops the round too", rc != 0, f"rc={rc}")
    check("  ↳ no artifact written", artifacts(root) == [], str(artifacts(root)))

# Isolation: the payload must carry the contract THIS fixture wrote. If the constant were
# captured at import time the suite would read the real ~/.claude and pass for the wrong
# reason — and would keep passing on a machine where that file does not exist.
with repo(contract="# SENTINEL-CONTRACT-9317\n\nonly this fixture wrote this\n") as root:
    calls = []
    invoke(root, calls=calls)
    body = calls[0]["messages"][1]["content"]
    check("the pushed contract is the fixture's, not the real ~/.claude",
          "SENTINEL-CONTRACT-9317" in body)

# AC-3: absent local add-ons are STATED, not silently omitted — the renders-nothing case,
# which is the whole point of an optional input in a pushed-context backend.
with repo() as root:
    calls = []
    rc, _, err = invoke(root, calls=calls)
    body = calls[0]["messages"][1]["content"]
    check("no repo AGENTS.md still succeeds", rc == 0, err[:140])
    check("  ↳ its absence is stated in the payload", "(none present in this repository)" in body)

with repo(local_contract="# Local\n\n- Solver code stays pure; no I/O.\n") as root:
    calls = []
    rc, _, err = invoke(root, calls=calls)
    body = calls[0]["messages"][1]["content"]
    check("present repo AGENTS.md succeeds", rc == 0, err[:140])
    check("  ↳ its CONTENT reaches the reviewer", "Solver code stays pure" in body)

# AC-5: a repo AGENTS.md that is really a stale copy of the shared contract is refused —
# both directions, since a guard that never fires and one that always fires are both wrong.
STALE = (Path(ROOT) / "workflow-AGENTS.md").read_text()
with repo(contract=STALE, local_contract=STALE) as root:
    rc, calls, err = invoke(root)
    check("a stale full copy in AGENTS.md stops the round", rc != 0, f"rc={rc}")
    check("  ↳ no artifact written", artifacts(root) == [], str(artifacts(root)))
    check("  ↳ what surfaces names the migration", "stale copy" in err and "AGENTS.md" in err,
          err[:160])

with repo(contract=STALE, local_contract="# Local rules\n\n- Prefer table-driven tests.\n") as root:
    rc, _, err = invoke(root)
    check("genuine local add-ons are NOT mistaken for a stale copy", rc == 0, err[:140])

# The preflight both skills call must agree with the runner — it calls the same code, so
# this asserts the CLI entry point actually reaches it rather than reimplementing it.
with repo(contract=STALE, local_contract=STALE) as root:
    check("--check-local-contract rejects a stale copy", runner.check_local_contract(root) == 1)
with repo(contract=STALE, local_contract="# Local\n\n- Keep the solver pure.\n") as root:
    check("--check-local-contract passes genuine add-ons", runner.check_local_contract(root) == 0)
with repo(contract=STALE) as root:
    check("--check-local-contract passes a repo with no AGENTS.md", runner.check_local_contract(root) == 0)

# AC-4: every pass declares BOTH contract inputs. Anchored to the skill invocations, not to
# PASSES alone — a check drawn only from the runner's own table cannot fail for a pass wired
# somewhere else, which is internal consistency rather than the criterion.
SKILL_ALTITUDES = ("design", "approach", "correctness", "lesson")   # frame/ + review/ + close/SKILL.md
invoked = {p for a in SKILL_ALTITUDES for p in runner.ALTITUDES[a]}
check("every pass the skills can invoke exists in PASSES", invoked <= set(runner.PASSES))
for name in sorted(invoked):
    ctx = runner.PASSES[name]["context"]
    check(f"  ↳ {name} declares both contract inputs",
          "contract" in ctx and "contract_local" in ctx, str(ctx))


# lesson-proposals AC6: the lesson pass gets its OWN schema, not a repurposed one.
# The regression this exists to catch is a schema that is new in NAME but a structural
# clone of design-review-schema.json — reversibility/standing/regressions surviving into a
# lesson assessment where they mean nothing is exactly how an independent check becomes the
# ceremonial field-filling the separate schema was created to avoid.
LESSON_SCHEMA = ROOT / ".claude/skills/review/lesson-review-schema.json"
check("the lesson pass exists", "lesson" in runner.PASSES)
check("the lesson pass does not reuse an existing schema",
      runner.PASSES["lesson"]["schema"] == "lesson-review-schema.json")
_lesson = runner.load_schema("lesson", LESSON_SCHEMA)   # raises if it accepts {}
check("the lesson schema constrains something (load_schema accepted it)", bool(_lesson))
_props = set(_lesson.get("properties", {}))
for dead in ("reversibility", "standing", "regressions"):
    check(f"  ↳ no vestigial design-review field: {dead}", dead not in _props)
for live in ("trigger_qualified", "stronger_explanation", "scope"):
    check(f"  ↳ asks the lesson question: {live}", live in _props)
# The proposal is NOT echoed by the model — it is written to its own file by /close, because
# a model asked to reproduce a long proposal paraphrases or truncates it, silently defeating
# the durability rule that requirement serves.
check("the lesson pass reads the proposal as a declared context input",
      "lesson_proposal" in runner.PASSES["lesson"]["context"])
check("no echo-the-proposal field in the schema",
      not {p for p in _props if "proposal" in p.lower()})
# The shared contract was NOT extended for this pass — the pass's questions live in its own
# prompt, so every other repo's reviews carry none of its weight.
check("the shared reviewer contract is untouched by the lesson pass",
      "lesson" not in (ROOT / "workflow-AGENTS.md").read_text().lower())

print()
print(f"passed={PASSED} failed={FAILED}")
if FAILED:
    sys.exit(1)
print("ALL FIREWORKS RUNNER CHECKS PASSED (behavioral — stubbed client, no network)")
