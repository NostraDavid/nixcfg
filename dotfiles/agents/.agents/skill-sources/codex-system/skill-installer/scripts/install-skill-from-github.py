#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "niquests==3.20.1",
#     "pydantic==2.12.5",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""Install one or more Codex skills from a GitHub repository."""

from __future__ import annotations

import contextlib
import io
import os
import shutil
import stat
import subprocess as sp
import sys
import tempfile
import urllib.parse
import zipfile
from pathlib import Path, PurePosixPath

import click
import pytest
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from github_utils import GitHubRequestError, github_request
from pydantic import BaseModel

DEFAULT_REF = "main"
GIT_TIMEOUT_SECONDS = 120
logger = log.get_logger(__name__)


class InstallError(Exception):
    """Report an expected source, download, git, or installation failure."""


class Source(BaseModel):
    """Describe a resolved GitHub source selection."""

    owner: str
    repo: str
    ref: str
    paths: list[str]
    repo_url: str | None = None


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


def codex_home() -> Path:
    """Return CODEX_HOME or its conventional default."""
    return Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))


def parse_github_url(url: str, default_ref: str) -> tuple[str, str, str, str | None]:
    """Parse a github.com repository, tree, or blob URL."""
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.netloc != "github.com":
        raise InstallError("only https://github.com URLs are supported")
    parts = [part for part in parsed.path.split("/") if part]
    if len(parts) < 2:
        raise InstallError("invalid GitHub URL")
    owner, repo = parts[:2]
    ref = default_ref
    subpath = ""
    if len(parts) > 2:
        if parts[2] in {"tree", "blob"}:
            if len(parts) < 4:
                raise InstallError("GitHub URL is missing a ref")
            ref = parts[3]
            subpath = "/".join(parts[4:])
        else:
            subpath = "/".join(parts[2:])
    return owner, repo.removesuffix(".git"), ref, subpath or None


def validate_relative_path(path: str) -> str:
    """Require a normalized repository-relative skill path."""
    normalized = path.replace("\\", "/")
    raw_parts = normalized.split("/")
    candidate = PurePosixPath(normalized)
    if candidate.is_absolute() or any(part in {"", ".", ".."} for part in raw_parts):
        raise InstallError(f"skill path must stay inside the repository: {path}")
    return candidate.as_posix()


def validate_skill_name(name: str) -> str:
    """Require a single non-special path segment."""
    if (
        not name
        or name in {".", ".."}
        or Path(name).name != name
        or "/" in name
        or "\\" in name
    ):
        raise InstallError("skill name must be a single non-special path segment")
    return name


def resolve_source(
    *, url: str | None, repo: str | None, paths: tuple[str, ...], ref: str
) -> Source:
    """Resolve CLI source options into one validated model."""
    if url:
        owner, repository, resolved_ref, url_path = parse_github_url(url, ref)
        selected = list(paths) if paths else ([url_path] if url_path else [])
    else:
        if not repo:
            raise InstallError("provide --repo or --url")
        if "://" in repo:
            return resolve_source(url=repo, repo=None, paths=paths, ref=ref)
        parts = [part for part in repo.split("/") if part]
        if len(parts) != 2:
            raise InstallError("--repo must use owner/repo format")
        owner, repository = parts
        resolved_ref = ref
        selected = list(paths)
    if not selected:
        raise InstallError("provide at least one --path or a GitHub tree URL")
    return Source(
        owner=owner,
        repo=repository,
        ref=resolved_ref,
        paths=[validate_relative_path(path) for path in selected],
    )


def safe_extract_zip(archive: zipfile.ZipFile, destination: Path) -> None:
    """Extract an archive after rejecting traversal and symbolic links."""
    root = destination.resolve()
    for info in archive.infolist():
        candidate = (destination / info.filename).resolve()
        mode = info.external_attr >> 16
        if not candidate.is_relative_to(root) or stat.S_ISLNK(mode):
            raise InstallError("archive contains unsafe paths or symbolic links")
    archive.extractall(destination)


def download_repo_zip(source: Source, destination: Path) -> Path:
    """Download and safely extract a GitHub repository archive."""
    url = f"https://codeload.github.com/{source.owner}/{source.repo}/zip/{source.ref}"
    try:
        payload = github_request(url, "codex-skill-install")
    except GitHubRequestError as exc:
        status = f" HTTP {exc.status_code}" if exc.status_code is not None else ""
        raise InstallError(f"download failed:{status} {exc}") from exc
    archive_path = destination / "repo.zip"
    archive_path.write_bytes(payload)
    try:
        with zipfile.ZipFile(archive_path) as archive:
            safe_extract_zip(archive, destination)
            top_levels = {name.split("/", 1)[0] for name in archive.namelist() if name}
    except (OSError, zipfile.BadZipFile) as exc:
        raise InstallError(f"invalid downloaded archive: {exc}") from exc
    if len(top_levels) != 1:
        raise InstallError(
            "downloaded archive must contain exactly one top-level directory"
        )
    return destination / next(iter(top_levels))


def run_git(arguments: list[str]) -> None:
    """Run git with captured diagnostics and a bounded timeout."""
    try:
        result = sp.run(
            arguments,
            check=False,
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT_SECONDS,
        )
    except (OSError, sp.TimeoutExpired) as exc:
        raise InstallError(f"git failed: {exc}") from exc
    if result.returncode != 0:
        raise InstallError(result.stderr.strip() or "git command failed")


def git_sparse_checkout(source: Source, destination: Path, repo_url: str) -> Path:
    """Clone only selected paths and check out the requested ref."""
    repo_dir = destination / "repo"
    base = [
        "git",
        "clone",
        "--filter=blob:none",
        "--depth",
        "1",
        "--sparse",
        "--single-branch",
    ]
    try:
        run_git([*base, "--branch", source.ref, repo_url, str(repo_dir)])
    except InstallError:
        run_git([*base, repo_url, str(repo_dir)])
    run_git(["git", "-C", str(repo_dir), "sparse-checkout", "set", *source.paths])
    run_git(["git", "-C", str(repo_dir), "checkout", source.ref])
    return repo_dir


def prepare_repo(source: Source, method: str, destination: Path) -> Path:
    """Prepare a repository using download first and git as an auth fallback."""
    if method in {"download", "auto"}:
        try:
            return download_repo_zip(source, destination)
        except InstallError as exc:
            if method == "download" or not any(
                code in str(exc) for code in ("401", "403", "404")
            ):
                raise
    if method in {"git", "auto"}:
        https_url = (
            source.repo_url or f"https://github.com/{source.owner}/{source.repo}.git"
        )
        try:
            return git_sparse_checkout(source, destination, https_url)
        except InstallError:
            return git_sparse_checkout(
                source, destination, f"git@github.com:{source.owner}/{source.repo}.git"
            )
    raise InstallError(f"unsupported install method: {method}")


def validate_skill(path: Path) -> None:
    """Require a skill directory containing SKILL.md."""
    if not path.is_dir():
        raise InstallError(f"skill path not found: {path}")
    if not path.joinpath("SKILL.md").is_file():
        raise InstallError(f"SKILL.md not found in {path}")


def install_from_repo(
    repo_root: Path,
    source_paths: list[str],
    destination_root: Path,
    name_override: str | None,
) -> list[tuple[str, Path]]:
    """Validate all skills, stage copies, and roll back a partial publication."""
    plans: list[tuple[str, Path, Path]] = []
    for source_path in source_paths:
        name = validate_skill_name(
            name_override
            if len(source_paths) == 1 and name_override
            else PurePosixPath(source_path).name
        )
        source = repo_root / source_path
        destination = destination_root / name
        validate_skill(source)
        if destination.exists():
            raise InstallError(f"destination already exists: {destination}")
        plans.append((name, source, destination))
    destination_root.mkdir(parents=True, exist_ok=True)
    stages: list[Path] = []
    installed: list[tuple[str, Path]] = []
    try:
        for name, source, destination in plans:
            stage_root = Path(
                tempfile.mkdtemp(prefix=f".{name}.", dir=destination_root)
            )
            stage = stage_root / name
            shutil.copytree(source, stage)
            stages.append(stage_root)
            os.replace(stage, destination)
            installed.append((name, destination))
    except OSError as exc:
        for _, destination in installed:
            shutil.rmtree(destination, ignore_errors=True)
        raise InstallError(f"could not install skills: {exc}") from exc
    finally:
        for stage_root in stages:
            shutil.rmtree(stage_root, ignore_errors=True)
    return installed


def compact_pytest_output(output: str) -> str:
    lines: list[str] = []
    for line in output.splitlines():
        section = (
            line.startswith("=") and line.endswith("=") and " tests coverage " in line
        )
        platform = (
            line.startswith("_")
            and line.endswith("_")
            and " coverage: platform " in line
        )
        if not section and not platform:
            lines.append(line)
    return "\n".join(lines).strip() + "\n"


@click.group()
def cli() -> None:
    """Install Codex skills from GitHub."""
    configure_logging()


@cli.command(name="install")
@click.option("--repo")
@click.option("--url")
@click.option("--path", "paths", multiple=True)
@click.option("--ref", default=DEFAULT_REF, show_default=True)
@click.option(
    "--dest", type=click.Path(path_type=Path), default=lambda: codex_home() / "skills"
)
@click.option("--name")
@click.option(
    "--method", type=click.Choice(("auto", "download", "git")), default="auto"
)
@click.option(
    "--dry-run", is_flag=True, help="Validate source options without downloading."
)
@click.option("--yes", is_flag=True, help="Install without interactive confirmation.")
def install_command(
    repo: str | None,
    url: str | None,
    paths: tuple[str, ...],
    ref: str,
    dest: Path,
    name: str | None,
    method: str,
    dry_run: bool,
    yes: bool,
) -> None:
    """Install selected skill paths."""
    try:
        source = resolve_source(url=url, repo=repo, paths=paths, ref=ref)
        if name is not None:
            validate_skill_name(name)
    except InstallError as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would install {len(source.paths)} skill(s) into {dest}")
        return
    if not yes:
        click.confirm(f"Install {len(source.paths)} skill(s) into {dest}?", abort=True)
    try:
        with tempfile.TemporaryDirectory(prefix="skill-install-") as directory:
            repo_root = prepare_repo(source, method, Path(directory))
            installed = install_from_repo(repo_root, source.paths, dest, name)
    except InstallError as exc:
        raise click.ClickException(str(exc)) from exc
    for skill_name, destination in installed:
        logger.info("skill_installed", skill=skill_name, destination=str(destination))
        click.echo(f"Installed {skill_name} to {destination}")


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="skill-install-coverage-") as directory:
        config = Path(directory) / ".coveragerc"
        config.write_text(
            os.linesep.join(
                (
                    "[run]",
                    "patch = subprocess",
                    "include =",
                    f"    {Path(__file__).resolve()}",
                    "",
                )
            ),
            encoding="utf-8",
        )
        previous = os.environ.get("COVERAGE_FILE")
        os.environ["COVERAGE_FILE"] = str(Path(directory) / ".coverage")
        output = io.StringIO()
        try:
            with contextlib.redirect_stdout(output):
                result = pytest.main(
                    [
                        "--cov",
                        "--cov-branch",
                        "--cov-config",
                        str(config),
                        "--cov-report=term-missing",
                        "-p",
                        "no:cacheprovider",
                        __file__,
                        "-q",
                    ]
                )
        finally:
            if previous is None:
                os.environ.pop("COVERAGE_FILE", None)
            else:
                os.environ["COVERAGE_FILE"] = previous
    click.echo(compact_pytest_output(output.getvalue()), nl=False)
    raise SystemExit(result)


cli.add_command(unit_test_command)


def test_source_resolution_and_validation() -> None:
    source = resolve_source(
        url="https://github.com/openai/skills/tree/main/skills/demo",
        repo=None,
        paths=(),
        ref="other",
    )
    assert source.paths == ["skills/demo"] and source.ref == "main"
    source = resolve_source(url=None, repo="owner/repo", paths=("skills/a",), ref="dev")
    assert source.owner == "owner" and source.ref == "dev"
    source = resolve_source(
        url=None,
        repo="https://github.com/owner/repo/tree/main/skill",
        paths=(),
        ref="main",
    )
    assert source.paths == ["skill"]
    for repo, paths in ((None, ()), ("bad", ("x",)), ("a/b", ())):
        with pytest.raises(InstallError):
            resolve_source(url=None, repo=repo, paths=paths, ref="main")
    for path in ("../bad", "/bad", "a/./b"):
        with pytest.raises(InstallError):
            validate_relative_path(path)
    for name in ("", "..", "a/b", "a\\b"):
        with pytest.raises(InstallError):
            validate_skill_name(name)


def test_parse_github_url_errors() -> None:
    assert parse_github_url("https://github.com/o/r", "main") == (
        "o",
        "r",
        "main",
        None,
    )
    assert parse_github_url("https://github.com/o/r/path", "main")[3] == "path"
    for url in (
        "http://github.com/o/r",
        "https://example.com/o/r",
        "https://github.com/o",
    ):
        with pytest.raises(InstallError):
            parse_github_url(url, "main")
    with pytest.raises(InstallError, match="missing a ref"):
        parse_github_url("https://github.com/o/r/tree", "main")


def test_safe_extract_zip(tmp_path: Path) -> None:
    archive_path = tmp_path / "archive.zip"
    with zipfile.ZipFile(archive_path, "w") as archive:
        archive.writestr("repo/SKILL.md", "ok")
    with zipfile.ZipFile(archive_path) as archive:
        safe_extract_zip(archive, tmp_path / "out")
    assert (tmp_path / "out" / "repo" / "SKILL.md").exists()
    with zipfile.ZipFile(archive_path, "w") as archive:
        archive.writestr("../escape", "bad")
    with zipfile.ZipFile(archive_path) as archive:
        with pytest.raises(InstallError, match="unsafe"):
            safe_extract_zip(archive, tmp_path / "out2")


def test_download_repo_zip(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("repo-main/SKILL.md", "ok")
    monkeypatch.setattr(
        sys.modules[__name__], "github_request", lambda *_args: buffer.getvalue()
    )
    source = Source(owner="o", repo="r", ref="main", paths=["skill"])
    assert download_repo_zip(source, tmp_path).name == "repo-main"

    def fail(*_args: object) -> bytes:
        raise GitHubRequestError("missing", 404)

    monkeypatch.setattr(sys.modules[__name__], "github_request", fail)
    with pytest.raises(InstallError, match="HTTP 404"):
        download_repo_zip(source, tmp_path)
    monkeypatch.setattr(
        sys.modules[__name__], "github_request", lambda *_args: b"bad zip"
    )
    with pytest.raises(InstallError, match="invalid downloaded"):
        download_repo_zip(source, tmp_path)
    multiple = io.BytesIO()
    with zipfile.ZipFile(multiple, "w") as archive:
        archive.writestr("one/a", "a")
        archive.writestr("two/b", "b")
    monkeypatch.setattr(
        sys.modules[__name__], "github_request", lambda *_args: multiple.getvalue()
    )
    with pytest.raises(InstallError, match="exactly one"):
        download_repo_zip(source, tmp_path)


def test_git_helpers(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr(
        sp,
        "run",
        lambda *_args, **_kwargs: sp.CompletedProcess(["git"], 0, stdout="", stderr=""),
    )
    run_git(["git", "status"])
    monkeypatch.setattr(
        sp,
        "run",
        lambda *_args, **_kwargs: sp.CompletedProcess(
            ["git"], 1, stdout="", stderr="bad"
        ),
    )
    with pytest.raises(InstallError, match="bad"):
        run_git(["git", "status"])

    def timed_out(*_args: object, **_kwargs: object) -> sp.CompletedProcess[str]:
        raise sp.TimeoutExpired(["git"], 1)

    monkeypatch.setattr(sp, "run", timed_out)
    with pytest.raises(InstallError, match="git failed"):
        run_git(["git", "status"])

    calls: list[list[str]] = []

    def record(arguments: list[str]) -> None:
        calls.append(arguments)
        if len(calls) == 1:
            raise InstallError("branch missing")

    monkeypatch.setattr(sys.modules[__name__], "run_git", record)
    source = Source(owner="o", repo="r", ref="main", paths=["skill"])
    assert git_sparse_checkout(source, tmp_path, "https://repo").name == "repo"
    assert len(calls) == 4


def test_prepare_repo_fallbacks(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    source = Source(owner="o", repo="r", ref="main", paths=["skill"])
    expected = tmp_path / "repo"
    monkeypatch.setattr(
        sys.modules[__name__], "download_repo_zip", lambda *_args: expected
    )
    assert prepare_repo(source, "download", tmp_path) == expected

    def unauthorized(*_args: object) -> Path:
        raise InstallError("HTTP 403")

    urls: list[str] = []

    def git(_source: Source, _destination: Path, url: str) -> Path:
        urls.append(url)
        if len(urls) == 1:
            raise InstallError("https failed")
        return expected

    monkeypatch.setattr(sys.modules[__name__], "download_repo_zip", unauthorized)
    monkeypatch.setattr(sys.modules[__name__], "git_sparse_checkout", git)
    assert prepare_repo(source, "auto", tmp_path) == expected
    assert urls[1].startswith("git@github.com")
    with pytest.raises(InstallError, match="HTTP 403"):
        prepare_repo(source, "download", tmp_path)
    with pytest.raises(InstallError, match="unsupported"):
        prepare_repo(source, "other", tmp_path)

    def fatal(*_args: object) -> Path:
        raise InstallError("network down")

    monkeypatch.setattr(sys.modules[__name__], "download_repo_zip", fatal)
    with pytest.raises(InstallError, match="network down"):
        prepare_repo(source, "auto", tmp_path)


def test_install_from_repo_and_errors(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    for name in ("one", "two"):
        skill = repo / "skills" / name
        skill.mkdir(parents=True)
        skill.joinpath("SKILL.md").write_text("ok", encoding="utf-8")
    dest = tmp_path / "installed"
    installed = install_from_repo(repo, ["skills/one", "skills/two"], dest, None)
    assert [name for name, _ in installed] == ["one", "two"]
    with pytest.raises(InstallError, match="already exists"):
        install_from_repo(repo, ["skills/one"], dest, None)
    with pytest.raises(InstallError, match="not found"):
        validate_skill(repo / "missing")
    empty = repo / "empty"
    empty.mkdir()
    with pytest.raises(InstallError, match="SKILL.md"):
        validate_skill(empty)


def test_install_from_repo_rolls_back(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo = tmp_path / "repo"
    for name in ("one", "two"):
        skill = repo / name
        skill.mkdir(parents=True)
        skill.joinpath("SKILL.md").write_text("ok", encoding="utf-8")
    original_replace = os.replace
    calls = 0

    def fail_second(source: Path, destination: Path) -> None:
        nonlocal calls
        calls += 1
        if calls == 2:
            raise OSError("disk full")
        original_replace(source, destination)

    monkeypatch.setattr(os, "replace", fail_second)
    destination = tmp_path / "dest"
    with pytest.raises(InstallError, match="disk full"):
        install_from_repo(repo, ["one", "two"], destination, None)
    assert not (destination / "one").exists()


def test_install_command_dry_run_and_local_install(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo_root = tmp_path / "repo"
    skill = repo_root / "skills" / "demo"
    skill.mkdir(parents=True)
    skill.joinpath("SKILL.md").write_text("ok", encoding="utf-8")
    monkeypatch.setattr(sys.modules[__name__], "prepare_repo", lambda *_args: repo_root)
    dest = tmp_path / "dest"
    runner = CliRunner()
    dry = runner.invoke(
        cli,
        [
            "install",
            "--repo",
            "o/r",
            "--path",
            "skills/demo",
            "--dest",
            str(dest),
            "--dry-run",
        ],
    )
    assert dry.exit_code == 0
    named = runner.invoke(
        cli,
        [
            "install",
            "--repo",
            "o/r",
            "--path",
            "skills/demo",
            "--dest",
            str(dest),
            "--name",
            "renamed",
            "--dry-run",
        ],
    )
    assert named.exit_code == 0
    result = runner.invoke(
        cli,
        ["install", "--repo", "o/r", "--path", "skills/demo", "--dest", str(dest)],
        input="y\n",
    )
    assert result.exit_code == 0 and (dest / "demo").exists()


def test_install_command_errors(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    result = CliRunner().invoke(cli, ["install", "--dry-run"])
    assert result.exit_code == 1

    def fail(*_args: object) -> Path:
        raise InstallError("prepare failed")

    monkeypatch.setattr(sys.modules[__name__], "prepare_repo", fail)
    result = CliRunner().invoke(
        cli,
        [
            "install",
            "--repo",
            "o/r",
            "--path",
            "skill",
            "--dest",
            str(tmp_path),
            "--yes",
        ],
    )
    assert result.exit_code == 1 and "prepare failed" in result.stderr


def test_compact_and_harness(monkeypatch: pytest.MonkeyPatch) -> None:
    assert (
        compact_pytest_output(
            "ok\n===== tests coverage =====\n_____ coverage: platform x _____\nTOTAL"
        )
        == "ok\nTOTAL\n"
    )
    assert compact_pytest_output("= keep =\n_ keep _") == "= keep =\n_ keep _\n"
    monkeypatch.delenv("COVERAGE_FILE", raising=False)

    def fake_main(arguments: list[str]) -> pytest.ExitCode:
        assert Path(arguments[arguments.index("--cov-config") + 1]).exists()
        print("TOTAL")
        return pytest.ExitCode.OK

    monkeypatch.setattr(pytest, "main", fake_main)
    assert CliRunner().invoke(unit_test_command).stdout == "TOTAL\n"


def test_harness_restores_existing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("COVERAGE_FILE", "existing")
    monkeypatch.setattr(pytest, "main", lambda _arguments: pytest.ExitCode.OK)
    assert CliRunner().invoke(unit_test_command).exit_code == 0
    assert os.environ["COVERAGE_FILE"] == "existing"


def test_help_logging_and_entrypoint(capsys: pytest.CaptureFixture[str]) -> None:
    assert "unit-test" in CliRunner().invoke(cli, ["--help"]).stdout
    configure_logging()
    logger.info("test_event")
    assert "test_event" in capsys.readouterr().err
    process = sp.run(
        [sys.executable, __file__, "--help"],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert process.returncode == 0 and "Install Codex" in process.stdout


if __name__ == "__main__":
    cli()
