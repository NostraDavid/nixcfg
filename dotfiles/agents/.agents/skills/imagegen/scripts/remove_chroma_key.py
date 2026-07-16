#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "click==8.4.2",
#     "numpy==2.5.1",
#     "pillow==12.3.0",
#     "pydantic==2.12.5",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "regex==2026.2.28",
#     "structlog==26.1.0",
# ]
# ///
"""Remove a solid chroma-key background from an image.

This helper supports the imagegen skill's built-in-first transparent workflow:
generate an image on a flat key color, then convert that key color to alpha.
"""

from __future__ import annotations

import contextlib
from io import BytesIO
import io
import os
from pathlib import Path
import subprocess as sp
import sys
import tempfile
from typing import Tuple

import click
import numpy as np
import pytest
import regex as re
import structlog as sl
import structlog.stdlib as log
from click.testing import CliRunner
from pydantic import BaseModel


Color = Tuple[int, int, int]
KEY_DOMINANCE_THRESHOLD = 16.0
ALPHA_NOISE_FLOOR = 8
logger = log.get_logger(__name__)


class ChromaKeyError(Exception):
    """Report an expected input, image, or output failure."""


class ChromaOptions(BaseModel):
    """Hold validated chroma-key processing settings."""

    input: Path
    out: Path
    key_color: str = "#00ff00"
    tolerance: int = 12
    auto_key: str = "none"
    soft_matte: bool = False
    transparent_threshold: float = 12.0
    opaque_threshold: float = 96.0
    edge_feather: float = 0.0
    edge_contract: int = 0
    spill_cleanup: bool = False
    force: bool = False


def _die(message: str, code: int = 1) -> None:
    del code
    raise ChromaKeyError(message)


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


def _dependency_hint(package: str) -> str:
    return (
        "Activate the repo-selected environment first, then install it with "
        f"`uv pip install {package}`. If this repo uses a local virtualenv, start with "
        "`source .venv/bin/activate`; otherwise use this repo's configured shared fallback "
        "environment."
    )


def _load_pillow():
    try:
        from PIL import Image, ImageFilter
    except ImportError:
        _die(f"Pillow is required for chroma-key removal. {_dependency_hint('pillow')}")
    return Image, ImageFilter


def _parse_key_color(raw: str) -> Color:
    value = raw.strip()
    match = re.fullmatch(r"#?([0-9a-fA-F]{6})", value)
    if not match:
        _die("key color must be a hex RGB value like #00ff00.")
    hex_value = match.group(1)
    return (
        int(hex_value[0:2], 16),
        int(hex_value[2:4], 16),
        int(hex_value[4:6], 16),
    )


def _validate_args(args: ChromaOptions) -> None:
    if args.tolerance < 0 or args.tolerance > 255:
        _die("--tolerance must be between 0 and 255.")
    if args.transparent_threshold < 0 or args.transparent_threshold > 255:
        _die("--transparent-threshold must be between 0 and 255.")
    if args.opaque_threshold < 0 or args.opaque_threshold > 255:
        _die("--opaque-threshold must be between 0 and 255.")
    if args.soft_matte and args.transparent_threshold >= args.opaque_threshold:
        _die("--transparent-threshold must be lower than --opaque-threshold.")
    if args.edge_feather < 0 or args.edge_feather > 64:
        _die("--edge-feather must be between 0 and 64.")
    if args.edge_contract < 0 or args.edge_contract > 16:
        _die("--edge-contract must be between 0 and 16.")

    src = Path(args.input)
    if not src.exists():
        _die(f"Input image not found: {src}")

    out = Path(args.out)
    if out.exists() and not args.force:
        _die(f"Output already exists: {out} (use --force to overwrite)")

    if out.suffix.lower() not in {".png", ".webp"}:
        _die("--out must end in .png or .webp so the alpha channel is preserved.")


def _channel_distance(a: Color, b: Color) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2]))


def _clamp_channel(value: float) -> int:
    return max(0, min(255, int(round(value))))


def _smoothstep(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def _soft_alpha(
    distance: int, transparent_threshold: float, opaque_threshold: float
) -> int:
    if distance <= transparent_threshold:
        return 0
    if distance >= opaque_threshold:
        return 255
    ratio = (float(distance) - transparent_threshold) / (
        opaque_threshold - transparent_threshold
    )
    return _clamp_channel(255.0 * _smoothstep(ratio))


def _dominance_alpha(rgb: Color, key: Color) -> int:
    spill_channels = _spill_channels(key)
    if not spill_channels:
        return 255

    channels = [float(value) for value in rgb]
    non_spill = [idx for idx in range(3) if idx not in spill_channels]
    key_strength = (
        min(channels[idx] for idx in spill_channels)
        if len(spill_channels) > 1
        else channels[spill_channels[0]]
    )
    non_key_strength = max((channels[idx] for idx in non_spill), default=0.0)
    dominance = key_strength - non_key_strength
    if dominance <= 0:
        return 255

    denominator = max(1.0, float(max(key)) - non_key_strength)
    alpha = 1.0 - min(1.0, dominance / denominator)
    return _clamp_channel(alpha * 255.0)


def _spill_channels(key: Color) -> list[int]:
    key_max = max(key)
    if key_max < 128:
        return []
    return [
        idx for idx, value in enumerate(key) if value >= key_max - 16 and value >= 128
    ]


def _key_channel_dominance(rgb: Color, key: Color) -> float:
    spill_channels = _spill_channels(key)
    if not spill_channels:
        return 0.0

    channels = [float(value) for value in rgb]
    non_spill = [idx for idx in range(3) if idx not in spill_channels]
    key_strength = (
        min(channels[idx] for idx in spill_channels)
        if len(spill_channels) > 1
        else channels[spill_channels[0]]
    )
    non_key_strength = max((channels[idx] for idx in non_spill), default=0.0)
    return key_strength - non_key_strength


def _looks_key_colored(rgb: Color, key: Color, distance: int) -> bool:
    if distance <= 32:
        return True

    spill_channels = _spill_channels(key)
    if not spill_channels:
        return True

    return _key_channel_dominance(rgb, key) >= KEY_DOMINANCE_THRESHOLD


def _cleanup_spill(rgb: Color, key: Color, alpha: int = 255) -> Color:
    if alpha >= 252:
        return rgb

    spill_channels = _spill_channels(key)
    if not spill_channels:
        return rgb

    channels = [float(value) for value in rgb]
    non_spill = [idx for idx in range(3) if idx not in spill_channels]
    if non_spill:
        anchor = max(channels[idx] for idx in non_spill)
        cap = max(0.0, anchor - 1.0)
        for idx in spill_channels:
            if channels[idx] > cap:
                channels[idx] = cap

    return (
        _clamp_channel(channels[0]),
        _clamp_channel(channels[1]),
        _clamp_channel(channels[2]),
    )


def _apply_alpha_to_image(
    image,
    *,
    key: Color,
    tolerance: int,
    spill_cleanup: bool,
    soft_matte: bool,
    transparent_threshold: float,
    opaque_threshold: float,
) -> int:
    pixels = image.load()
    width, height = image.size
    transparent = 0

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            rgb = (red, green, blue)
            distance = _channel_distance(rgb, key)
            key_like = _looks_key_colored(rgb, key, distance)
            output_alpha = (
                min(
                    _soft_alpha(distance, transparent_threshold, opaque_threshold),
                    _dominance_alpha(rgb, key),
                )
                if soft_matte and key_like
                else (0 if distance <= tolerance else 255)
            )
            output_alpha = int(round(output_alpha * (alpha / 255.0)))
            if 0 < output_alpha <= ALPHA_NOISE_FLOOR:
                output_alpha = 0

            if output_alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
                transparent += 1
                continue

            if spill_cleanup and key_like:
                red, green, blue = _cleanup_spill(rgb, key, output_alpha)
            pixels[x, y] = (red, green, blue, output_alpha)

    return transparent


def _contract_alpha(image, pixels: int):
    if pixels == 0:
        return image

    _, ImageFilter = _load_pillow()
    alpha = image.getchannel("A")
    for _ in range(pixels):
        alpha = alpha.filter(ImageFilter.MinFilter(3))
    image.putalpha(alpha)
    return image


def _apply_edge_feather(image, radius: float):
    if radius == 0:
        return image

    _, ImageFilter = _load_pillow()
    alpha = image.getchannel("A")
    alpha = alpha.filter(ImageFilter.GaussianBlur(radius=radius))
    image.putalpha(alpha)
    return image


def _encode_image(image, output_format: str) -> bytes:
    out = BytesIO()
    image.save(out, format=output_format.upper())
    return out.getvalue()


def _alpha_counts(image) -> tuple[int, int, int]:
    pixels = image.load()
    width, height = image.size
    total = 0
    transparent = 0
    partial = 0

    for y in range(height):
        for x in range(width):
            alpha = pixels[x, y][3]
            total += 1
            if alpha == 0:
                transparent += 1
            elif alpha < 255:
                partial += 1

    return total, transparent, partial


def _sample_border_key(image, mode: str) -> Color:
    width, height = image.size
    pixels = image.load()
    samples: list[Color] = []

    if mode == "corners":
        patch = max(1, min(width, height, 12))
        boxes = [
            (0, 0, patch, patch),
            (width - patch, 0, width, patch),
            (0, height - patch, patch, height),
            (width - patch, height - patch, width, height),
        ]
        for left, top, right, bottom in boxes:
            for y in range(top, bottom):
                for x in range(left, right):
                    red, green, blue = pixels[x, y][:3]
                    samples.append((red, green, blue))
    else:
        band = max(1, min(width, height, 6))
        step = max(1, min(width, height) // 256)
        for x in range(0, width, step):
            for y in range(band):
                red, green, blue = pixels[x, y][:3]
                samples.append((red, green, blue))
                red, green, blue = pixels[x, height - 1 - y][:3]
                samples.append((red, green, blue))
        for y in range(0, height, step):
            for x in range(band):
                red, green, blue = pixels[x, y][:3]
                samples.append((red, green, blue))
                red, green, blue = pixels[width - 1 - x, y][:3]
                samples.append((red, green, blue))

    if not samples:
        _die("Could not sample background key color from image border.")

    return (
        int(round(float(np.median([sample[0] for sample in samples])))),
        int(round(float(np.median([sample[1] for sample in samples])))),
        int(round(float(np.median([sample[2] for sample in samples])))),
    )


def _write_atomic(path: Path, payload: bytes) -> None:
    """Create or replace an image atomically."""
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode if path.exists() else 0o644
    descriptor, raw_temp_path = tempfile.mkstemp(
        prefix=f".{path.name}.", dir=path.parent
    )
    temp_path = Path(raw_temp_path)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_path, mode)
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def _remove_chroma_key(args: ChromaOptions) -> None:
    Image, _ = _load_pillow()
    src = Path(args.input)
    out = Path(args.out)

    with Image.open(src) as image:
        rgba = image.convert("RGBA")
    key = (
        _sample_border_key(rgba, args.auto_key)
        if args.auto_key != "none"
        else _parse_key_color(args.key_color)
    )

    transparent = _apply_alpha_to_image(
        rgba,
        key=key,
        tolerance=args.tolerance,
        spill_cleanup=args.spill_cleanup,
        soft_matte=args.soft_matte,
        transparent_threshold=args.transparent_threshold,
        opaque_threshold=args.opaque_threshold,
    )
    rgba = _contract_alpha(rgba, args.edge_contract)
    rgba = _apply_edge_feather(rgba, args.edge_feather)

    total, transparent_after, partial_after = _alpha_counts(rgba)

    output_format = "PNG" if out.suffix.lower() == ".png" else "WEBP"
    _write_atomic(out, _encode_image(rgba, output_format))

    click.echo(f"Wrote {out}")
    click.echo(f"Key color: #{key[0]:02x}{key[1]:02x}{key[2]:02x}")
    click.echo(f"Transparent pixels: {transparent_after}/{total}")
    click.echo(f"Partially transparent pixels: {partial_after}/{total}")
    if transparent == 0:
        logger.warning("no_key_pixels_matched", input=str(src), key=key)


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
    """Create transparent images from chroma-key inputs."""
    configure_logging()


@cli.command(name="remove")
@click.option(
    "--input",
    "input_path",
    type=click.Path(path_type=Path, exists=True, dir_okay=False),
    required=True,
)
@click.option("--out", type=click.Path(path_type=Path, dir_okay=False), required=True)
@click.option("--key-color", default="#00ff00", show_default=True)
@click.option("--tolerance", type=int, default=12, show_default=True)
@click.option(
    "--auto-key", type=click.Choice(("none", "corners", "border")), default="none"
)
@click.option("--soft-matte", is_flag=True)
@click.option("--transparent-threshold", type=float, default=12.0)
@click.option("--opaque-threshold", type=float, default=96.0)
@click.option("--edge-feather", type=float, default=0.0)
@click.option("--edge-contract", type=int, default=0)
@click.option("--spill-cleanup", "spill_cleanup", is_flag=True)
@click.option("--despill", "spill_cleanup", flag_value=True)
@click.option("--force", is_flag=True)
@click.option("--dry-run", is_flag=True, help="Validate without writing an image.")
@click.option("--yes", is_flag=True, help="Write without interactive confirmation.")
def remove_command(
    input_path: Path,
    out: Path,
    key_color: str,
    tolerance: int,
    auto_key: str,
    soft_matte: bool,
    transparent_threshold: float,
    opaque_threshold: float,
    edge_feather: float,
    edge_contract: int,
    spill_cleanup: bool,
    force: bool,
    dry_run: bool,
    yes: bool,
) -> None:
    """Remove a solid background and write alpha to --out."""
    options = ChromaOptions(
        input=input_path,
        out=out,
        key_color=key_color,
        tolerance=tolerance,
        auto_key=auto_key,
        soft_matte=soft_matte,
        transparent_threshold=transparent_threshold,
        opaque_threshold=opaque_threshold,
        edge_feather=edge_feather,
        edge_contract=edge_contract,
        spill_cleanup=spill_cleanup,
        force=force,
    )
    try:
        _validate_args(options)
    except ChromaKeyError as exc:
        raise click.ClickException(str(exc)) from exc
    if dry_run:
        click.echo(f"Would remove chroma key from {input_path} into {out}")
        return
    if not yes:
        click.confirm(f"Write {out}?", abort=True)
    try:
        _remove_chroma_key(options)
    except (OSError, ChromaKeyError) as exc:
        raise click.ClickException(str(exc)) from exc


@click.command(name="unit-test")
def unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="chroma-key-coverage-") as directory:
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


def test_color_and_alpha_helpers() -> None:
    assert _parse_key_color("#00ff80") == (0, 255, 128)
    with pytest.raises(ChromaKeyError, match="hex RGB"):
        _parse_key_color("bad")
    assert _channel_distance((0, 1, 2), (2, 1, 0)) == 2
    assert _clamp_channel(-1) == 0 and _clamp_channel(300) == 255
    assert _smoothstep(-1) == 0 and _smoothstep(2) == 1
    assert _soft_alpha(0, 10, 20) == 0
    assert _soft_alpha(30, 10, 20) == 255
    assert 0 < _soft_alpha(15, 10, 20) < 255
    assert _spill_channels((0, 255, 0)) == [1]
    assert _spill_channels((10, 20, 30)) == []
    assert _dominance_alpha((0, 255, 0), (0, 255, 0)) == 0
    assert _looks_key_colored((0, 255, 0), (0, 255, 0), 0)
    assert _cleanup_spill((0, 255, 0), (0, 255, 0), 0)[1] == 0


@pytest.mark.parametrize(
    ("updates", "message"),
    [
        ({"tolerance": -1}, "tolerance"),
        ({"transparent_threshold": 300}, "transparent-threshold"),
        ({"opaque_threshold": -1}, "opaque-threshold"),
        (
            {"soft_matte": True, "transparent_threshold": 20, "opaque_threshold": 10},
            "lower",
        ),
        ({"edge_feather": 65}, "edge-feather"),
        ({"edge_contract": 17}, "edge-contract"),
    ],
)
def test_validate_options_ranges(
    tmp_path: Path, updates: dict[str, object], message: str
) -> None:
    source = tmp_path / "input.png"
    source.write_bytes(b"x")
    options = ChromaOptions(input=source, out=tmp_path / "out.png").model_copy(
        update=updates
    )
    with pytest.raises(ChromaKeyError, match=message):
        _validate_args(options)


def test_remove_command_dry_run_and_image(tmp_path: Path) -> None:
    Image, _ = _load_pillow()
    source = tmp_path / "input.png"
    image = Image.new("RGBA", (2, 1), (0, 255, 0, 255))
    image.putpixel((1, 0), (255, 0, 0, 255))
    image.save(source)
    output = tmp_path / "out.png"
    runner = CliRunner()
    dry = runner.invoke(
        cli, ["remove", "--input", str(source), "--out", str(output), "--dry-run"]
    )
    assert dry.exit_code == 0 and not output.exists()
    result = runner.invoke(
        cli, ["remove", "--input", str(source), "--out", str(output)], input="y\n"
    )
    assert result.exit_code == 0 and output.exists()
    with Image.open(output) as processed:
        assert processed.getpixel((0, 0))[3] == 0


def test_remove_command_reports_validation_error(tmp_path: Path) -> None:
    source = tmp_path / "input.png"
    source.write_bytes(b"x")
    result = CliRunner().invoke(
        cli,
        [
            "remove",
            "--input",
            str(source),
            "--out",
            str(tmp_path / "bad.jpg"),
            "--dry-run",
        ],
    )
    assert result.exit_code == 1 and "png or .webp" in result.stderr


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
    assert process.returncode == 0 and "transparent images" in process.stdout


if __name__ == "__main__":
    cli()
