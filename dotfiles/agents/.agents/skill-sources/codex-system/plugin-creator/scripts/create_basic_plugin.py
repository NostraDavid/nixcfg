#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "orjson==3.11.7",
#     "pydantic==2.12.5",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "regex==2026.2.28",
#     "structlog==26.1.0",
# ]
# ///

"""Create a validation-ready Codex plugin and optional marketplace entry."""

from __future__ import annotations

import contextlib
import io
import os
import shutil
import subprocess as sp
import sys
import tempfile
from pathlib import Path

import click
import orjson as json
import pytest
import regex as re
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    JsonValue,
    ValidationError,
    field_validator,
)

MAX_PLUGIN_NAME_LENGTH = 64
DEFAULT_INSTALL_POLICY = "AVAILABLE"
DEFAULT_AUTH_POLICY = "ON_INSTALL"
DEFAULT_CATEGORY = "Productivity"
DEFAULT_MARKETPLACE_NAME = "personal"
VALID_INSTALL_POLICIES = ("NOT_AVAILABLE", "AVAILABLE", "INSTALLED_BY_DEFAULT")
VALID_AUTH_POLICIES = ("ON_INSTALL", "ON_USE")
DEFAULT_PLUGIN_PARENT = Path.home() / "plugins"
DEFAULT_MARKETPLACE_PATH = Path.home() / ".agents" / "plugins" / "marketplace.json"
logger = log.get_logger(__name__)


class PluginCreationError(Exception):
    """Report an expected plugin, marketplace, or filesystem failure."""


class Marketplace(BaseModel):
    """Validate mutable marketplace fields while preserving extensions."""

    model_config = ConfigDict(extra="allow")
    name: str
    interface: dict[str, JsonValue] | None = None
    plugins: list[dict[str, JsonValue]] = Field(default_factory=list)

    @field_validator("name")
    @classmethod
    def name_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("name must not be blank")
        return value.strip()


def configure_logging() -> None:
    """Send human-readable structured diagnostics to stderr."""
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


def normalize_plugin_name(plugin_name: str) -> str:
    """Normalize a plugin name to lowercase hyphen-case."""
    normalized = re.sub(r"[^a-z0-9]+", "-", plugin_name.strip().lower())
    return re.sub(r"-{2,}", "-", normalized).strip("-")


def validate_plugin_name(plugin_name: str) -> None:
    """Enforce the portable plugin-name contract."""
    if not plugin_name:
        raise PluginCreationError(
            "plugin name must contain at least one letter or digit"
        )
    if len(plugin_name) > MAX_PLUGIN_NAME_LENGTH:
        raise PluginCreationError(
            f"plugin name is {len(plugin_name)} characters; maximum is {MAX_PLUGIN_NAME_LENGTH}"
        )


def validate_marketplace_name(marketplace_name: str) -> str:
    """Validate and normalize an explicit marketplace name."""
    normalized = marketplace_name.strip()
    if not normalized:
        raise PluginCreationError("marketplace name must not be empty")
    if re.fullmatch(r"[A-Za-z0-9_-]+", normalized) is None:
        raise PluginCreationError(
            "marketplace name may contain only ASCII letters, digits, underscores, and hyphens"
        )
    return normalized


def display_name_from_plugin_name(plugin_name: str) -> str:
    """Build a human-readable title from a plugin identifier."""
    return " ".join(part.capitalize() for part in re.split(r"[-_]+", plugin_name))


def build_plugin_json(
    plugin_name: str, *, with_mcp: bool, with_apps: bool
) -> dict[str, JsonValue]:
    """Build a conservative plugin manifest."""
    display_name = display_name_from_plugin_name(plugin_name)
    payload: dict[str, JsonValue] = {
        "name": plugin_name,
        "version": "0.1.0",
        "description": f"{display_name} plugin",
        "author": {"name": "Local developer"},
        "skills": "./skills/",
        "interface": {
            "displayName": display_name,
            "shortDescription": f"Use {display_name} in Codex.",
            "longDescription": f"{display_name} adds a local Codex plugin scaffold.",
            "developerName": "Local developer",
            "category": DEFAULT_CATEGORY,
            "capabilities": [],
            "defaultPrompt": f"Help me use {display_name}.",
        },
    }
    if with_mcp:
        payload["mcpServers"] = "./.mcp.json"
    if with_apps:
        payload["apps"] = "./.app.json"
    return payload


def build_marketplace_entry(
    plugin_name: str, install_policy: str, auth_policy: str, category: str
) -> dict[str, JsonValue]:
    """Build one local marketplace entry."""
    return {
        "name": plugin_name,
        "source": {"source": "local", "path": f"./plugins/{plugin_name}"},
        "policy": {"installation": install_policy, "authentication": auth_policy},
        "category": category,
    }


def load_marketplace(path: Path, requested_name: str | None) -> Marketplace:
    """Load an existing marketplace or build a new one."""
    if not path.exists():
        name = requested_name or DEFAULT_MARKETPLACE_NAME
        return Marketplace(
            name=name,
            interface={"displayName": display_name_from_plugin_name(name)},
        )
    try:
        marketplace = Marketplace.model_validate(json.loads(path.read_bytes()))
    except OSError as exc:
        raise PluginCreationError(f"could not read {path}: {exc}") from exc
    except (json.JSONDecodeError, ValidationError) as exc:
        raise PluginCreationError(
            f"invalid marketplace manifest {path}: {exc}"
        ) from exc
    if requested_name is not None and marketplace.name != requested_name:
        raise PluginCreationError(
            f"{path} uses marketplace name {marketplace.name!r}, not {requested_name!r}"
        )
    return marketplace


def render_marketplace(
    marketplace: Marketplace,
    entry: dict[str, JsonValue],
    *,
    force: bool,
) -> bytes:
    """Insert or replace one marketplace entry and render JSON."""
    plugin_name = entry["name"]
    for index, existing in enumerate(marketplace.plugins):
        if existing.get("name") == plugin_name:
            if not force:
                raise PluginCreationError(
                    f"marketplace entry {plugin_name!r} already exists; pass --force to replace it"
                )
            marketplace.plugins[index] = entry
            break
    else:
        marketplace.plugins.append(entry)
    return json.dumps(
        marketplace.model_dump(mode="json"),
        option=json.OPT_INDENT_2 | json.OPT_APPEND_NEWLINE,
    )


def json_bytes(payload: dict[str, JsonValue]) -> bytes:
    """Render deterministic, newline-terminated JSON."""
    return json.dumps(payload, option=json.OPT_INDENT_2 | json.OPT_APPEND_NEWLINE)


def stage_plugin(
    plugin_parent: Path,
    plugin_name: str,
    directories: tuple[str, ...],
    *,
    with_mcp: bool,
    with_apps: bool,
) -> Path:
    """Build a complete plugin in a temporary sibling directory."""
    plugin_parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=f".{plugin_name}.", dir=plugin_parent))
    try:
        manifest = stage / ".codex-plugin" / "plugin.json"
        manifest.parent.mkdir()
        manifest.write_bytes(
            json_bytes(
                build_plugin_json(plugin_name, with_mcp=with_mcp, with_apps=with_apps)
            )
        )
        for directory in directories:
            stage.joinpath(directory).mkdir()
        if with_mcp:
            stage.joinpath(".mcp.json").write_bytes(json_bytes({"mcpServers": {}}))
        if with_apps:
            stage.joinpath(".app.json").write_bytes(json_bytes({"apps": {}}))
    except OSError as exc:
        shutil.rmtree(stage, ignore_errors=True)
        raise PluginCreationError(f"could not stage plugin: {exc}") from exc
    return stage


def write_atomic(path: Path, payload: bytes) -> None:
    """Create or replace PATH atomically."""
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, raw_temp_path = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temp_path = Path(raw_temp_path)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def publish_plugin(
    stage: Path,
    plugin_root: Path,
    *,
    force: bool,
    marketplace_path: Path | None,
    marketplace_payload: bytes | None,
) -> None:
    """Publish plugin and marketplace as one rollback-capable operation."""
    backup = plugin_root.with_name(f".{plugin_root.name}.backup")
    if backup.exists():
        raise PluginCreationError(f"stale plugin backup exists: {backup}")
    if plugin_root.exists():
        if not force:
            raise PluginCreationError(
                f"plugin already exists: {plugin_root}; pass --force"
            )
        os.replace(plugin_root, backup)
    try:
        os.replace(stage, plugin_root)
        if marketplace_path is not None and marketplace_payload is not None:
            write_atomic(marketplace_path, marketplace_payload)
    except OSError as exc:
        if plugin_root.exists():
            shutil.rmtree(plugin_root)
        if backup.exists():
            os.replace(backup, plugin_root)
        raise PluginCreationError(f"could not publish plugin: {exc}") from exc
    shutil.rmtree(backup, ignore_errors=True)


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
    """Create local Codex plugins."""
    configure_logging()


@cli.command(name="create")
@click.argument("plugin_name")
@click.option(
    "--path",
    "plugin_parent",
    type=click.Path(path_type=Path),
    default=DEFAULT_PLUGIN_PARENT,
)
@click.option("--with-skills", is_flag=True)
@click.option("--with-hooks", is_flag=True)
@click.option("--with-scripts", is_flag=True)
@click.option("--with-assets", is_flag=True)
@click.option("--with-mcp", is_flag=True)
@click.option("--with-apps", is_flag=True)
@click.option("--with-marketplace", is_flag=True)
@click.option(
    "--marketplace-path",
    type=click.Path(path_type=Path),
    default=DEFAULT_MARKETPLACE_PATH,
)
@click.option("--marketplace-name")
@click.option(
    "--install-policy",
    type=click.Choice(VALID_INSTALL_POLICIES),
    default=DEFAULT_INSTALL_POLICY,
)
@click.option(
    "--auth-policy", type=click.Choice(VALID_AUTH_POLICIES), default=DEFAULT_AUTH_POLICY
)
@click.option("--category", default=DEFAULT_CATEGORY)
@click.option("--force", is_flag=True)
@click.option("--dry-run", is_flag=True, help="Validate and describe without writing.")
@click.option("--yes", is_flag=True, help="Write without interactive confirmation.")
def create_command(
    plugin_name: str,
    plugin_parent: Path,
    with_skills: bool,
    with_hooks: bool,
    with_scripts: bool,
    with_assets: bool,
    with_mcp: bool,
    with_apps: bool,
    with_marketplace: bool,
    marketplace_path: Path,
    marketplace_name: str | None,
    install_policy: str,
    auth_policy: str,
    category: str,
    force: bool,
    dry_run: bool,
    yes: bool,
) -> None:
    """Create PLUGIN_NAME beneath --path."""
    normalized = normalize_plugin_name(plugin_name)
    plugin_root = plugin_parent.expanduser().resolve() / normalized
    try:
        validate_plugin_name(normalized)
        requested_name = (
            validate_marketplace_name(marketplace_name)
            if marketplace_name is not None
            else None
        )
        marketplace_payload = None
        resolved_marketplace_path = None
        if with_marketplace:
            resolved_marketplace_path = marketplace_path.expanduser().resolve()
            marketplace = load_marketplace(resolved_marketplace_path, requested_name)
            marketplace_payload = render_marketplace(
                marketplace,
                build_marketplace_entry(
                    normalized, install_policy, auth_policy, category
                ),
                force=force,
            )
        if plugin_root.exists() and not force:
            raise PluginCreationError(
                f"plugin already exists: {plugin_root}; pass --force"
            )
    except PluginCreationError as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would create plugin: {plugin_root}")
        return
    if not yes:
        click.confirm(f"Create plugin {plugin_root}?", abort=True)
    directories = tuple(
        name
        for name, enabled in (
            ("skills", with_skills),
            ("hooks", with_hooks),
            ("scripts", with_scripts),
            ("assets", with_assets),
        )
        if enabled
    )
    stage: Path | None = None
    try:
        stage = stage_plugin(
            plugin_parent.expanduser().resolve(),
            normalized,
            directories,
            with_mcp=with_mcp,
            with_apps=with_apps,
        )
        publish_plugin(
            stage,
            plugin_root,
            force=force,
            marketplace_path=resolved_marketplace_path,
            marketplace_payload=marketplace_payload,
        )
    except (OSError, PluginCreationError) as exc:
        if stage is not None:
            shutil.rmtree(stage, ignore_errors=True)
        raise click.ClickException(str(exc)) from exc
    logger.info("plugin_created", plugin=normalized, output=str(plugin_root))
    click.echo(plugin_root)


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="plugin-create-coverage-") as directory:
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


def test_name_and_manifest_helpers() -> None:
    assert normalize_plugin_name(" My_Plugin ") == "my-plugin"
    validate_plugin_name("valid")
    with pytest.raises(PluginCreationError, match="at least one"):
        validate_plugin_name("")
    with pytest.raises(PluginCreationError, match="maximum is 64"):
        validate_plugin_name("a" * 65)
    assert validate_marketplace_name(" personal_2 ") == "personal_2"
    for invalid in ("", "bad name"):
        with pytest.raises(PluginCreationError):
            validate_marketplace_name(invalid)
    manifest = build_plugin_json("my-plugin", with_mcp=True, with_apps=True)
    assert manifest["mcpServers"] == "./.mcp.json"
    assert manifest["apps"] == "./.app.json"
    plain = build_plugin_json("plain", with_mcp=False, with_apps=False)
    assert "mcpServers" not in plain and "apps" not in plain


def test_marketplace_load_render_and_errors(tmp_path: Path) -> None:
    path = tmp_path / "marketplace.json"
    marketplace = load_marketplace(path, None)
    assert marketplace.name == "personal"
    entry = build_marketplace_entry("sample", "AVAILABLE", "ON_USE", "Tools")
    payload = render_marketplace(marketplace, entry, force=False)
    path.write_bytes(payload)
    loaded = load_marketplace(path, "personal")
    with pytest.raises(PluginCreationError, match="already exists"):
        render_marketplace(loaded, entry, force=False)
    replaced = render_marketplace(loaded, entry, force=True)
    assert len(json.loads(replaced)["plugins"]) == 1
    marketplace_with_other = Marketplace(name="personal", plugins=[{"name": "other"}])
    appended = render_marketplace(marketplace_with_other, entry, force=False)
    assert len(json.loads(appended)["plugins"]) == 2
    with pytest.raises(PluginCreationError, match="not 'other'"):
        load_marketplace(path, "other")
    path.write_bytes(b"{")
    with pytest.raises(PluginCreationError, match="invalid marketplace"):
        load_marketplace(path, None)
    with pytest.raises(ValidationError, match="name must not be blank"):
        Marketplace.model_validate({"name": " "})


def test_load_marketplace_reports_read_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    path = tmp_path / "marketplace.json"
    path.write_bytes(b"{}")

    def fail(_path: Path) -> bytes:
        raise OSError("read failed")

    monkeypatch.setattr(Path, "read_bytes", fail)
    with pytest.raises(PluginCreationError, match="could not read"):
        load_marketplace(path, None)


def test_stage_and_publish_plugin(tmp_path: Path) -> None:
    stage = stage_plugin(
        tmp_path, "sample", ("skills", "hooks"), with_mcp=True, with_apps=True
    )
    root = tmp_path / "sample"
    marketplace = tmp_path / "marketplace.json"
    publish_plugin(
        stage,
        root,
        force=False,
        marketplace_path=marketplace,
        marketplace_payload=b"{}\n",
    )
    assert (root / ".codex-plugin" / "plugin.json").exists()
    assert (root / "skills").is_dir()
    assert marketplace.read_bytes() == b"{}\n"
    replacement = stage_plugin(
        tmp_path, "sample", ("assets",), with_mcp=False, with_apps=False
    )
    publish_plugin(
        replacement, root, force=True, marketplace_path=None, marketplace_payload=None
    )
    assert (root / "assets").is_dir()
    existing = stage_plugin(tmp_path, "sample", (), with_mcp=False, with_apps=False)
    with pytest.raises(PluginCreationError, match="pass --force"):
        publish_plugin(
            existing, root, force=False, marketplace_path=None, marketplace_payload=None
        )
    shutil.rmtree(existing)
    left_only = stage_plugin(tmp_path, "left", (), with_mcp=False, with_apps=False)
    publish_plugin(
        left_only,
        tmp_path / "left",
        force=False,
        marketplace_path=tmp_path / "unused.json",
        marketplace_payload=None,
    )
    right_only = stage_plugin(tmp_path, "right", (), with_mcp=False, with_apps=False)
    publish_plugin(
        right_only,
        tmp_path / "right",
        force=False,
        marketplace_path=None,
        marketplace_payload=b"unused",
    )


def test_stage_plugin_cleans_up_after_write_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    original = Path.write_bytes

    def fail(path: Path, payload: bytes) -> int:
        if path.name == "plugin.json":
            raise OSError("write failed")
        return original(path, payload)

    monkeypatch.setattr(Path, "write_bytes", fail)
    assert (tmp_path / "probe").write_bytes(b"ok") == 2
    (tmp_path / "probe").unlink()
    with pytest.raises(PluginCreationError, match="could not stage"):
        stage_plugin(tmp_path, "broken", (), with_mcp=False, with_apps=False)
    assert not list(tmp_path.iterdir())


def test_publish_rolls_back_and_rejects_stale_backup(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "sample"
    root.mkdir()
    root.joinpath("old").write_text("old", encoding="utf-8")
    stage = stage_plugin(tmp_path, "sample", (), with_mcp=False, with_apps=False)

    def fail(_path: Path, _payload: bytes) -> None:
        raise OSError("disk full")

    monkeypatch.setattr(sys.modules[__name__], "write_atomic", fail)
    with pytest.raises(PluginCreationError, match="disk full"):
        publish_plugin(
            stage,
            root,
            force=True,
            marketplace_path=tmp_path / "m.json",
            marketplace_payload=b"{}",
        )
    assert root.joinpath("old").exists()
    fresh_stage = stage_plugin(tmp_path, "fresh", (), with_mcp=False, with_apps=False)

    def remove_then_fail(_path: Path, _payload: bytes) -> None:
        shutil.rmtree(tmp_path / "fresh")
        raise OSError("disk full")

    monkeypatch.setattr(sys.modules[__name__], "write_atomic", remove_then_fail)
    with pytest.raises(PluginCreationError, match="disk full"):
        publish_plugin(
            fresh_stage,
            tmp_path / "fresh",
            force=False,
            marketplace_path=tmp_path / "fresh-marketplace.json",
            marketplace_payload=b"{}",
        )
    assert not (tmp_path / "fresh").exists()
    stage = stage_plugin(tmp_path, "sample", (), with_mcp=False, with_apps=False)
    backup = root.with_name(".sample.backup")
    backup.mkdir()
    with pytest.raises(PluginCreationError, match="stale"):
        publish_plugin(
            stage, root, force=True, marketplace_path=None, marketplace_payload=None
        )
    shutil.rmtree(stage)


def test_create_command_dry_run_and_write(tmp_path: Path) -> None:
    marketplace = tmp_path / "marketplace.json"
    runner = CliRunner()
    dry = runner.invoke(
        cli, ["create", "My Plugin", "--path", str(tmp_path), "--dry-run"]
    )
    assert dry.exit_code == 0
    result = runner.invoke(
        cli,
        [
            "create",
            "My Plugin",
            "--path",
            str(tmp_path),
            "--with-skills",
            "--with-marketplace",
            "--marketplace-path",
            str(marketplace),
        ],
        input="y\n",
    )
    assert result.exit_code == 0
    assert (tmp_path / "my-plugin" / "skills").is_dir()
    duplicate = runner.invoke(
        cli, ["create", "My Plugin", "--path", str(tmp_path), "--dry-run"]
    )
    assert duplicate.exit_code == 1


def test_create_command_translates_staging_error(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fail(*_args: object, **_kwargs: object) -> Path:
        raise PluginCreationError("stage failed")

    monkeypatch.setattr(sys.modules[__name__], "stage_plugin", fail)
    result = CliRunner().invoke(
        cli, ["create", "sample", "--path", str(tmp_path), "--yes"]
    )
    assert result.exit_code == 1
    assert "stage failed" in result.stderr

    monkeypatch.setattr(
        sys.modules[__name__],
        "stage_plugin",
        lambda *_args, **_kwargs: Path(tempfile.mkdtemp(dir=tmp_path)),
    )

    def fail_publish(*_args: object, **_kwargs: object) -> None:
        raise PluginCreationError("publish failed")

    monkeypatch.setattr(sys.modules[__name__], "publish_plugin", fail_publish)
    result = CliRunner().invoke(
        cli, ["create", "second", "--path", str(tmp_path), "--yes"]
    )
    assert result.exit_code == 1
    assert "publish failed" in result.stderr


def test_compact_and_unit_test_harness(monkeypatch: pytest.MonkeyPatch) -> None:
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
    result = CliRunner().invoke(unit_test_command)
    assert result.exit_code == 0 and result.stdout == "TOTAL\n"
    assert "COVERAGE_FILE" not in os.environ


def test_unit_test_harness_restores_existing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("COVERAGE_FILE", "existing")
    monkeypatch.setattr(pytest, "main", lambda _arguments: pytest.ExitCode.OK)
    result = CliRunner().invoke(unit_test_command)
    assert result.exit_code == 0
    assert os.environ["COVERAGE_FILE"] == "existing"


def test_help_logging_and_entrypoint(capsys: pytest.CaptureFixture[str]) -> None:
    result = CliRunner().invoke(cli, ["--help"])
    assert result.exit_code == 0 and "unit-test" in result.stdout
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
    assert process.returncode == 0 and "Create local Codex" in process.stdout


if __name__ == "__main__":
    cli()
