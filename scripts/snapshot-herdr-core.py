#!/usr/bin/env python3
"""Save readable copies of Wodan's Herdr core state."""

import json
import os
import tempfile
from pathlib import Path


def snapshot(source: Path, destination: Path) -> None:
    names = ("docs.json", "terminals.json")
    documents = {name: json.loads((source / name).read_text()) for name in names}
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    for name, document in documents.items():
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=destination, delete=False
        ) as output:
            temporary = Path(output.name)
            try:
                json.dump(document, output, indent=2, ensure_ascii=False)
                output.write("\n")
                output.flush()
                os.fsync(output.fileno())
            except BaseException:
                temporary.unlink(missing_ok=True)
                raise
        try:
            temporary.replace(destination / name)
        finally:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    state_home = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    snapshot(
        state_home / "herdr-core/default",
        state_home / "herdr-core-snapshots/wodan",
    )
    print("Herdr core snapshots updated.")
