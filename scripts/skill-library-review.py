#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "orjson==3.11.7",
#     "pydantic==2.13.4",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""Inventory a local technical-book library and audit its review coverage."""

import contextlib
import hashlib
import io
import os
import subprocess as sp
import sys
import tempfile
from collections.abc import Callable
from enum import StrEnum
from pathlib import Path

import click
import orjson as json
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from pydantic import BaseModel, ConfigDict, Field, ValidationError

logger = log.get_logger(__name__)
SUPPORTED_SUFFIXES = frozenset({".pdf", ".epub", ".chm", ".mobi", ".md"})
EDITION_MARKERS = (", early release", ", sample chapter", ", draft")


class ReviewError(Exception):
    """Report an expected inventory or catalog failure."""


class ReviewStatus(StrEnum):
    """Track whether a source has received the required individual review."""

    PENDING = "pending"
    REVIEWED = "reviewed"
    BLOCKED = "blocked"


class Decision(StrEnum):
    """Record the skill-level disposition of a reviewed source."""

    UNDECIDED = "undecided"
    IMPROVE = "improve"
    NEW_SKILL = "new-skill"
    MERGE_OR_SPLIT = "merge-or-split"
    NO_SKILL = "no-skill"


class SourceReview(BaseModel):
    """Store reproducible source facts and human-authored review conclusions."""

    model_config = ConfigDict(extra="forbid")

    path: str
    sha256: str
    format: str
    category: str
    title: str
    edition: str | None = None
    size_bytes: int = Field(ge=0)
    pages: int | None = Field(default=None, ge=1)
    extraction_chars_first_20_pages: int | None = Field(default=None, ge=0)
    extraction_quality: str
    status: ReviewStatus = ReviewStatus.PENDING
    inspected_sections: list[str] = Field(default_factory=list)
    topics: list[str] = Field(default_factory=list)
    workflows: list[str] = Field(default_factory=list)
    anti_patterns: list[str] = Field(default_factory=list)
    relevant_skills: list[str] = Field(default_factory=list)
    clusters: list[str] = Field(default_factory=list)
    freshness: str = "unassessed"
    decision: Decision = Decision.UNDECIDED
    rationale: str = ""
    provenance: list[str] = Field(default_factory=list)


class Catalog(BaseModel):
    """Describe the versioned, machine-auditable review register."""

    model_config = ConfigDict(extra="forbid")

    schema_version: int = 1
    library_root: str
    sources: list[SourceReview]


RunCommand = Callable[[list[str], int], sp.CompletedProcess[str]]


def configure_logging() -> None:
    """Send human-readable structured logs to stderr."""
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


def run_command(arguments: list[str], timeout: int) -> sp.CompletedProcess[str]:
    """Run a read-only metadata command without invoking a shell."""
    return sp.run(
        arguments,
        check=False,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def parse_title(stem: str) -> tuple[str, str | None]:
    """Split the filename convention into a title and optional edition label."""
    lowered = stem.lower()
    for marker in EDITION_MARKERS:
        index = lowered.rfind(marker)
        if index >= 0:
            title = stem[:index]
            suffix = stem[index + 2 :]
            edition_marker = title.lower().rfind(", ")
            if edition_marker >= 0 and "edition" in title.lower()[edition_marker:]:
                return title[
                    :edition_marker
                ], f"{title[edition_marker + 2 :]}, {suffix}"
            return title, suffix
    edition_marker = lowered.rfind(", ")
    if edition_marker >= 0 and "edition" in lowered[edition_marker:]:
        return stem[:edition_marker], stem[edition_marker + 2 :]
    return stem, None


def fingerprint(path: Path) -> str:
    """Hash a source without loading a large book into memory."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def parse_pdf_pages(output: str) -> int | None:
    """Read the page count from Poppler's stable key-value output."""
    for line in output.splitlines():
        if line.startswith("Pages:"):
            value = line.partition(":")[2].strip()
            return int(value) if value.isdigit() else None
    return None


def inspect_pdf(path: Path, runner: RunCommand = run_command) -> tuple[int, int]:
    """Collect page count and a bounded text-extraction quality sample."""
    try:
        info = runner(["pdfinfo", str(path)], 30)
    except (OSError, sp.TimeoutExpired) as error:
        raise ReviewError(
            f"could not inspect PDF metadata for {path}: {error}"
        ) from error
    pages = parse_pdf_pages(info.stdout)
    if info.returncode != 0 or pages is None:
        detail = info.stderr.strip() or "page count missing"
        raise ReviewError(f"pdfinfo failed for {path}: {detail}")
    try:
        text = runner(
            ["pdftotext", "-f", "1", "-l", str(min(pages, 20)), str(path), "-"],
            60,
        )
    except (OSError, sp.TimeoutExpired) as error:
        raise ReviewError(f"could not sample PDF text for {path}: {error}") from error
    if text.returncode != 0:
        detail = text.stderr.strip() or "unknown extraction error"
        raise ReviewError(f"pdftotext failed for {path}: {detail}")
    characters = sum(not character.isspace() for character in text.stdout)
    return pages, characters


def discover_sources(library_root: Path) -> list[Path]:
    """Return supported local sources in deterministic path order."""
    if not library_root.is_dir():
        raise ReviewError(f"library root is not a directory: {library_root}")
    return sorted(
        path
        for path in library_root.rglob("*")
        if path.is_file() and path.suffix.lower() in SUPPORTED_SUFFIXES
    )


def load_catalog(path: Path) -> Catalog | None:
    """Load and validate an existing catalog when present."""
    if not path.exists():
        return None
    try:
        return Catalog.model_validate_json(path.read_bytes())
    except (OSError, ValidationError, ValueError) as error:
        raise ReviewError(f"invalid catalog {path}: {error}") from error


def source_facts(
    path: Path,
    library_root: Path,
    runner: RunCommand = run_command,
) -> dict[str, object]:
    """Build reproducible facts without assigning an editorial decision."""
    relative = path.relative_to(library_root)
    title, edition = parse_title(path.stem)
    pages: int | None = None
    characters: int | None = None
    quality = "structured-text"
    if path.suffix.lower() == ".pdf":
        pages, characters = inspect_pdf(path, runner)
        quality = "scanned-image" if characters < 1000 else "extractable-text"
    elif path.suffix.lower() == ".md":
        quality = "plain-text"
    return {
        "path": relative.as_posix(),
        "sha256": fingerprint(path),
        "format": path.suffix.lower().lstrip("."),
        "category": relative.parts[0] if len(relative.parts) > 1 else "root",
        "title": title,
        "edition": edition,
        "size_bytes": path.stat().st_size,
        "pages": pages,
        "extraction_chars_first_20_pages": characters,
        "extraction_quality": quality,
    }


def merge_review(
    facts: dict[str, object], previous: SourceReview | None
) -> SourceReview:
    """Refresh source facts while preserving all human-authored review fields."""
    if previous is None:
        return SourceReview.model_validate(facts)
    review_fields = previous.model_dump(
        exclude={
            "path",
            "sha256",
            "format",
            "category",
            "title",
            "edition",
            "size_bytes",
            "pages",
            "extraction_chars_first_20_pages",
            "extraction_quality",
        }
    )
    return SourceReview.model_validate(facts | review_fields)


def build_catalog(
    library_root: Path,
    previous: Catalog | None,
    runner: RunCommand = run_command,
) -> Catalog:
    """Inventory every source and retain reviews by stable relative path."""
    previous_by_path = (
        {source.path: source for source in previous.sources} if previous else {}
    )
    sources: list[SourceReview] = []
    for path in discover_sources(library_root):
        facts = source_facts(path, library_root, runner)
        relative = str(facts["path"])
        sources.append(merge_review(facts, previous_by_path.get(relative)))
    return Catalog(library_root=library_root.as_posix(), sources=sources)


def serialize_catalog(catalog: Catalog) -> bytes:
    """Serialize deterministically for readable reviews and stable diffs."""
    return json.dumps(
        catalog.model_dump(mode="json"),
        option=json.OPT_INDENT_2 | json.OPT_APPEND_NEWLINE | json.OPT_SORT_KEYS,
    )


def atomic_write(path: Path, content: bytes) -> None:
    """Replace the catalog atomically to avoid partial review state."""
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(content)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def audit_catalog(catalog: Catalog) -> list[str]:
    """Return coverage failures without hiding partially completed work."""
    failures: list[str] = []
    paths = [source.path for source in catalog.sources]
    duplicates = sorted(path for path in set(paths) if paths.count(path) > 1)
    if duplicates:
        failures.append(f"duplicate source paths: {', '.join(duplicates)}")
    for source in catalog.sources:
        if source.status is not ReviewStatus.REVIEWED:
            failures.append(f"{source.path}: status is {source.status.value}")
        if source.decision is Decision.UNDECIDED:
            failures.append(f"{source.path}: decision is undecided")
        if not source.inspected_sections:
            failures.append(f"{source.path}: inspected_sections is empty")
        if not source.rationale.strip():
            failures.append(f"{source.path}: rationale is empty")
        if not source.provenance:
            failures.append(f"{source.path}: provenance is empty")
    return failures


@click.group()
def cli() -> None:
    """Inventory technical books and audit their skill-review coverage."""
    configure_logging()


@cli.command()
@click.option(
    "--library-root",
    type=click.Path(path_type=Path, exists=True, file_okay=False),
    default=Path("pdfs"),
    show_default=True,
)
@click.option(
    "--output",
    type=click.Path(path_type=Path, dir_okay=False),
    default=Path("docs/skill-library-review/coverage.json"),
    show_default=True,
)
@click.option(
    "--dry-run", is_flag=True, help="Inspect sources without writing the catalog."
)
def inventory(library_root: Path, output: Path, dry_run: bool) -> None:
    """Refresh source facts while preserving completed review annotations."""
    try:
        previous = load_catalog(output)
        catalog = build_catalog(library_root.resolve(), previous)
        catalog.library_root = library_root.as_posix()
        content = serialize_catalog(catalog)
        if not dry_run:
            atomic_write(output, content)
    except ReviewError as error:
        raise click.ClickException(str(error)) from error
    pending = sum(
        source.status is not ReviewStatus.REVIEWED for source in catalog.sources
    )
    logger.info(
        "inventory_completed",
        sources=len(catalog.sources),
        pending=pending,
        output=str(output),
        dry_run=dry_run,
    )
    click.echo(f"sources={len(catalog.sources)} pending={pending}")


@cli.command()
@click.argument(
    "catalog_path",
    type=click.Path(path_type=Path, exists=True, dir_okay=False),
    default=Path("docs/skill-library-review/coverage.json"),
)
def audit(catalog_path: Path) -> None:
    """Fail unless every source has a substantiated review decision."""
    try:
        catalog = load_catalog(catalog_path)
    except ReviewError as error:
        raise click.ClickException(str(error)) from error
    if catalog is None:
        raise click.ClickException(f"catalog does not exist: {catalog_path}")
    failures = audit_catalog(catalog)
    if failures:
        preview = "\n".join(f"- {failure}" for failure in failures[:20])
        suffix = f"\n- ... {len(failures) - 20} more" if len(failures) > 20 else ""
        raise click.ClickException(
            f"coverage audit failed with {len(failures)} issue(s):\n{preview}{suffix}"
        )
    click.echo(f"coverage complete: {len(catalog.sources)} sources reviewed")


def compact_pytest_output(output: str) -> str:
    """Remove pytest-cov banners while preserving its useful report."""
    lines: list[str] = []
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
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(
        prefix="skill-library-review-coverage-"
    ) as directory:
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


cli.add_command(unit_test_command)


def completed(
    output: str, returncode: int = 0, stderr: str = ""
) -> sp.CompletedProcess[str]:
    """Build a typed subprocess result for metadata tests."""
    return sp.CompletedProcess([], returncode, output, stderr)


def test_parse_title() -> None:
    assert parse_title("Effective Python, 2nd edition") == (
        "Effective Python",
        "2nd edition",
    )
    assert parse_title("Data Quality Fundamentals, early release") == (
        "Data Quality Fundamentals",
        "early release",
    )
    assert parse_title("Database Design, 3rd edition, sample chapter") == (
        "Database Design",
        "3rd edition, sample chapter",
    )
    assert parse_title("Computer Ethics") == ("Computer Ethics", None)


def test_inspect_pdf() -> None:
    responses = iter((completed("Pages: 42\n"), completed(" useful text ")))

    def fake_runner(arguments: list[str], timeout: int) -> sp.CompletedProcess[str]:
        assert arguments[0] in {"pdfinfo", "pdftotext"}
        assert timeout > 0
        return next(responses)

    assert inspect_pdf(Path("book.pdf"), fake_runner) == (42, 10)


def test_build_catalog_preserves_review_fields(tmp_path: Path) -> None:
    library = tmp_path / "pdfs"
    category = library / "Databases"
    category.mkdir(parents=True)
    source_path = category / "SQL Book.md"
    source_path.write_text("# Contents", encoding="utf-8")
    previous_source = SourceReview(
        path="Databases/SQL Book.md",
        sha256="old",
        format="md",
        category="Databases",
        title="SQL Book",
        size_bytes=1,
        extraction_quality="plain-text",
        status=ReviewStatus.REVIEWED,
        inspected_sections=["contents"],
        decision=Decision.IMPROVE,
        rationale="Adds a repeatable review workflow.",
        provenance=["contents"],
    )
    previous = Catalog(library_root="old", sources=[previous_source])
    catalog = build_catalog(library, previous)
    assert len(catalog.sources) == 1
    assert catalog.sources[0].sha256 != "old"
    assert catalog.sources[0].status is ReviewStatus.REVIEWED
    assert catalog.sources[0].decision is Decision.IMPROVE


def test_audit_catalog_reports_missing_review_fields() -> None:
    source = SourceReview(
        path="book.md",
        sha256="0" * 64,
        format="md",
        category="root",
        title="book",
        size_bytes=1,
        extraction_quality="plain-text",
    )
    failures = audit_catalog(Catalog(library_root="pdfs", sources=[source]))
    assert len(failures) == 5
    assert any("decision is undecided" in failure for failure in failures)


def test_inventory_dry_run_and_audit_failure(tmp_path: Path) -> None:
    library = tmp_path / "pdfs"
    library.mkdir()
    (library / "notes.md").write_text("content", encoding="utf-8")
    output = tmp_path / "coverage.json"
    runner = CliRunner()
    result = runner.invoke(
        cli,
        [
            "inventory",
            "--library-root",
            str(library),
            "--output",
            str(output),
            "--dry-run",
        ],
    )
    assert result.exit_code == 0
    assert result.stdout == "sources=1 pending=1\n"
    assert not output.exists()

    result = runner.invoke(
        cli,
        ["inventory", "--library-root", str(library), "--output", str(output)],
    )
    assert result.exit_code == 0
    assert output.exists()
    result = runner.invoke(cli, ["audit", str(output)])
    assert result.exit_code == 1
    assert "coverage audit failed" in result.stderr


def test_cli_help_and_entrypoint() -> None:
    result = CliRunner().invoke(cli, ["--help"])
    assert result.exit_code == 0
    assert "inventory" in result.stdout
    assert "audit" in result.stdout
    assert "unit-test" in result.stdout
    process = sp.run(
        [sys.executable, __file__, "--help"],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert process.returncode == 0
    assert "Inventory technical books" in process.stdout


if __name__ == "__main__":
    cli()
