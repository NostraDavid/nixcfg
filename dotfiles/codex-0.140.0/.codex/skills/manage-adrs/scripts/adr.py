#!/usr/bin/env python3
"""Manage Markdown Architecture Decision Records."""

from __future__ import annotations

import argparse
import datetime as dt
import re
from pathlib import Path


ADR_RE = re.compile(r"^(?P<num>\d{3,6})-(?P<slug>.+)\.md$")
TITLE_RE = re.compile(r"^#\s+(?:ADR\s+)?(?:(?P<num>\d{3,6}):\s*)?(?P<title>.+?)\s*$", re.I)
STATUS_RE = re.compile(r"^\s*[-*]?\s*Status\s*:\s*(?P<status>.+?)\s*$", re.I)
DATE_RE = re.compile(r"^\s*[-*]?\s*Date\s*:\s*(?P<date>\d{4}-\d{2}-\d{2})\s*$", re.I)

DEFAULT_DIRS = (
    "docs/adr",
    "doc/adr",
    "adr",
    "architecture/decisions",
    "docs/architecture/decisions",
)


def slugify(title: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return re.sub(r"-{2,}", "-", slug) or "decision"


def project_path(raw: str) -> Path:
    return Path(raw).expanduser().resolve()


def candidate_dirs(project: Path) -> list[Path]:
    dirs: list[Path] = []
    for rel in DEFAULT_DIRS:
        path = project / rel
        if path.exists():
            dirs.append(path)
    for path in project.rglob("*.md"):
        if ADR_RE.match(path.name):
            parent = path.parent
            if parent not in dirs:
                dirs.append(parent)
    return sorted(dirs)


def detect_dir(project: Path, explicit: str | None = None, create: bool = False) -> Path:
    if explicit:
        adr_dir = (project / explicit).resolve()
        if create:
            adr_dir.mkdir(parents=True, exist_ok=True)
        return adr_dir

    dirs = candidate_dirs(project)
    if dirs:
        return dirs[0]

    adr_dir = project / "docs" / "adr"
    if create:
        adr_dir.mkdir(parents=True, exist_ok=True)
    return adr_dir


def parse_adr(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    title = path.stem
    status = ""
    date = ""
    number = ""

    match = ADR_RE.match(path.name)
    if match:
        number = match.group("num")

    for line in text.splitlines():
        if not title or title == path.stem:
            title_match = TITLE_RE.match(line)
            if title_match:
                title = title_match.group("title").strip()
                number = number or (title_match.group("num") or "")
                continue
        status_match = STATUS_RE.match(line)
        if status_match and not status:
            status = status_match.group("status").strip()
            continue
        date_match = DATE_RE.match(line)
        if date_match and not date:
            date = date_match.group("date")

    return {
        "number": number,
        "title": title,
        "status": status or "Unknown",
        "date": date,
        "path": str(path),
    }


def adr_files(adr_dir: Path) -> list[Path]:
    return sorted(
        (path for path in adr_dir.glob("*.md") if ADR_RE.match(path.name)),
        key=lambda path: (ADR_RE.match(path.name).group("num"), path.name),  # type: ignore[union-attr]
    )


def next_number(adr_dir: Path) -> int:
    numbers = [int(ADR_RE.match(path.name).group("num")) for path in adr_files(adr_dir)]  # type: ignore[union-attr]
    return max(numbers, default=0) + 1


def render_adr(number: int, title: str, status: str, date: str) -> str:
    return f"""# ADR {number:04d}: {title}

- Status: {status}
- Date: {date}
- Deciders: TODO
- Supersedes: None
- Superseded by: None

## Context

TODO

## Decision

TODO

## Options Considered

TODO

## Consequences

TODO

## Notes

TODO
"""


def cmd_detect(args: argparse.Namespace) -> None:
    project = project_path(args.project)
    dirs = candidate_dirs(project)
    if dirs:
        for path in dirs:
            print(path.relative_to(project))
    else:
        print("docs/adr")


def cmd_new(args: argparse.Namespace) -> None:
    project = project_path(args.project)
    adr_dir = detect_dir(project, args.dir, create=True)
    number = args.number or next_number(adr_dir)
    filename = f"{number:04d}-{slugify(args.title)}.md"
    path = adr_dir / filename
    if path.exists() and not args.force:
        raise SystemExit(f"ADR already exists: {path}")
    date = args.date or dt.date.today().isoformat()
    path.write_text(render_adr(number, args.title, args.status, date), encoding="utf-8")
    print(path)


def cmd_list(args: argparse.Namespace) -> None:
    project = project_path(args.project)
    adr_dir = detect_dir(project, args.dir)
    for path in adr_files(adr_dir):
        adr = parse_adr(path)
        rel = Path(adr["path"]).relative_to(project)
        print(f"{adr['number']}\t{adr['status']}\t{adr['date']}\t{adr['title']}\t{rel}")


def index_text(project: Path, adr_dir: Path) -> str:
    rows = []
    for path in adr_files(adr_dir):
        adr = parse_adr(path)
        rel = path.name
        rows.append(f"| [{adr['number']}]({rel}) | {adr['title']} | {adr['status']} | {adr['date']} |")
    body = "\n".join(rows)
    if body:
        body += "\n"
    return f"""# Architecture Decision Records

| ADR | Title | Status | Date |
| --- | --- | --- | --- |
{body}"""


def cmd_index(args: argparse.Namespace) -> None:
    project = project_path(args.project)
    adr_dir = detect_dir(project, args.dir, create=True)
    path = adr_dir / (args.output or "README.md")
    path.write_text(index_text(project, adr_dir), encoding="utf-8")
    print(path)


def cmd_status(args: argparse.Namespace) -> None:
    project = project_path(args.project)
    adr_path = (project / args.adr).resolve()
    text = adr_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    changed = False
    for index, line in enumerate(lines):
        if STATUS_RE.match(line):
            prefix = "- " if line.lstrip().startswith(("-", "*")) else ""
            lines[index] = f"{prefix}Status: {args.status}"
            changed = True
            break
    if not changed:
        lines.insert(1, f"- Status: {args.status}")
    if args.superseded_by:
        lines.append("")
        lines.append(f"Superseded by: {args.superseded_by}")
    adr_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print(adr_path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    detect = sub.add_parser("detect", help="Print detected ADR directories")
    detect.add_argument("--project", default=".")
    detect.set_defaults(func=cmd_detect)

    new = sub.add_parser("new", help="Create a new ADR")
    new.add_argument("--project", default=".")
    new.add_argument("--dir", help="ADR directory relative to project root")
    new.add_argument("--title", required=True)
    new.add_argument("--status", default="Proposed")
    new.add_argument("--date")
    new.add_argument("--number", type=int)
    new.add_argument("--force", action="store_true")
    new.set_defaults(func=cmd_new)

    list_cmd = sub.add_parser("list", help="List ADRs")
    list_cmd.add_argument("--project", default=".")
    list_cmd.add_argument("--dir", help="ADR directory relative to project root")
    list_cmd.set_defaults(func=cmd_list)

    index = sub.add_parser("index", help="Regenerate ADR README index")
    index.add_argument("--project", default=".")
    index.add_argument("--dir", help="ADR directory relative to project root")
    index.add_argument("--output", help="Index filename inside the ADR directory")
    index.set_defaults(func=cmd_index)

    status = sub.add_parser("status", help="Update ADR status line")
    status.add_argument("--project", default=".")
    status.add_argument("--adr", required=True, help="ADR path relative to project root")
    status.add_argument("--status", required=True)
    status.add_argument("--superseded-by")
    status.set_defaults(func=cmd_status)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
