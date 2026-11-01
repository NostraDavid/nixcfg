#!/usr/bin/env python3
"""Check readable Herdr snapshots and preserve them when input is invalid."""

import importlib.util
import json
import tempfile
from pathlib import Path

script = Path(__file__).resolve().parent.parent / "scripts/snapshot-herdr-core.py"
spec = importlib.util.spec_from_file_location("snapshot_herdr_core", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    source = root / "source"
    destination = root / "destination"
    source.mkdir()
    (source / "docs.json").write_text('{"tabs":["one"]}')
    (source / "terminals.json").write_text('{"terminals":[]}')
    module.snapshot(source, destination)
    for name in ("docs.json", "terminals.json"):
        result = (destination / name).read_text()
        assert json.loads(result) == json.loads((source / name).read_text())
        assert "\n  " in result
    before = (destination / "docs.json").read_bytes()
    (source / "docs.json").write_text('{"tabs":["two"]}')
    (source / "terminals.json").write_text("{invalid")
    try:
        module.snapshot(source, destination)
    except json.JSONDecodeError:
        pass
    else:
        raise AssertionError("Invalid source JSON was accepted")
    assert (destination / "docs.json").read_bytes() == before
print("Herdr snapshots are formatted and invalid input preserves the old copy.")
