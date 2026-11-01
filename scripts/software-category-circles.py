#!/usr/bin/env python3
"""Render software overlap from the evaluated machine configurations."""

import html
import importlib.util
import json
from pathlib import Path

import module_map

ROOT = Path(__file__).resolve().parent.parent
WORK = {"loki", "mimir2"}
HOME_LAPTOPS = {"donar", "frigg"}
NAMES = ("Home", "Work", "Virtual")
POSITIONS = (
    (130, 145),
    (330, 145),
    (230, 120),
    (230, 310),
    (170, 230),
    (290, 230),
    (230, 195),
)


def render(machines: list[dict]) -> str:
    categories = {name: [] for name in NAMES}
    for machine in machines:
        category = (
            "Virtual"
            if machine["kind"] == "virtual"
            else "Work"
            if machine["name"] in WORK
            else "Home"
        )
        categories[category].append(machine)
    groups = {mask: set() for mask in range(1, 8)}
    memberships = {}
    for bit, category in enumerate(NAMES):
        for machine in categories[category]:
            for package in machine["packages"]:
                name = package["name"]
                if name == "coreutils-full":
                    name = "coreutils"
                memberships[name] = memberships.get(name, 0) | (1 << bit)
    for name, mask in memberships.items():
        groups[mask].add(name)
    branches = {
        category: "".join(
            f"<li>{html.escape(m['name'])}</li>"
            for m in sorted(machines, key=lambda m: m["name"])
        )
        for category, machines in categories.items()
    }
    home_branches = {
        label: "".join(
            f"<li>{html.escape(machine['name'])}</li>"
            for machine in sorted(categories["Home"], key=lambda m: m["name"])
            if (machine["name"] in HOME_LAPTOPS) == (label == "Laptop")
        )
        for label in ("Desktop", "Laptop")
    }
    markers, rows = [], []
    for mask, (x, y) in enumerate(POSITIONS, 1):
        names = " + ".join(name for bit, name in enumerate(NAMES) if mask & (1 << bit))
        packages = groups[mask]
        markers.append(
            f'<a href="#group-{mask}"><title>{names}: {len(packages)} packages</title><circle cx="{x}" cy="{y}" r="17" fill="white" stroke="#34495e"/><text x="{x}" y="{y}" text-anchor="middle" dominant-baseline="central">{len(packages)}</text></a>'
        )
        items = "".join(f"<li>{html.escape(name)}</li>" for name in sorted(packages))
        rows.append(
            f'<tr id="group-{mask}"><td>{names}</td><td>{len(packages)}</td><td><details><summary>Package names</summary><ul>{items}</ul></details></td></tr>'
        )
    return f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Software overlap by machine category</title>
<style>body{{font:15px/1.5 system-ui;color:#243848;background:#f3f6f8;margin:24px auto;max-width:1200px;padding:0 20px}}.overview{{display:grid;grid-template-columns:minmax(0,2fr) minmax(240px,1fr);gap:20px;align-items:start}}svg,.tree,table{{width:100%;background:white;border:1px solid #d9e2e8;border-radius:8px;box-sizing:border-box}}.tree{{padding:0 16px}}th,td{{text-align:left;padding:8px;border-bottom:1px solid #d9e2e8;vertical-align:top}}tr:target{{background:#fff1bd}}summary{{cursor:pointer}}li{{overflow-wrap:anywhere}}@media(max-width:750px){{.overview{{grid-template-columns:1fr}}}}</style>
<nav aria-label="Overlap views">Category overlap · <a href="six-circles.html">Six physical machines</a></nav>
<h1>Software overlap by machine category</h1><p>Each count is an exact combination of categories. Physical is the union of Home and Work. All contains every category. Click a count for its package names.</p><p>Packages are grouped by name across the machines in each category; coreutils-full is counted as coreutils. Areas are schematic.</p>
<div class="overview"><svg viewBox="0 0 460 400" role="img" aria-label="Software overlap between home, work and virtual machines"><circle cx="230" cy="200" r="190" fill="#f5f7fa" stroke="#475569"/><text x="230" y="30" text-anchor="middle">All</text><circle cx="180" cy="160" r="100" fill="#2878b5" fill-opacity=".2" stroke="#2878b5"/><circle cx="280" cy="160" r="100" fill="#b86512" fill-opacity=".2" stroke="#b86512"/><circle cx="230" cy="245" r="100" fill="#258046" fill-opacity=".2" stroke="#258046" stroke-width="3" stroke-dasharray="5 4"/><path d="M 230 73.4 A 100 100 0 1 0 230 246.6 A 100 100 0 1 0 230 73.4" fill="none" stroke="#7047a3" stroke-width="3"/><text x="105" y="85" fill="#2878b5">Home</text><text x="315" y="85" fill="#b86512">Work</text><text x="230" y="365" text-anchor="middle" fill="#258046">Virtual (dashed)</text><text x="230" y="55" text-anchor="middle" fill="#7047a3">Physical (outline)</text>{"".join(markers)}</svg>
<section class="tree"><h2>Machine categories</h2><ul><li>All<ul><li>Physical<ul><li>Home<ul><li>Desktop<ul>{home_branches["Desktop"]}</ul></li><li>Laptop<ul>{home_branches["Laptop"]}</ul></li></ul></li><li>Work<ul>{branches["Work"]}</ul></li></ul></li><li>Virtual<ul>{branches["Virtual"]}</ul></li></ul></li></ul></section></div><table><thead><tr><th>Category combination</th><th>Packages</th><th>Details</th></tr></thead><tbody>{"".join(rows)}</tbody></table></html>"""


if __name__ == "__main__":
    raw = json.loads(
        module_map.run(
            [
                "nix",
                "eval",
                "--impure",
                "--json",
                "--file",
                str(ROOT / "scripts/module-graph.nix"),
                "--apply",
                "f: f {}",
            ],
            cwd=ROOT,
        )
    )
    report = module_map.analyze(raw, ROOT)
    output = ROOT / "reports/software-overlap-circles/index.html"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render(report["software"]))
    spec = importlib.util.spec_from_file_location(
        "six_circles", ROOT / "scripts/check-software-overlap-circles.py"
    )
    six = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(six)
    machines = {m["name"]: m for m in report["software"] if m["kind"] == "physical"}
    sets = [{p["name"] for p in machines[name]["packages"]} for name, *_ in six.CIRCLES]
    groups = {}
    for package in set.union(*sets):
        mask = sum(1 << i for i, names in enumerate(sets) if package in names)
        groups.setdefault(mask, []).append(package)
    (output.parent / "six-circles.html").write_text(six.render(groups))
    missing = sorted(groups.keys() - six.LABELS.keys())
    if missing:
        (output.parent / "proof.json").write_text(
            json.dumps({"validated": False, "missing_masks": missing}, indent=2) + "\n"
        )
    else:
        layout = module_map.physical_circle_layout(report)
        (output.parent / "proof.json").write_text(
            json.dumps(
                {
                    "validated": True,
                    "circles": six.CIRCLES,
                    "labels": six.LABELS,
                    "counts": layout["counts"],
                    "required_masks": sorted(groups),
                    "extra_empty_masks": layout["extra_empty_masks"],
                    "minimum_occupied_clearance": layout["minimum_occupied_clearance"],
                },
                indent=2,
            )
            + "\n"
        )
    print(f"Preview: {output.relative_to(ROOT)}")
