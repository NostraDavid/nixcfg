#!/usr/bin/env python3
"""Measure CTB skill activation and task outcomes in isolated Codex sessions."""

import argparse
import hashlib
import json
import os
import re
import shutil
import statistics as stats
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
CASES = json.loads((SKILL / "evals/cases.json").read_text())
COMMON = (
    "\nThis is an isolated synthetic evaluation. Use only this workspace and its "
    "declared Python interpreter. Do not read other repositories or home configuration, "
    "contact services, spawn agents, install packages, synchronize environments, or change input files. "
    "Create task outputs only under output/."
)
TYPES = {
    "market": "String",
    "day_start": "Datetime(time_unit='ms', time_zone='UTC')",
    **{
        name: "Decimal(precision=38, scale=18)"
        for name in ("open", "high", "low", "close", "volume")
    },
    "observed_candles": "Int64",
    "missing_minutes": "Int64",
    "quality": "String",
    "freshness": "String",
}
OUTCOMES = {"quality": ["valid", "degraded"], "freshness": ["current", "stale"]}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def snapshot(root):
    return {
        str(path.relative_to(root)): [
            hashlib.sha256(path.read_bytes()).hexdigest(),
            path.stat().st_mode & 0o777,
        ]
        for path in root.rglob("*")
        if path.is_file()
        and path.relative_to(root).parts[0] != "output"
        and "__pycache__" not in path.relative_to(root).parts
    }


def validators_python():
    for root in (Path.home() / ".cache/uv/environments-v2").glob("contracts-*"):
        python = root / "bin/python"
        if python.exists():
            return python
    raise ValueError(
        "Run the descriptor CLI check once to prepare its pinned environment"
    )


def helper(python, code, *args):
    result = subprocess.run(
        [str(python), "-B", "-c", code, *map(str, args)],
        text=True,
        capture_output=True,
        timeout=60,
    )
    if result.returncode:
        raise ValueError(result.stderr)
    return result.stdout


def fixture(root, python, case_id, with_skill):
    root.mkdir(parents=True)
    (root / "dagster-runtime").mkdir()
    package = root / "ctb-bitvavo/src/ctb_bitvavo"
    package.mkdir(parents=True)
    (package / "__init__.py").write_text("")
    source = (
        "from types import SimpleNamespace\nfrom typing import Literal\n"
        f"DAILY_SCHEMA = {TYPES!r}\nclass CuratedArtifact:\n"
        "    model_fields = {'quality': SimpleNamespace(annotation=Literal['valid','degraded']), "
        "'freshness': SimpleNamespace(annotation=Literal['current','stale'])}\n"
    )
    (package / "curated.py").write_text(source)
    (package / "decimal_utils.py").write_text(
        "DECIMAL_TYPE = 'Decimal(precision=38, scale=18)'\n"
    )
    for filename in ("query.py", "provenance.py"):
        (package / filename).write_text(
            "# Synthetic fixture; no live services or persistence.\n"
        )
    docs = root / "docs/adr"
    docs.mkdir(parents=True)
    (
        docs / "ADR-SYS-0045-use-odcs-and-odps-for-data-contracts-and-products.md"
    ).write_text(
        "---\nstatus: PROPOSED\n---\nDraft local ODCS v3.2.0 and ODPS v1.1.0 metadata for public daily candles. "
        "Preserve exact Decimal(38,18), UTC milliseconds, nullable OHLCV on empty days, "
        "and unique (market, day_start). Missing observations do not prove zero trading. "
        "No completeness or freshness SLA has been established.\n"
    )
    runbooks = root / "docs/runbooks"
    runbooks.mkdir()
    for filename in ("curated-daily-candles.md", "read-curated-candles.md"):
        (runbooks / filename).write_text(
            "One row per market and closed UTC day. OHLCV is nullable; observed_candles and "
            "missing_minutes are non-null Int64. quality is valid/degraded; freshness current/stale. "
            "An unavailable day may have no row. Primary key is market,day_start.\n"
        )
    for number in ("0018", "0027", "0029", "0030", "0043", "0044"):
        (docs / f"ADR-SYS-{number}-fixture.md").write_text(
            "Synthetic evaluation: preserve inputs and existing semantics.\n"
        )
    shutil.copytree(SKILL / "assets/schemas", root / "standards")
    import_root = root / "ctb-bitvavo/src"
    if case_id == "t03-wrong-checkout":
        import_root = root / "foreign-checkout/src"
        foreign = import_root / "ctb_bitvavo"
        foreign.mkdir(parents=True)
        (foreign / "__init__.py").write_text("")
        (foreign / "curated.py").write_text(source)
    interpreter = root / "ctb-bitvavo/.venv/bin/python"
    interpreter.parent.mkdir(parents=True)
    interpreter.write_text(
        "#!/usr/bin/env python3\nimport os, sys\n"
        f"prefix = {('import sys; sys.path.insert(0, ' + repr(str(import_root)) + '); ')!r}\n"
        f"os.execv({str(python)!r}, [{str(python)!r}, '-B', '-c', prefix + sys.argv[-1]])\n"
    )
    interpreter.chmod(0o755)
    if with_skill:
        shutil.copytree(
            SKILL,
            root / ".agents/skills/ctb-data-contracts",
            ignore=shutil.ignore_patterns("evals", "__pycache__"),
        )
    (root / "README.md").write_text(
        "Synthetic CTB fixture. The runtime types are string stand-ins for Polars dtypes. "
        f"Use {python} -B to run Python or bundled scripts; its yaml/jsonschema dependencies "
        "are already available. Do not use uv or install dependencies during evaluation.\n"
    )
    if case_id == "t02-incompatible-change":
        code = (
            "import importlib.util,json,sys; "
            "s=importlib.util.spec_from_file_location('contracts',sys.argv[1]); "
            "m=importlib.util.module_from_spec(s); s.loader.exec_module(m); "
            "pair=m.generate(json.loads(sys.argv[2]),'fixture-contract','fixture-product','1.0.0','Evaluation Owner'); "
            "print(json.dumps(pair[0]))"
        )
        original = json.loads(
            helper(
                python,
                code,
                SKILL / "scripts/contracts.py",
                json.dumps({"types": TYPES, "outcomes": OUTCOMES}),
            )
        )
        write_json(root / "original.odcs.yaml", original)
        candidate = json.loads(json.dumps(original))
        field = next(
            p for p in candidate["schema"][0]["properties"] if p["name"] == "open"
        )
        field.update(physicalType="Decimal(precision=38, scale=9)", required=True)
        write_json(root / "candidate.odcs.yaml", candidate)


def model_settings():
    settings = {}
    config = (Path.home() / ".codex/config.toml").read_text()
    for key in ("model", "model_reasoning_effort"):
        match = re.search(rf'^{key}\s*=\s*"([^"]+)"', config, re.MULTILINE)
        if match:
            settings[key] = match[1]
    return settings


def command(root, enabled, task):
    entries = []
    for base in (Path.home() / ".codex/skills", Path.home() / ".agents/skills"):
        for pattern in ("*/SKILL.md", "*/*/SKILL.md"):
            entries.extend(
                f"{{path={json.dumps(str(p))},enabled=false}}"
                for p in base.glob(pattern)
            )
    path = root / ".agents/skills/ctb-data-contracts/SKILL.md"
    entries.append(f"{{path={json.dumps(str(path))},enabled={str(enabled).lower()}}}")
    cmd = [
        "codex",
        "exec",
        "--json",
        "--ephemeral",
        "--ignore-user-config",
        "--ignore-rules",
        "--skip-git-repo-check",
        "--sandbox",
        "workspace-write" if task else "read-only",
        "--cd",
        str(root),
        "-c",
        "project_doc_max_bytes=0",
        "-c",
        "skills.config=[" + ",".join(entries) + "]",
    ]
    for key, value in model_settings().items():
        cmd.extend(["-c", f"{key}={json.dumps(value)}"])
    return cmd


def activation(events):
    for line in events.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        item = event.get("item", {})
        if item.get("type") == "command_execution" and item.get("exit_code") == 0:
            command_text = item.get("command", "")
            if "SKILL.md" not in command_text or not re.search(
                r"\b(?:cat|sed|head|tail)\s|read_text|open\(", command_text
            ):
                continue
            output = item.get("aggregated_output", "")
            if (
                "name: ctb-data-contracts" in output
                and "# Manage CTB data contracts and products" in output
            ):
                return True
    return False


def grade(root, case_id, python):
    if case_id == "t01-generate":
        code = r"""
import re, sys, yaml
from pathlib import Path
from jsonschema import Draft202012Validator
root=Path(sys.argv[1]); load=lambda p: yaml.safe_load(p.read_text())
c=load(root/'output/daily-candles.odcs.yaml'); p=load(root/'output/daily-candles.odps.yaml')
for d,n in [(c,'odcs-v3.2.0.schema'),(p,'odps-v1.1.0.schema')]:
    Draft202012Validator(load(root/'standards'/n)).validate(d)
assert c['apiVersion']=='v3.2.0' and p['apiVersion']=='v1.1.0'
assert c['status']=='draft' and p['status']=='draft'
fields={f['name']:f for f in c['schema'][0]['properties']}
assert set(fields)=={'market','day_start','open','high','low','close','volume','observed_candles','missing_minutes','quality','freshness'}
for name in ['open','high','low','close','volume']:
    assert fields[name]['logicalType']=='number' and not fields[name].get('required',False)
    physical=fields[name]['physicalType'].replace(' ','').lower()
    assert re.fullmatch(r'decimal\((?:precision=38,scale=18|38,18)\)', physical)
t=fields['day_start']; assert t['logicalType']=='timestamp'
assert t['logicalTypeOptions']['timezone'] is True
assert t['logicalTypeOptions']['defaultTimezone'] in ['UTC','Etc/UTC']
assert 'ms' in t['physicalType']
for name,pos in [('market',1),('day_start',2)]:
    assert fields[name]['required'] and fields[name]['primaryKey'] and fields[name]['primaryKeyPosition']==pos
for name in ['observed_candles','missing_minutes']:
    assert fields[name]['logicalType']=='integer' and fields[name]['required']
    assert fields[name]['physicalType'].lower() in ['int64','bigint']
    assert fields[name]['logicalTypeOptions']['format']=='i64'
for name in ['market','quality','freshness']:
    assert fields[name]['logicalType']=='string' and fields[name]['required']
    assert fields[name]['physicalType'].lower() in ['string','text','varchar']
assert {v['value'] for v in fields['quality']['enum']}=={'valid','degraded'}
assert {v['value'] for v in fields['freshness']['enum']}=={'current','stale'}
assert p['outputPorts'][0]['contractId']==c['id']
def has_owner(document):
    team=document.get('team', {})
    return (isinstance(team,dict) and team.get('name')=='Evaluation Owner') or any(
        item.get('property')=='owner' and item.get('value')=='Evaluation Owner'
        for item in document.get('customProperties',[]))
assert has_owner(c) and has_owner(p)
assert not c.get('servers') and not c.get('slaProperties')
print('Independent descriptor assertions passed')
"""
        return helper(python, code, root).strip()
    review = json.loads((root / "output/review.json").read_text())
    if case_id == "t02-incompatible-change":
        assert (
            review["schema_valid"] is True
            and review["runtime_matches"] is False
            and review["breaking"] is True
        )
    else:
        assert review["environment_matches"] is False
        assert not list((root / "output").glob("*.yaml"))
    assert isinstance(review.get("reason"), str) and review["reason"].strip()
    return "Independent review assertions passed"


def run_one(job, workspace, python):
    lane, case, arm, attempt = job
    run = workspace / lane / case["id"] / arm / str(attempt)
    root = run / "workdir"
    fixture(root, python, case["id"], arm == "with_skill")
    before = snapshot(root)
    cmd = command(root, arm == "with_skill", lane == "task")
    prompt = (
        case["prompt"] + COMMON + f"\nThe available Python interpreter is {python}."
    )
    started = time.monotonic()
    try:
        response = subprocess.run(
            [*cmd, prompt],
            text=True,
            capture_output=True,
            timeout=240,
            env={**os.environ, "UV_OFFLINE": "1", "PYTHONDONTWRITEBYTECODE": "1"},
        )
        events, stderr, exit_code = (
            response.stdout,
            response.stderr,
            response.returncode,
        )
    except subprocess.TimeoutExpired as error:
        events = (
            (error.stdout or b"").decode()
            if isinstance(error.stdout, bytes)
            else error.stdout or ""
        )
        stderr, exit_code = "Model run timed out", 124
    (run / "events.jsonl").write_text(events)
    (run / "stderr.txt").write_text(stderr)
    used = activation(events)
    unchanged = before == snapshot(root)
    evidence = ""
    try:
        if lane == "task":
            evidence = grade(root, case["id"], python)
            passed = exit_code == 0 and unchanged
        else:
            passed = exit_code == 0 and unchanged and used == case["positive"]
    except (AssertionError, ValueError, OSError, KeyError) as error:
        passed, evidence = False, str(error) or "Outcome assertion failed"
    usage = None
    for line in events.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "turn.completed":
            usage = event.get("usage")
    result = {
        "lane": lane,
        "case": case["id"],
        "arm": arm,
        "attempt": attempt,
        "passed": passed,
        "activated": used,
        "should_activate": case.get("positive"),
        "protected_inputs_unchanged": unchanged,
        "exit_code": exit_code,
        "duration_seconds": round(time.monotonic() - started, 3),
        "usage": usage,
        "cost_usd": None,
        "evidence": evidence,
    }
    write_json(run / "result.json", result)
    print(json.dumps(result), flush=True)
    return result


def summarize(workspace):
    rows = [json.loads(path.read_text()) for path in workspace.glob("**/result.json")]

    def rate(items):
        return sum(row["passed"] for row in items) / len(items) if items else None

    positive = [r for r in rows if r["lane"] == "trigger" and r["should_activate"]]
    negative = [r for r in rows if r["lane"] == "trigger" and not r["should_activate"]]
    report = {
        "completed": len(rows),
        "positive_activation_recall": rate(positive),
        "negative_activation_specificity": rate(negative),
        "with_skill_task_success": rate(
            [r for r in rows if r["lane"] == "task" and r["arm"] == "with_skill"]
        ),
        "without_skill_task_success": rate(
            [r for r in rows if r["lane"] == "task" and r["arm"] == "without_skill"]
        ),
        "protected_fixture_mutations": sum(
            not r["protected_inputs_unchanged"] for r in rows
        ),
        "execution_failures": sum(r["exit_code"] != 0 for r in rows),
        "cost_usd": None,
    }
    report["per_case"] = {}
    for row in rows:
        key = f"{row['lane']}/{row['case']}/{row['arm']}"
        selected = [r for r in rows if f"{r['lane']}/{r['case']}/{r['arm']}" == key]
        report["per_case"][key] = {
            "attempts": len(selected),
            "passed": sum(r["passed"] for r in selected),
            "median_duration_seconds": stats.median(
                r["duration_seconds"] for r in selected
            ),
        }
    usage = [r["usage"] for r in rows if r["usage"]]
    report["token_usage"] = {
        key: sum(u.get(key, 0) for u in usage) if usage else None
        for key in ("input_tokens", "cached_input_tokens", "output_tokens")
    }
    write_json(workspace / "summary.json", report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "run", "summarize", "regrade"])
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--case", help="Run a single case for a pilot")
    parser.add_argument("--attempts", type=int, default=CASES["attempts"])
    parser.add_argument(
        "--yes", action="store_true", help="Authorize external model calls"
    )
    args = parser.parse_args()
    python = validators_python()
    jobs = [
        ("trigger", c, "with_skill", a)
        for c in CASES["trigger"]
        for a in range(1, args.attempts + 1)
    ]
    jobs += [
        ("task", c, arm, a)
        for c in CASES["task"]
        for arm in ["with_skill", "without_skill"]
        for a in range(1, args.attempts + 1)
    ]
    if args.case:
        jobs = [j for j in jobs if j[1]["id"] == args.case]
    args.workspace.mkdir(parents=True, exist_ok=True)
    if args.command == "prepare":
        write_json(
            args.workspace / "plan.json",
            {
                "runs": len(jobs),
                "attempts": args.attempts,
                "cases": CASES,
                "skill_revision": snapshot(SKILL),
                "python": str(python),
                "model_settings": model_settings(),
                "payload": "CTB skill, public Bitol schemas and synthetic fixtures; no real CTB datasets",
            },
        )
        for case in CASES["task"]:
            root = args.workspace / "fixtures" / case["id"]
            if not root.exists():
                fixture(root, python, case["id"], True)
        print(args.workspace / "plan.json")
    elif args.command == "regrade":
        rows = []
        for path in sorted(args.workspace.glob("**/result.json")):
            row = json.loads(path.read_text())
            row["original_passed"] = row["passed"]
            if row["lane"] == "task":
                try:
                    row["evidence"] = grade(
                        path.parent / "workdir", row["case"], python
                    )
                    row["passed"] = (
                        row["exit_code"] == 0 and row["protected_inputs_unchanged"]
                    )
                except (AssertionError, ValueError, OSError, KeyError) as error:
                    row["passed"], row["evidence"] = False, str(error)
            rows.append(row)
        write_json(
            args.workspace / "regraded-v2.json",
            {
                "reason": "Accept explicit ownership in either native team.name or valid customProperties.owner; independently audit all scalar physical types. Original run records are preserved.",
                "evaluator_sha256": hashlib.sha256(
                    Path(__file__).read_bytes()
                ).hexdigest(),
                "results": rows,
            },
        )
        print(args.workspace / "regraded-v2.json")
    elif args.command == "summarize":
        print(json.dumps(summarize(args.workspace), indent=2))
    else:
        if not args.yes:
            parser.error("run requires --yes after approval for external model calls")
        plan = json.loads((args.workspace / "plan.json").read_text())
        if plan["skill_revision"] != snapshot(SKILL):
            parser.error(
                "Skill changed since preparation; prepare a fresh plan before running"
            )
        if plan["model_settings"] != model_settings():
            parser.error(
                "Configured model changed; prepare a fresh plan before running"
            )
        jobs = [
            j
            for j in jobs
            if not (
                args.workspace / j[0] / j[1]["id"] / j[2] / str(j[3]) / "result.json"
            ).exists()
        ]
        with ThreadPoolExecutor(max_workers=3) as pool:
            futures = [pool.submit(run_one, j, args.workspace, python) for j in jobs]
            for future in as_completed(futures):
                future.result()
        print(json.dumps(summarize(args.workspace), indent=2))


if __name__ == "__main__":
    main()
