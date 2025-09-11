#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "typer>=0.12",
#   "pydantic>=2.9",
#   "structlog>=24.2"
# ]
# ///
from __future__ import annotations

import os
from pathlib import Path
from statistics import mean, median, pstdev, quantiles
from typing import Iterable

import structlog
import typer
from pydantic import BaseModel, Field, ValidationError

logger = structlog.get_logger(__name__)
app = typer.Typer(add_completion=False, no_args_is_help=True)


class Settings(BaseModel):
    path: Path = Field(default=Path("."))
    include_hidden: bool = Field(default=False)
    follow_symlinks: bool = Field(default=False)
    # non-recursive by design for “single folder” stats
    # filters:
    min_size: int | None = Field(default=None, ge=0)  # bytes
    max_size: int | None = Field(default=None, ge=0)  # bytes

    model_config = {
        "strict": True,
        "extra": "forbid",
    }


def iter_file_sizes(
    directory: Path,
    include_hidden: bool,
    follow_symlinks: bool,
) -> Iterable[int]:
    with os.scandir(directory) as it:
        for entry in it:
            if not entry.is_file(follow_symlinks=follow_symlinks):
                continue
            name = entry.name
            if not include_hidden and name.startswith("."):
                continue
            try:
                size = entry.stat(follow_symlinks=follow_symlinks).st_size
            except FileNotFoundError:
                # racing deletes; skip
                continue
            yield int(size)


def filter_sizes(
    sizes: Iterable[int],
    min_size: int | None,
    max_size: int | None,
) -> list[int]:
    out: list[int] = []
    for s in sizes:
        if min_size is not None and s < min_size:
            continue
        if max_size is not None and s > max_size:
            continue
        out.append(s)
    return out


def basic_stats(sizes: list[int]) -> dict[str, float | int]:
    n = len(sizes)
    if n == 0:
        return {
            "files": 0,
            "total_bytes": 0,
            "mean": 0.0,
            "stdev": 0.0,
            "median": 0.0,
            "p25": 0.0,
            "p75": 0.0,
            "min": 0,
            "max": 0,
            "skewness": 0.0,
            "kurtosis": 0.0,
        }
    total = int(sum(sizes))
    mu = float(mean(sizes))
    # population stdev (consistent with skew/kurt formulas below)
    sigma = float(pstdev(sizes)) if n > 1 else 0.0
    med = float(median(sizes))
    try:
        q25, q75 = (
            quantiles(sizes, n=4, method="inclusive")[0],
            quantiles(sizes, n=4, method="inclusive")[2],
        )
    except Exception:
        q25, q75 = med, med

    # central moments
    if sigma > 0.0 and n > 0:
        m3 = sum(((x - mu) / sigma) ** 3 for x in sizes) / n
        m4 = sum(((x - mu) / sigma) ** 4 for x in sizes) / n
        skew = float(m3)
        kurt = float(m4 - 3.0)  # excess kurtosis
    else:
        skew = 0.0
        kurt = 0.0

    return {
        "files": n,
        "total_bytes": total,
        "mean": mu,
        "stdev": sigma,
        "median": med,
        "p25": float(q25),
        "p75": float(q75),
        "min": int(min(sizes)),
        "max": int(max(sizes)),
        "skewness": skew,
        "kurtosis": kurt,
    }


def ascii_bar(count: int, max_count: int, width: int = 40) -> str:
    if max_count <= 0:
        return ""
    filled = int(round((count / max_count) * width))
    return "#" * filled


def render_report(
    stats: dict[str, float | int],
    zero_count: int,
) -> str:
    lines: list[str] = []
    lines.append(f"files: {stats['files']}")
    lines.append(f"total bytes: {stats['total_bytes']}")
    lines.append(f"mean: {int(stats['mean'])}")
    lines.append(f"stdev: {int(stats['stdev'])}")
    lines.append(f"median: {int(stats['median'])}")
    lines.append(f"p25: {int(stats['p25'])}")
    lines.append(f"p75: {int(stats['p75'])}")
    lines.append(f"min: {stats['min']}")
    lines.append(f"max: {stats['max']}")
    lines.append(f"skewness: {stats['skewness']:.4f}")
    lines.append(f"kurtosis: {stats['kurtosis']:.4f}")
    if zero_count:
        lines.append(f"zero-byte files: {zero_count}")
    lines.append("")
    return "\n".join(lines)


@app.command()
def main(
    path: Path = typer.Argument(Path(".")),
    include_hidden: bool = typer.Option(False, "--hidden/--no-hidden"),
    follow_symlinks: bool = typer.Option(
        False, "--follow-symlinks/--no-follow-symlinks"
    ),
    min_size: int | None = typer.Option(None, "--min-size", help="bytes"),
    max_size: int | None = typer.Option(None, "--max-size", help="bytes"),
    bins: int = typer.Option(12, "--bins", min=1, max=200),
    log_bins: int = typer.Option(12, "--log-bins", min=1, max=200),
) -> None:
    try:
        settings = Settings(
            path=path,
            include_hidden=include_hidden,
            follow_symlinks=follow_symlinks,
            min_size=min_size,
            max_size=max_size,
        )
    except ValidationError as e:
        raise typer.Exit(code=2) from e

    sizes_all = list(
        iter_file_sizes(
            directory=settings.path,
            include_hidden=settings.include_hidden,
            follow_symlinks=settings.follow_symlinks,
        )
    )
    sizes = filter_sizes(
        sizes_all,
        min_size=settings.min_size,
        max_size=settings.max_size,
    )
    zero_count = sum(1 for s in sizes if s == 0)

    s = basic_stats(sizes)

    report = render_report(s, zero_count)
    print(report)


if __name__ == "__main__":
    app()
