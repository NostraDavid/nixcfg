"""Read VS Code settings while accepting trailing commas."""

import json
import re
from pathlib import Path


def read_settings(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    content = path.read_text(encoding="utf-8")
    content = re.sub(
        r'("(?:\\.|[^"\\])*")|,(?=\s*[}\]])',
        lambda match: match.group(1) or "",
        content,
    )
    settings = json.loads(content)
    if not isinstance(settings, dict):
        raise ValueError(f"expected a JSON object in {path}")
    return settings
