#!/usr/bin/env python3
"""Rotate terminal contents together with their two- or three-pane layout."""

import argparse
import fcntl
import json
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Pane:
    id: int
    x: int
    y: int
    width: int
    height: int


def reading_order(pane: Pane) -> tuple[int, int]:
    return pane.y, pane.x


def main_edge(panes: list[Pane]) -> tuple[Pane, str] | None:
    """Find the full side of an L, including its half-width/height flattened form."""
    if len(panes) != 3:
        return None
    left = min(p.x for p in panes)
    top = min(p.y for p in panes)
    width = max(p.x + p.width for p in panes) - left
    height = max(p.y + p.height for p in panes) - top
    for pane in panes:
        if (
            pane.height == height
            and pane.x in {left, left + width - pane.width}
            and (
                any(other.height != height for other in panes)
                or abs(2 * pane.width - width) <= 2
            )
        ):
            return pane, "left" if pane.x == left else "right"
        if (
            pane.width == width
            and pane.y in {top, top + height - pane.height}
            and (
                any(other.width != width for other in panes)
                or abs(2 * pane.height - height) <= 2
            )
        ):
            return pane, "top" if pane.y == top else "bottom"
    return None


def rotation_plan(
    panes: list[Pane], clockwise: bool, focused: int | None
) -> tuple[str, list[int], int | None] | None:
    side = main_edge(panes)
    rotating = panes
    if side:
        main, edge = side
        peers = [p for p in panes if p != main]
        flat = (
            peers[0].y == peers[1].y
            if edge in ("left", "right")
            else peers[0].x == peers[1].x
        )
        if focused is not None:
            if focused == main.id:
                return None
            # The named layouts split the outer area in half. Don't resize an
            # untouched pane when only its neighbours were asked to rotate.
            horizontal_axis = edge in ("left", "right")
            size = main.width if horizontal_axis else main.height
            group_size = (
                max(p.x + p.width for p in peers) - min(p.x for p in peers)
                if horizontal_axis
                else max(p.y + p.height for p in peers) - min(p.y for p in peers)
            )
            if abs(size - group_size) > 1:
                return None
            rotating = peers
            flat = not flat
        else:
            edges = ("left", "top", "right", "bottom")
            edge = edges[(edges.index(edge) + (1 if clockwise else -1)) % 4]
        layout = "main-" + edge + ("-flat" if flat else "")
    else:
        if focused is not None and len(panes) != 2:
            return None
        layout = "rows" if panes[0].y == panes[1].y else "columns"

    # Top-to-bottom, then left-to-right, as seen after the requested turn.
    order = sorted(
        rotating,
        key=lambda p: (p.x, -p.y - p.height) if clockwise else (-p.x - p.width, p.y),
    )
    return (
        layout,
        [p.id for p in order],
        side[0].id if focused is not None and side else None,
    )


def action(*args: str) -> str:
    executable = shutil.which("zellij")
    if executable is None:
        raise SystemExit("zellij is missing from PATH")
    return subprocess.check_output(  # noqa: S603 - Fixed executable and separate arguments.
        [executable, "--session", os.environ["ZELLIJ_SESSION_NAME"], "action", *args],
        text=True,
        timeout=5,
    )


def visible_terminals(focused: int) -> tuple[int, list[Pane]]:
    rows = json.loads(action("list-panes", "--all", "--json"))
    source = next((p for p in rows if not p["is_plugin"] and p["id"] == focused), None)
    if source is None:
        return -1, []
    tab = source["tab_id"]
    tiles = [
        p
        for p in rows
        if p["tab_id"] == tab
        and p["is_selectable"]
        and not p["is_suppressed"]
        and not p["is_floating"]
    ]
    if source not in tiles or any(
        p["is_plugin"] or p["is_fullscreen"] or p["is_collapsed"] for p in tiles
    ):
        return tab, []
    return tab, sorted(
        (
            Pane(p["id"], p["pane_x"], p["pane_y"], p["pane_columns"], p["pane_rows"])
            for p in tiles
        ),
        key=reading_order,
    )


def rotate(clockwise: bool, pair: bool, focused: int) -> None:
    tab, panes = visible_terminals(focused)
    if len(panes) < 2:
        return
    if len(panes) > 3:
        if not pair:
            action(
                "next-swap-layout" if clockwise else "previous-swap-layout",
                "--tab-id",
                str(tab),
            )
        return
    plan = rotation_plan(panes, clockwise, focused if pair else None)
    if plan is None:
        return
    layout, wanted, stationary = plan
    action("apply-tiled-swap-layout", layout, "--tab-id", str(tab))
    _, result = visible_terminals(focused)
    current = [p.id for p in result]
    if set(current) != {p.id for p in panes}:
        return
    if stationary is not None:
        new_side = main_edge(result)
        if new_side is None:
            return
        wanted.insert(result.index(new_side[0]), stationary)

    # Zellij matches existing panes to slots independently of rotation. Its
    # move-pane action swaps adjacent selectable panes in cyclic reading order.
    for i, target in enumerate(wanted):
        j = current.index(target)
        if i != j:
            move = "move-pane" if (j + 1) % len(current) == i else "move-pane-backwards"
            action(move, "--pane-id", f"terminal_{target}")
            current[i], current[j] = current[j], current[i]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("direction", choices=("cw", "ccw"))
    parser.add_argument("--pair", action="store_true")
    args = parser.parse_args()
    # Background key actions can overlap on key repeat.
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "zellij"
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (cache / "rotate.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        origin = os.environ.get("ZELLIJ_ORIGIN_PANE_ID", "")
        if origin.startswith("terminal_"):
            rotate(
                args.direction == "cw", args.pair, int(origin.removeprefix("terminal_"))
            )
