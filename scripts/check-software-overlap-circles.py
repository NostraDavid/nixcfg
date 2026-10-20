#!/usr/bin/env python3
"""Verify a six-circle construction against the evaluated software snapshot."""

import html
import json
from pathlib import Path

from module_map import CIRCLES, LABELS, physical_circle_layout

ROOT = Path(__file__).resolve().parent.parent
COLORS = ["#2878b5", "#b86512", "#258046", "#8557ac", "#bf4050", "#148485"]


def host_names(mask: int) -> str:
    return " + ".join(
        name for i, (name, *_rest) in enumerate(CIRCLES) if mask & (1 << i)
    )


def render(groups: dict[int, list[str]]) -> str:
    shapes, markers, rows, legend = [], [], [], []
    for (name, x, y, r), color in zip(CIRCLES, COLORS, strict=True):
        shapes.append(
            f'<circle data-host="{name}" cx="{x}" cy="{-y}" r="{r}" fill="{color}" fill-opacity=".10" stroke="{color}" stroke-width=".007"/>'
        )
        legend.append(f'<span style="border-bottom:3px solid {color}">{name}</span>')
    for mask, (x, y) in LABELS.items():
        packages = groups.get(mask, [])
        count = len(packages)
        title = html.escape(f"{host_names(mask)}: {count} packages")
        radius = 0.032 + 0.01 * len(str(count))
        bubble = (
            f'<circle r="{radius}" fill="white" stroke="#34495e" stroke-width=".003"/>'
            if count
            else ""
        )
        text_color = "#243848" if count else "#667988"
        markers.append(
            f'<a href="#group-{mask}" data-mask="{mask}" transform="translate({x},{-y})"><title>{title}</title>{bubble}<text text-anchor="middle" dominant-baseline="central" font-size="{0.045 if count else 0.035}" fill="{text_color}">{count}</text></a>'
        )
        package_list = "".join(f"<li>{html.escape(p)}</li>" for p in sorted(packages))
        rows.append(
            f'<tr id="group-{mask}"><td>{html.escape(host_names(mask))}</td><td>{count}</td><td><details><summary>Package names</summary><ul>{package_list}</ul></details></td></tr>'
        )
    return f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Six-circle software overlap study</title><link rel="icon" href="data:,">
<style>body{{font:15px/1.5 system-ui;color:#243848;background:#f3f6f8;margin:24px auto;max-width:1100px;padding:0 20px}}svg,table{{width:100%;background:white;border:1px solid #d9e2e8;border-radius:8px}}.legend{{display:flex;gap:16px;flex-wrap:wrap;margin:20px 0}}.legend span{{padding:4px 8px}}th,td{{text-align:left;padding:8px;border-bottom:1px solid #d9e2e8;vertical-align:top}}tr:target{{background:#fff1bd}}a:focus-visible text,a:hover text{{font-weight:bold}}li{{overflow-wrap:anywhere}}</style>
<h1>All six physical machines, using circles</h1>
<p>{len(groups)} nonempty groups · {sum(map(len, groups.values()))} package names. Each numbered marker is one exact host combination. Click a number for its package list.</p>
<p>Areas do not represent package counts. Gray zeroes are empty combinations. A combination can have disconnected parts; its count is shown once.</p>
<div class="legend">{"".join(legend)}</div>
<svg viewBox="-1.65 -1.3 2.95 2.9" role="group" aria-label="Six physical host circles">{"".join(shapes)}{"".join(markers)}</svg>
<table><thead><tr><th>Host combination</th><th>Packages</th><th>Details</th></tr></thead><tbody>{"".join(rows)}</tbody></table></html>
"""


def main() -> None:
    report = json.loads((ROOT / "docs/module-map.json").read_text())
    layout = physical_circle_layout(report)
    groups = layout["groups"]
    output = ROOT / "reports/software-overlap-circles"
    output.mkdir(parents=True, exist_ok=True)
    proof = {
        "circles": CIRCLES,
        "labels": LABELS,
        "counts": layout["counts"],
        "required_masks": sorted(groups),
        "extra_empty_masks": layout["extra_empty_masks"],
        "minimum_occupied_clearance": layout["minimum_occupied_clearance"],
    }
    (output / "proof.json").write_text(json.dumps(proof, indent=2) + "\n")
    (output / "index.html").write_text(render(groups))
    print(
        f"PASS: {len(groups)} occupied combinations, {sum(map(len, groups.values()))} packages, "
        f"{len(layout['extra_empty_masks'])} additional empty combinations"
    )
    print(f"Preview: {output.relative_to(ROOT)}/index.html")


if __name__ == "__main__":
    main()
