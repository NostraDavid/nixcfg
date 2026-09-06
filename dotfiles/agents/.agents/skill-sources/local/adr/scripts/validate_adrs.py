#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.5.0",
#     "markdown-it-py==4.2.0",
#     "orjson==3.12.0",
#     "pydantic==2.13.5",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "pyyaml==6.0.3",
#     "structlog==26.1.0",
# ]
# ///

"""Validate Markdown architectural decision records and their relationships."""

import contextlib
import datetime as dt
import io
import os
import re
import subprocess as sp
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import click
import orjson as json
import pytest
import structlog as sl
import structlog.stdlib as log
import yaml
from click.testing import CliRunner
from markdown_it import MarkdownIt
from markdown_it.token import Token
from pydantic import BaseModel, ConfigDict, Field, ValidationError, field_validator

logger = log.get_logger(__name__)
ID_PATTERN = r"ADR-(OP|SYS|TRS|CM)-(?!0000)[0-9]{4}"
SECTIONS = (
    "Context and Problem Statement",
    "Decision Outcome",
    "Participants",
    "Consequences",
    "Decision Drivers",
    "Considered Options",
    "More Information",
)
FINAL = {"ACCEPTED", "REJECTED", "DEPRECATED", "SUPERSEDED"}
RELATIONS = ("supersedes", "superseded_by", "related")
PLACEHOLDER = re.compile(r"\b(?:TODO|TBD|FIXME)\b|<[^>\n]+>|\{[^}\n]+\}", re.IGNORECASE)


class InputError(Exception):
    """An input cannot be interpreted as an ADR."""


class Metadata(BaseModel):
    model_config = ConfigDict(
        extra="forbid", strict=True, frozen=True, regex_engine="python-re"
    )
    id: str = Field(pattern=f"^{ID_PATTERN}$")
    title: str = Field(min_length=1)
    status: Literal[
        "DRAFT", "PROPOSED", "ACCEPTED", "REJECTED", "DEPRECATED", "SUPERSEDED"
    ]
    domain: Literal["OP", "SYS", "TRS", "CM"]
    system: str | None
    owner: str = Field(min_length=1)
    decider: str = Field(min_length=1)
    decision_date: dt.date | None
    last_reviewed_date: dt.date | None
    supersedes: list[str] = Field(default_factory=list)
    superseded_by: list[str] = Field(default_factory=list)
    related: list[str] = Field(default_factory=list)

    @field_validator("title", "owner", "decider", "system")
    @classmethod
    def nonempty_text(cls, value: str | None) -> str | None:
        if isinstance(value, str) and not value.strip():
            raise ValueError("text must not be blank")
        return value

    @field_validator("decision_date", "last_reviewed_date", mode="before")
    @classmethod
    def iso_date(cls, value: object) -> object:
        if isinstance(value, str):
            if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value):
                raise ValueError("expected ISO YYYY-MM-DD date or null")
            return dt.date.fromisoformat(value)
        if isinstance(value, dt.datetime):
            raise ValueError("timestamps are not dates")  # noqa: TRY004 - Pydantic requires ValueError.
        return value


@dataclass(frozen=True)
class Issue:
    path: str
    code: str
    message: str
    severity: str = "error"

    def as_dict(self) -> dict[str, str]:
        return {
            "path": self.path,
            "code": self.code,
            "message": self.message,
            "severity": self.severity,
        }


@dataclass(frozen=True)
class Document:
    path: Path
    metadata: Metadata


def parse_frontmatter(source: str) -> tuple[Metadata, str]:
    lines = source.lstrip("\ufeff").splitlines()
    if not lines or lines[0] != "---":
        raise InputError("document must start with YAML front matter delimited by ---")
    try:
        end = lines.index("---", 1)
    except ValueError as error:
        raise InputError("missing closing YAML delimiter") from error
    header = "\n".join(lines[1:end])
    try:
        for token in yaml.scan(header):
            if isinstance(token, (yaml.AliasToken, yaml.AnchorToken)):
                raise InputError("YAML anchors and aliases are not supported")
        node = yaml.compose(header, Loader=yaml.SafeLoader)
        if not isinstance(node, yaml.MappingNode):
            raise InputError("front matter must be a mapping")
        keys: set[str] = set()
        for key, _ in node.value:
            if (
                not isinstance(key, yaml.ScalarNode)
                or key.tag != "tag:yaml.org,2002:str"
            ):
                raise InputError("metadata keys must be strings")
            if key.value in keys:
                raise InputError(f"duplicate YAML key: {key.value}")
            keys.add(key.value)
        metadata = Metadata.model_validate(yaml.safe_load(header))
    except (yaml.YAMLError, ValidationError, ValueError) as error:
        raise InputError(str(error)) from error
    return metadata, "\n".join(lines[end + 1 :])


def markdown_tokens(body: str) -> list[Token]:
    return MarkdownIt("commonmark").enable("table").parse(body)


def inline_text(token: Token) -> str:
    return "".join(
        child.content
        for child in token.children or []
        if child.type in {"text", "code_inline", "softbreak", "hardbreak"}
    )


def headings(tokens: list[Token]) -> list[tuple[int, str, int]]:
    return [
        (int(token.tag[1:]), inline_text(tokens[i + 1]), i)
        for i, token in enumerate(tokens)
        if token.type == "heading_open" and token.level == 0
    ]


def prose(tokens: list[Token]) -> str:
    return " ".join(
        inline_text(t)
        for i, t in enumerate(tokens)
        if t.type == "inline" and (i == 0 or tokens[i - 1].type != "heading_open")
    )


def contains_placeholders(tokens: list[Token]) -> bool:
    """Treat code-span parameters as examples, while still reporting explicit TODOs."""
    return any(
        re.search(r"\b(?:TODO|TBD|FIXME)\b", child.content, re.IGNORECASE)
        if child.type == "code_inline"
        else PLACEHOLDER.search(child.content)
        for token in tokens
        if token.type == "inline"
        for child in token.children or []
        if child.type in {"text", "code_inline"}
    )


def table_rows(tokens: list[Token]) -> list[list[list[str]]]:
    tables: list[list[list[str]]] = []
    for i, token in enumerate(tokens):
        if token.type == "table_open":
            tables.append([])
        elif token.type == "tr_open" and tables:
            tables[-1].append([])
        elif token.type in {"th_open", "td_open"} and tables and tables[-1]:
            tables[-1][-1].append(inline_text(tokens[i + 1]))
    return tables


def validate_document(
    path: Path, source: str, strict: bool, today: dt.date
) -> tuple[Document | None, list[Issue]]:
    issues: list[Issue] = []
    try:
        meta, body = parse_frontmatter(source)
    except InputError as error:
        return None, [Issue(str(path), "metadata", str(error))]

    def report(code: str, message: str, incomplete: bool = False) -> None:
        severity = (
            "warning"
            if incomplete and not strict and meta.status not in FINAL
            else "error"
        )
        issues.append(Issue(str(path), code, message, severity))

    if meta.id.split("-")[1] != meta.domain:
        report("domain", "ID domain must match domain metadata")
    if not re.fullmatch(
        re.escape(meta.id) + r"-[a-z0-9]+(?:-[a-z0-9]+)*\.md", path.name
    ):
        report("filename", "expected ID-lowercase-slug.md matching metadata")
    for key in ("title", "owner", "decider", "system"):
        value = getattr(meta, key)
        if isinstance(value, str) and (not value.strip() or PLACEHOLDER.search(value)):
            report("incomplete", f"{key} is blank or contains a placeholder", True)
    if (
        meta.status in {"ACCEPTED", "DEPRECATED", "SUPERSEDED"}
        and meta.decision_date is None
    ):
        report("date", "this status requires decision_date")
    for value in (meta.decision_date, meta.last_reviewed_date):
        if value and value > today:
            report("date", "dates cannot be in the future")
    if (
        meta.decision_date
        and meta.last_reviewed_date
        and meta.last_reviewed_date < meta.decision_date
    ):
        report("date", "last_reviewed_date precedes decision_date")
    if (meta.status == "SUPERSEDED") != bool(meta.superseded_by):
        report(
            "supersession", "SUPERSEDED status requires superseded_by and vice versa"
        )
    if meta.supersedes and meta.status not in {"ACCEPTED", "DEPRECATED", "SUPERSEDED"}:
        report("supersession", "only an adopted decision can supersede another ADR")
    for relation in RELATIONS:
        refs: list[str] = getattr(meta, relation)
        if len(set(refs)) != len(refs):
            report("reference", f"duplicate IDs in {relation}")
        for reference in refs:
            if not re.fullmatch(ID_PATTERN, reference) or reference == meta.id:
                report(
                    "reference", f"invalid or self reference in {relation}: {reference}"
                )
    tokens = markdown_tokens(body)
    hs = headings(tokens)
    if (
        [title for level, title, _ in hs if level == 1] != [meta.title]
        or not hs
        or hs[0][0] != 1
    ):
        report("title", "exactly one initial H1 must match the YAML title")
    top = [(title, index) for level, title, index in hs if level == 2]
    if [title for title, _ in top] != list(SECTIONS):
        report(
            "sections", "H2 sections must occur exactly once in the documented order"
        )
    first_h2 = top[0][1] if top else len(tokens)
    preamble = tokens[hs[0][2] + 3 : first_h2] if hs else []
    displayed = [
        t
        for t in preamble
        if t.type == "inline" and t.level == 1 and t.content == f"`{meta.id}`"
    ]
    code_ids = [
        child.content
        for t in preamble
        for child in t.children or []
        if child.type == "code_inline" and child.content.startswith("ADR-")
    ]
    if len(displayed) != 1 or code_ids != [meta.id]:
        report(
            "id",
            "display the ADR ID as a standalone inline-code paragraph before the first section",
        )
    sections: dict[str, list[Token]] = {}
    for number, (title, start) in enumerate(top):
        end = top[number + 1][1] if number + 1 < len(top) else len(tokens)
        sections[title] = tokens[start + 3 : end]
    for title, section in sections.items():
        text = prose(section)
        if not text.strip() or contains_placeholders(section):
            report("incomplete", f"{title} is empty or contains placeholders", True)
    consequences = sections.get("Consequences", [])
    consequence_heads = headings(consequences)
    if [(level, title) for level, title, _ in consequence_heads] != [
        (3, t) for t in ("Positive", "Negative", "Neutral")
    ]:
        report("consequences", "use H3 Positive, Negative and Neutral in order")
    for n, (_, title, start) in enumerate(consequence_heads):
        end = (
            consequence_heads[n + 1][2]
            if n + 1 < len(consequence_heads)
            else len(consequences)
        )
        if not prose(consequences[start + 3 : end]).strip():
            report("incomplete", f"Consequence {title} needs content", True)
    drivers = table_rows(sections.get("Decision Drivers", []))
    if (
        len(drivers) != 1
        or not drivers[0]
        or drivers[0][0] != ["Driver", "Relative weight", "Description"]
    ):
        report("drivers", "requires one Driver | Relative weight | Description table")
    elif len(drivers[0]) < 2 or any(
        len(row) != 3 or row[1] not in {"High", "Medium", "Low"}
        for row in drivers[0][1:]
    ):
        report("drivers", "provide at least one driver with High, Medium or Low weight")
    elif any(not cell.strip() for row in drivers[0][1:] for cell in row):
        report("incomplete", "driver table contains empty cells", True)
    options_section = sections.get("Considered Options", [])
    tables = table_rows(options_section)
    options: list[str] = []
    if len(tables) != 1 or not tables[0] or tables[0][0] != ["Option", "Summary"]:
        report("options", "requires one Option | Summary table")
    else:
        options = [row[0] for row in tables[0][1:]]
        if (
            len(options) < 2
            or len(set(options)) != len(options)
            or any(not o.strip() for o in options)
        ):
            report("options", "provide at least two distinct named options")
        if any(not cell.strip() for row in tables[0][1:] for cell in row):
            report("incomplete", "option table contains empty cells", True)
    expected = [(3, "Pros and Cons of the Options")]
    for option in options:
        expected.extend([(4, option), (5, "Pros and Cons")])
    option_heads = headings(options_section)
    if [(level, title) for level, title, _ in option_heads] != expected:
        report(
            "options",
            "option H4 titles and H5 Pros and Cons must match the table in order",
        )
    for n, (level, title, start) in enumerate(option_heads):
        end = (
            option_heads[n + 1][2]
            if n + 1 < len(option_heads)
            else len(options_section)
        )
        detail = options_section[start + 3 : end]
        if level == 4 and not prose(detail).strip():
            report("incomplete", f"{title} needs a description", True)
        if level == 5:
            items = [
                inline_text(detail[i + 2])
                for i, t in enumerate(detail)
                if t.type == "list_item_open" and i + 2 < len(detail)
            ]
            if any(
                not any(
                    item.startswith(label + ",") and item[len(label) + 1 :].strip()
                    for item in items
                )
                for label in ("Good", "Neutral", "Bad")
            ):
                report(
                    "incomplete",
                    "each option needs Good, Neutral and Bad because observations",
                    True,
                )
    outcome = sections.get("Decision Outcome", [])
    paragraphs = [inline_text(t) for t in outcome if t.type == "inline"]
    chosen = [
        text.removeprefix("Chosen option:").strip()
        for text in paragraphs
        if text.startswith("Chosen option:")
    ]
    if len(chosen) != 1:
        report("outcome", "provide exactly one Chosen option: paragraph")
    elif chosen[0] not in options:
        if chosen[0] == "Undecided" and meta.status in {"DRAFT", "PROPOSED"}:
            report("incomplete", "decision is still undecided", True)
        else:
            report("outcome", "chosen option must match an option table label")
    if not any(
        text.strip() and not text.startswith("Chosen option:") for text in paragraphs
    ):
        report("incomplete", "Decision Outcome needs a justification", True)
    return Document(path, meta), issues


def validate_relationships(documents: list[Document]) -> list[Issue]:
    issues: list[Issue] = []
    by_id: dict[str, Document] = {}
    for document in documents:
        identifier = document.metadata.id
        if identifier in by_id:
            issues.append(
                Issue(str(document.path), "duplicate-id", f"duplicate ID: {identifier}")
            )
        by_id[identifier] = document
    for document in documents:
        meta = document.metadata
        for relation in RELATIONS:
            for reference in getattr(meta, relation):
                target = by_id.get(reference)
                if target is None:
                    issues.append(
                        Issue(
                            str(document.path),
                            "missing-reference",
                            f"{relation}: missing {reference}",
                        )
                    )
                elif relation != "related":
                    opposite = (
                        "superseded_by" if relation == "supersedes" else "supersedes"
                    )
                    if meta.id not in getattr(target.metadata, opposite):
                        issues.append(
                            Issue(
                                str(document.path),
                                "reciprocity",
                                f"{reference} must declare {opposite}: {meta.id}",
                            )
                        )
                    if (
                        relation == "supersedes"
                        and meta.decision_date
                        and target.metadata.decision_date
                        and meta.decision_date < target.metadata.decision_date
                    ):
                        issues.append(
                            Issue(
                                str(document.path),
                                "chronology",
                                "replacement predates superseded ADR",
                            )
                        )
    for origin, document in by_id.items():
        pending = list(document.metadata.supersedes)
        seen: set[str] = set()
        while pending:
            identifier = pending.pop()
            if identifier == origin:
                issues.append(Issue(str(document.path), "cycle", "supersession cycle"))
                break
            if identifier in by_id and identifier not in seen:
                seen.add(identifier)
                pending.extend(by_id[identifier].metadata.supersedes)
    return issues


def validate_paths(
    target: Path, strict: bool, today: dt.date
) -> tuple[int, list[Issue]]:
    paths = (
        sorted(
            p
            for p in target.rglob("*.md")
            if p.name.lower() not in {"readme.md", "index.md"}
        )
        if target.is_dir()
        else [target]
    )
    if not paths:
        raise InputError("no ADR Markdown files found")
    documents: list[Document] = []
    issues: list[Issue] = []
    for path in paths:
        if path.is_symlink():
            issues.append(
                Issue(str(path), "read", "symlinked ADR files are not supported")
            )
            continue
        try:
            source = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            issues.append(Issue(str(path), "read", str(error)))
            continue
        document, found = validate_document(path, source, strict, today)
        issues.extend(found)
        if document:
            documents.append(document)
    issues.extend(validate_relationships(documents))
    return len(paths), issues


def configure_logging() -> None:
    sl.configure(
        processors=[
            sl.processors.TimeStamper(fmt="iso", utc=True),
            sl.processors.add_log_level,
            sl.dev.ConsoleRenderer(colors=sys.stderr.isatty()),
        ],
        wrapper_class=sl.make_filtering_bound_logger("debug"),
        logger_factory=sl.PrintLoggerFactory(file=sys.stderr),
        cache_logger_on_first_use=False,
    )


@click.group()
def cli() -> None:
    """Validate ADR content and collection relationships without modifying files."""
    configure_logging()


@cli.command()
@click.argument("target", type=click.Path(exists=True, path_type=Path))
@click.option(
    "--strict", is_flag=True, help="Treat unfinished draft content as errors."
)
@click.option(
    "--format",
    "output_format",
    type=click.Choice(["text", "json"]),
    default="text",
    show_default=True,
)
def validate(target: Path, strict: bool, output_format: str) -> None:
    """Check a dedicated ADR directory recursively, or a single Markdown file."""
    try:
        count, issues = validate_paths(target, strict, dt.datetime.now(dt.UTC).date())
    except (InputError, OSError) as error:
        raise click.ClickException(str(error)) from error
    errors = sum(issue.severity == "error" for issue in issues)
    warnings = len(issues) - errors
    if output_format == "json":
        click.echo(
            json.dumps(
                {
                    "files": count,
                    "errors": errors,
                    "warnings": warnings,
                    "issues": [issue.as_dict() for issue in issues],
                }
            ).decode()
        )
    else:
        for issue in issues:
            click.echo(
                f"{issue.path}: {issue.severity} [{issue.code}] {issue.message}",
                err=True,
            )
        click.echo(f"{count} ADR(s): {errors} error(s), {warnings} warning(s)")
    if errors:
        raise click.exceptions.Exit(1)


@cli.command(name="check")
def check_command() -> None:
    """Probe required parsers; no external services or setup are required."""
    if yaml.safe_load("ready: true") != {"ready": True} or not markdown_tokens(
        "# Ready"
    ):
        raise click.ClickException("required parsers failed the readiness probe")
    click.echo("ok")


def compact_pytest_output(output: str) -> str:
    """Remove pytest-cov banners while preserving its useful report."""
    lines = []
    for line in output.splitlines():
        is_section_banner = (
            line.startswith("=") and line.endswith("=") and " tests coverage " in line
        )
        is_platform_banner = (
            line.startswith("_")
            and line.endswith("_")
            and " coverage: platform " in line
        )
        if not is_section_banner and not is_platform_banner:
            lines.append(line)
    return "\n".join(lines).strip() + "\n"


@click.command(name="unit-test")
def _embedded_unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="python-cli-coverage-") as directory:
        coverage_config = Path(directory) / ".coveragerc"
        coverage_config.write_text(
            os.linesep.join(
                (
                    "[run]",
                    "patch = subprocess",
                    "include =",
                    f"    {Path(__file__).resolve().as_posix()}",
                    "",
                )
            ),
            encoding="utf-8",
        )
        previous_coverage_file = os.environ.get("COVERAGE_FILE")
        os.environ["COVERAGE_FILE"] = str(Path(directory) / ".coverage")
        pytest_output = io.StringIO()
        try:
            with contextlib.redirect_stdout(pytest_output):
                result = pytest.main(
                    [
                        "--cov",
                        "--cov-branch",
                        "--cov-config",
                        str(coverage_config),
                        "--cov-report=term-missing",
                        "-p",
                        "no:cacheprovider",
                        __file__,
                        "-q",
                    ]
                )
        finally:
            if previous_coverage_file is None:
                os.environ.pop("COVERAGE_FILE", None)
            else:
                os.environ["COVERAGE_FILE"] = previous_coverage_file
    click.echo(compact_pytest_output(pytest_output.getvalue()), nl=False)
    raise SystemExit(result)


cli.add_command(_embedded_unit_test_command)


SAMPLE = "---\nid: ADR-SYS-0001\ntitle: Use PostgreSQL for orders\nstatus: ACCEPTED\ndomain: SYS\nsystem: Orders\nowner: Orders team\ndecider: Architecture group\ndecision_date: 2026-01-15\nlast_reviewed_date: 2026-01-16\nsupersedes: []\nsuperseded_by: []\nrelated: []\n---\n\n# Use PostgreSQL for orders\n\n`ADR-SYS-0001`\n\n## Context and Problem Statement\n\nThe orders service needs transactions across orders and their line items. The\nteam already operates PostgreSQL and has no production document-store support.\n\n## Decision Outcome\n\n**Chosen option:** PostgreSQL\n\nUse PostgreSQL because it provides the required transaction model and matches\nthe team's operational experience. These drivers outweigh flexible documents.\n\n## Participants\n\nThe orders team operates the service; the architecture group approves this\ndecision and customer support depends on consistent order records.\n\n## Consequences\n\n### Positive\n\nOrders and line items can be committed together using existing operational skills.\n\n### Negative\n\nSchema migrations require coordination with application releases.\n\n### Neutral\n\nThe team continues to own backup and restore exercises.\n\n## Decision Drivers\n\n| Driver | Relative weight | Description |\n| --- | --- | --- |\n| Consistency | High | Orders and line items must commit together. |\n| Operations | Medium | Reuse database skills already held by the team. |\n\n## Considered Options\n\n| Option | Summary |\n| --- | --- |\n| PostgreSQL | Relational storage with transactions and explicit schema. |\n| Document store | Flexible order documents in a separately operated database. |\n\n### Pros and Cons of the Options\n\n#### PostgreSQL\n\nSelected because transactions and operational familiarity match both drivers.\n\n##### Pros and Cons\n\n- Good, because the team can operate the transaction model.\n- Neutral, because backup ownership remains with the orders team.\n- Bad, because schema changes need release coordination.\n\n#### Document store\n\nRejected because a new operational stack does not address a demonstrated need.\n\n##### Pros and Cons\n\n- Good, because individual order shapes can evolve independently.\n- Neutral, because backup ownership would still remain with the orders team.\n- Bad, because the team would need a new operational capability.\n\n## More Information\n\nThis is synthetic evaluation data, not a real approval. Revisit if order access\npatterns change enough that relational constraints no longer fit."


def check_sample(source: str, strict: bool = False) -> list[Issue]:
    return validate_document(
        Path("ADR-SYS-0001-use-postgresql.md"), source, strict, dt.date(2026, 9, 6)
    )[1]


def test_complete_document() -> None:
    assert check_sample(SAMPLE) == []


@pytest.mark.parametrize(
    "change",
    [
        "id: ADR-SYS-0002\nid: ADR-SYS-0001",
        "id: !!python/object:os.system {}",
        "id: &ref ADR-SYS-0001",
        "id: [ADR-SYS-0001]",
        "id: ADR-SYS-0000",
    ],
)
def test_yaml_rejected(change: str) -> None:
    assert any(
        i.code == "metadata"
        for i in check_sample(SAMPLE.replace("id: ADR-SYS-0001", change))
    )


def test_comments_and_fences() -> None:
    assert (
        check_sample(
            SAMPLE + "\n\n<!-- TODO\n## Fake -->\n\n~~~markdown\n## Fake\nTODO\n~~~\n"
        )
        == []
    )


def test_inline_code_examples_are_not_unfinished_content() -> None:
    source = (
        SAMPLE
        + "\nUse `codex/<task>` and `/items/{id}` as documented naming patterns.\n"
    )
    assert check_sample(source, True) == []
    assert any(
        i.code == "incomplete"
        for i in check_sample(SAMPLE + "\nResolve `TODO` before approval.\n")
    )
    assert any(
        i.code == "incomplete"
        for i in check_sample(SAMPLE + "\nResolve {decision} before approval.\n")
    )


def test_draft_strictness() -> None:
    draft = SAMPLE.replace("status: ACCEPTED", "status: DRAFT") + "\nTODO\n"
    assert [i.severity for i in check_sample(draft)] == ["warning"]
    assert [i.severity for i in check_sample(draft, True)] == ["error"]


def test_structure() -> None:
    assert check_sample(SAMPLE.replace("## Participants", "## People"))
    assert check_sample(SAMPLE.replace("### Positive", "### Benefits"))


def test_collection(tmp_path: Path) -> None:
    first = parse_frontmatter(SAMPLE)[0]
    old = first.model_copy(
        update={"status": "SUPERSEDED", "superseded_by": ["ADR-SYS-0002"]}
    )
    new = first.model_copy(
        update={"id": "ADR-SYS-0002", "supersedes": ["ADR-SYS-0001"]}
    )
    docs = [Document(tmp_path / "old.md", old), Document(tmp_path / "new.md", new)]
    assert validate_relationships(docs) == []
    assert any(i.code == "missing-reference" for i in validate_relationships(docs[:1]))
    assert any(
        i.code == "duplicate-id" for i in validate_relationships(docs + docs[:1])
    )
    cycle = new.model_copy(update={"superseded_by": ["ADR-SYS-0001"]})
    old_cycle = old.model_copy(update={"supersedes": ["ADR-SYS-0002"]})
    assert any(
        i.code == "cycle"
        for i in validate_relationships(
            [Document(tmp_path, cycle), Document(tmp_path, old_cycle)]
        )
    )


def test_cli(tmp_path: Path) -> None:
    runner = CliRunner()
    assert runner.invoke(cli, ["check"]).stdout == "ok\n"
    assert "unit-test" in runner.invoke(cli, ["--help"]).stdout
    target = tmp_path / "ADR-SYS-0001-use-postgresql.md"
    target.write_text(SAMPLE)
    before = target.read_bytes()
    result = runner.invoke(
        cli, ["validate", str(tmp_path), "--strict", "--format", "json"]
    )
    assert result.exit_code == 0, result.output
    assert json.loads(result.stdout)["errors"] == 0
    assert target.read_bytes() == before
    target.write_text("invalid")
    result = runner.invoke(cli, ["validate", str(tmp_path)])
    assert result.exit_code == 1
    assert "[metadata]" in result.stderr
    assert runner.invoke(cli, ["validate", str(tmp_path / "missing")]).exit_code == 2


def test_empty_collection(tmp_path: Path) -> None:
    (tmp_path / "README.md").write_text("# Collection")
    assert CliRunner().invoke(cli, ["validate", str(tmp_path)]).exit_code == 1


def test_entrypoint() -> None:
    result = sp.run(
        [sys.executable, __file__, "check"],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    assert result.returncode == 0
    assert result.stdout == "ok\n"


@pytest.mark.parametrize(
    "old,new,code",
    [
        ("owner: Orders team", "owner: false", "metadata"),
        ("system: Orders", "system: Orders\nunknown: true", "metadata"),
        ("decision_date: 2026-01-15", "decision_date: 2026-02-30", "metadata"),
        ("decision_date: 2026-01-15", "decision_date: null", "date"),
        ("decision_date: 2026-01-15", "decision_date: 2099-01-01", "date"),
        ("last_reviewed_date: 2026-01-16", "last_reviewed_date: 2025-01-01", "date"),
        ("domain: SYS", "domain: OP", "domain"),
        ("related: []", "related: [ADR-SYS-0001]", "reference"),
        ("related: []", "related: [ADR-SYS-0002, ADR-SYS-0002]", "reference"),
        ("## Participants", "> ## Participants", "sections"),
        ("#### PostgreSQL", "#### Different", "options"),
        ("**Chosen option:** PostgreSQL", "**Chosen option:** Missing", "outcome"),
        ("| Consistency | High", "| Consistency | 10", "drivers"),
    ],
)
def test_invalid_invariants(old: str, new: str, code: str) -> None:
    assert any(i.code == code for i in check_sample(SAMPLE.replace(old, new)))


def test_complex_yaml_key() -> None:
    assert (
        check_sample(SAMPLE.replace("system: Orders", "? [a, b]\n: invalid"))[0].code
        == "metadata"
    )


def test_readiness_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(yaml, "safe_load", lambda source: None)
    result = CliRunner().invoke(cli, ["check"])
    assert result.exit_code == 1
    assert result.stdout == ""


def test_symlink_rejected(tmp_path: Path) -> None:
    source = tmp_path / "source.txt"
    source.write_text(SAMPLE, encoding="utf-8")
    (tmp_path / "ADR-SYS-0001-use-postgresql.md").symlink_to(source)
    assert validate_paths(tmp_path, False, dt.date(2026, 9, 6))[1][0].code == "read"


@pytest.mark.parametrize(
    "old,new",
    [
        ("owner: Orders team", 'owner: "   "'),
        ("system: Orders", 'system: ""'),
        ("system: Orders\n", ""),
        ("related: []", "related: false"),
        (
            "| PostgreSQL | Relational storage with transactions and explicit schema. |",
            "| PostgreSQL | |",
        ),
    ],
)
def test_schema_and_empty_cells(old: str, new: str) -> None:
    assert check_sample(SAMPLE.replace(old, new))


def test_quoted_dates_and_escaped_pipe() -> None:
    source = SAMPLE.replace("2026-01-15", '"2026-01-15"').replace(
        "Relational storage with transactions and explicit schema.",
        "Transactions \\| explicit schema.",
    )
    assert check_sample(source) == []


def test_relationship_reciprocity_and_chronology() -> None:
    first = parse_frontmatter(SAMPLE)[0]
    old = first.model_copy(
        update={"status": "SUPERSEDED", "superseded_by": ["ADR-SYS-0002"]}
    )
    new = first.model_copy(
        update={
            "id": "ADR-SYS-0002",
            "decision_date": dt.date(2025, 1, 1),
            "supersedes": ["ADR-SYS-0001"],
        }
    )
    docs = [Document(Path("old.md"), old), Document(Path("new.md"), new)]
    assert any(i.code == "chronology" for i in validate_relationships(docs))
    docs[1] = Document(Path("new.md"), new.model_copy(update={"supersedes": []}))
    assert any(i.code == "reciprocity" for i in validate_relationships(docs))


def test_template_snapshot() -> None:
    source = '---\nid: ADR-SYS-0001\ntitle: "TODO: Decision title"\nstatus: DRAFT\ndomain: SYS\nsystem: null\nowner: "TODO: Content owner"\ndecider: "TODO: Approver"\ndecision_date: null\nlast_reviewed_date: null\nsupersedes: []\nsuperseded_by: []\nrelated: []\n---\n\n# TODO: Decision title\n\n`ADR-SYS-0001`\n\n## Context and Problem Statement\n\nTODO: Describe the problem, constraints, and evidence that require this decision.\n\n## Decision Outcome\n\n**Chosen option:** Undecided\n\nTODO: State the decision and connect its rationale to the decision drivers.\n\n## Participants\n\nTODO: Identify affected architects, teams, and business stakeholders.\n\n## Consequences\n\n### Positive\n\nTODO: Explain benefits or state why none are known.\n\n### Negative\n\nTODO: Explain costs, risks, and mitigations or state why none are known.\n\n### Neutral\n\nTODO: Explain other effects or state why none are known.\n\n## Decision Drivers\n\n| Driver | Relative weight | Description |\n| --- | --- | --- |\n| TODO: Driver | High | TODO: Explain this constraint and its evidence. |\n\n## Considered Options\n\n| Option | Summary |\n| --- | --- |\n| Option A | TODO: Describe the first genuine option. |\n| Option B | TODO: Describe an alternative, including status quo if viable. |\n\n### Pros and Cons of the Options\n\n#### Option A\n\nTODO: Describe the option and why it was selected or rejected.\n\n##### Pros and Cons\n\n- Good, because TODO: explain a benefit.\n- Neutral, because TODO: explain an effect or why none is known.\n- Bad, because TODO: explain a drawback.\n\n#### Option B\n\nTODO: Describe the option and why it was selected or rejected.\n\n##### Pros and Cons\n\n- Good, because TODO: explain a benefit.\n- Neutral, because TODO: explain an effect or why none is known.\n- Bad, because TODO: explain a drawback.\n\n## More Information\n\nTODO: Link evidence, related records, and any revisit trigger.\n'
    path = Path("ADR-SYS-0001-decision-title.md")
    issues = validate_document(path, source, False, dt.date(2026, 9, 6))[1]
    assert issues and all(i.severity == "warning" for i in issues)
    strict = validate_document(path, source, True, dt.date(2026, 9, 6))[1]
    assert len(strict) == len(issues) and all(i.severity == "error" for i in strict)


def test_displayed_id_must_follow_title() -> None:
    assert check_sample(SAMPLE.replace("`ADR-SYS-0001`", "> `ADR-SYS-0001`"))
    assert check_sample(
        SAMPLE.replace("`ADR-SYS-0001`", "`ADR-SYS-0001`\n\n`ADR-SYS-0002`")
    )


if __name__ == "__main__":
    cli()
