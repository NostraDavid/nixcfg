"""Apply curated descriptions during skill builds and Home Manager activation."""

import json
import os
import sys
import tempfile
from pathlib import Path

import yaml


def rewrite(text, descriptions):
    if not text.startswith("---\n"):
        return text
    front, body = text[4:].split("\n---", 1)
    metadata = yaml.safe_load(front)
    if not isinstance(metadata, dict) or metadata.get("name") not in descriptions:
        return text
    description = descriptions[metadata["name"]]
    if metadata.get("description") == description:
        return text
    node = next(
        value for key, value in yaml.compose(front).value if key.value == "description"
    )
    start, end = node.start_mark.index, node.end_mark.index
    value = json.dumps(description, ensure_ascii=False)
    if front[start:end].endswith("\n"):
        value += "\n"
    return "---\n" + front[:start] + value + front[end:] + "\n---" + body


def main():
    descriptions = json.loads(Path(sys.argv[1]).read_text())["descriptions"]
    changed = 0
    for directory in sys.argv[2:]:
        for path in Path(directory).rglob("SKILL.md"):
            text = path.read_text()
            updated = rewrite(text, descriptions)
            if updated != text:
                # Codex installs marketplace plugin files read-only; replacing
                # the file through its writable parent avoids changing modes.
                fd, temporary = tempfile.mkstemp(dir=path.parent)
                try:
                    with os.fdopen(fd, "w") as stream:
                        stream.write(updated)
                    os.replace(temporary, path)
                finally:
                    if os.path.exists(temporary):
                        os.unlink(temporary)
                changed += 1
    print(f"Updated {changed} skill descriptions")


if __name__ == "__main__":
    main()
