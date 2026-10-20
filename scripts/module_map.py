#!/usr/bin/env python3
"""Generate the repository's module diagrams from evaluated Nix import graphs."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess as sp
import sys
from pathlib import Path
from typing import NotRequired, TypedDict


class Composition(TypedDict):
    name: str
    kind: str
    nodes: list[dict[str, str]]
    edges: list[list[str]]


class Record(TypedDict):
    file: str
    parent: str | None
    disabled: bool


class Machine(TypedDict):
    name: str
    kind: str
    system: list[Record]
    home: dict[str, list[Record]]


class Graphs(TypedDict):
    schema: int
    wiring: list[Record]
    machines: list[Machine]
    variants: list[Machine]
    compositions: NotRequired[list[Composition]]
    policy: NotRequired[dict]
    catalogue: NotRequired[list[Record]]
    software: NotRequired[list[dict]]


class Context(TypedDict):
    id: str
    label: str
    kind: str
    modules: list[str]
    edges: list[list[str]]
    roots: list[str]
    disabled: list[str]
    layers: dict[str, list[str]]
    composition: NotRequired[Composition]


class Module(TypedDict):
    path: str
    lines: int
    sha256: str
    contexts: list[str]
    parents: list[str]
    children: list[str]
    status: str
    merge_into: str | None
    kind: str


class Report(TypedDict):
    schema: int
    generator: str
    contexts: list[Context]
    modules: list[Module]
    policy: dict
    software: list[dict]


def run(command: list[str], *, cwd: Path, source: str | None = None) -> str:
    result = sp.run(  # noqa: S603
        command,
        cwd=cwd,
        input=source,
        text=True,
        capture_output=True,
        timeout=600,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(f"{command[0]} failed:\n{result.stderr.strip()}")
    return result.stdout


def context(name: str, kind: str, layers: dict[str, list[Record]]) -> Context:
    records = [record for layer in layers.values() for record in layer]
    members = {record["file"] for record in records if not record["disabled"]}
    edges = {
        (record["parent"], record["file"])
        for record in records
        if not record["disabled"]
        and record["parent"] in members
        and record["parent"] != record["file"]
    }
    return {
        "id": f"{kind}:{name}",
        "label": name,
        "kind": kind,
        "modules": sorted(members),
        "edges": [list(edge) for edge in sorted(edges)],
        "roots": sorted(members - {child for _, child in edges}),
        "disabled": sorted({r["file"] for r in records if r["disabled"]} - members),
        "layers": {
            name: sorted({r["file"] for r in layer if not r["disabled"]})
            for name, layer in layers.items()
        },
    }


def module_status(users: list[str], *, disabled: bool) -> str:
    if not users:
        return "disabled" if disabled else "unobserved"
    if all(user.startswith("wiring:") for user in users):
        return "wiring-only"
    if all(user.startswith(("wiring:", "optional:")) for user in users):
        return "optional-only"
    return "used"


def analyze(graphs: Graphs, root: Path) -> Report:
    if graphs["schema"] != 1:
        raise ValueError("Unsupported Nix graph schema")
    contexts = [context("Flake wiring", "wiring", {"flake": graphs["wiring"]})]
    if graphs.get("catalogue"):
        contexts.append(
            context("Registered Den aspects", "wiring", {"flake": graphs["catalogue"]})
        )
    contexts.extend(
        context(
            machine["name"],
            machine["kind"],
            {
                "system": machine["system"],
                **{
                    f"home:{user}": records for user, records in machine["home"].items()
                },
            },
        )
        for machine in graphs["machines"] + graphs["variants"]
    )
    for composition in graphs.get("compositions", []):
        item = next(
            c
            for c in contexts
            if c["id"] == f"{composition['kind']}:{composition['name']}"
        )
        item["composition"] = composition
        item["layers"]["aspects"] = sorted(
            {node["file"] for node in composition["nodes"]}
        )
    paths = {"flake.nix"} | {
        path.relative_to(root).as_posix()
        for directory in (
            "features",
            "profiles",
            "nix",
            "policy",
            "modules",
            "hosts",
        )
        for path in (root / directory).rglob("*.nix")
    }
    paths |= {path for item in contexts for path in item["modules"] + item["disabled"]}
    paths |= {path for item in contexts for path in item["layers"].get("aspects", [])}
    edges = {tuple(edge) for item in contexts for edge in item["edges"]}
    modules: list[Module] = []
    for path in sorted(paths):
        source = (root / path).read_bytes()
        users = [
            item["id"]
            for item in contexts
            if any(path in members for members in item["layers"].values())
        ]
        status = module_status(
            users, disabled=any(path in c["disabled"] for c in contexts)
        )
        modules.append(
            {
                "path": path,
                "lines": len(source.splitlines()),
                "sha256": hashlib.sha256(source).hexdigest(),
                "contexts": users,
                "parents": sorted(parent for parent, child in edges if child == path),
                "children": sorted(child for parent, child in edges if parent == path),
                "status": status,
                "merge_into": None,
                "kind": {
                    "features": "feature",
                    "profiles": "profile",
                    "hosts": "host",
                }.get(path.split("/")[0], "infrastructure"),
            }
        )
    by_path = {module["path"]: module for module in modules}
    for module in modules:
        if (
            module["status"] in {"used", "optional-only"}
            and len(module["parents"]) == 1
            and module["lines"] <= 60
        ):
            parent = by_path[module["parents"][0]]
            if module["contexts"] == parent["contexts"]:
                module["merge_into"] = parent["path"]
    digest = hashlib.sha256()
    for name in ("module-graph.nix", "module_map.py", "module-map.html"):
        digest.update((root / "scripts" / name).read_bytes())
    return {
        "schema": 1,
        "generator": digest.hexdigest(),
        "contexts": contexts,
        "modules": modules,
        "policy": graphs.get("policy", {}),
        "software": [
            {
                "name": machine["name"],
                "kind": next(
                    (
                        node["file"].split("/")[1]
                        for composition in graphs.get("compositions", [])
                        if composition["name"] == machine["name"]
                        for node in composition["nodes"]
                        if node["file"].startswith(
                            ("hosts/physical/", "hosts/virtual/")
                        )
                    ),
                    "unknown",
                ),
                "packages": [
                    {"name": name, "version": version, "origin": origin}
                    for name, version, origin in sorted(
                        {
                            (p["name"], p["version"], p["origin"])
                            for p in machine["packages"]
                        }
                    )
                ],
            }
            for machine in sorted(graphs.get("software", []), key=lambda m: m["name"])
        ],
    }


def composition_dot(item: Context) -> str:
    composition = item["composition"]
    ids = {node["id"]: f"a{index}" for index, node in enumerate(composition["nodes"])}
    rows = [
        'digraph aspects { graph [rankdir=LR, bgcolor="transparent"]; node [shape=box, style="rounded,filled", fontname="sans-serif", fillcolor="#e7eff8"];'
    ]
    for node in composition["nodes"]:
        label = f"{node['id']}\n{node['file'].split('/')[0]}"
        rows.append(
            f'{ids[node["id"]]} [label={json.dumps(label)}, tooltip={json.dumps(node["file"])}, id="{ids[node["id"]]}"];'
        )
    rows.extend(f"{ids[a]} -> {ids[b]};" for a, b in composition["edges"])
    return "\n".join([*rows, "}"])


def dot_source(item: Context, modules: list[Module]) -> str:
    ids = {module["path"]: f"n{index}" for index, module in enumerate(modules)}
    lines = [
        "digraph modules {",
        'graph [rankdir=LR, bgcolor="transparent", nodesep=0.18, ranksep=0.5];',
        'node [shape=box, style="rounded,filled", fontname="sans-serif", fontsize=11, fillcolor="#e7eff8", color="#698198"];',
        'edge [color="#9aaebf", arrowsize=0.5];',
        f'root [label={json.dumps(item["label"])}, fillcolor="#163f52", fontcolor=white];',
    ]
    for path in item["modules"]:
        label = (
            path.removeprefix("modules/")
            .removesuffix("/default.nix")
            .removesuffix(".nix")
        )
        lines.append(
            f'{ids[path]} [label={json.dumps(label)}, tooltip={json.dumps(path)}, id="{ids[path]}"];'
        )
    lines.extend(f"{ids[parent]} -> {ids[child]};" for parent, child in item["edges"])
    lines.extend(f"root -> {ids[path]};" for path in item["roots"])
    return "\n".join([*lines, "}"])


def markdown(report: Report) -> str:
    modules, contexts = report["modules"], report["contexts"]
    rows = [
        "<!-- dprint-ignore-file -->",
        "<!-- markdownlint-disable MD013 MD060 -->",
        "",
        "# Module map",
        "",
        "Generated by `just module-map`. Do not edit this file by hand.",
        "",
        "Open [the interactive diagram](../reports/module-map/index.html) after generating it locally.",
        "CI attaches the same offline HTML as the `module-map` artifact.",
        "",
        "## Reading this map",
        "",
        "This map combines actual Den aspect membership with evaluated Nix imports, including embedded Home Manager graphs.",
        "Composition edges are authored includes filtered to selected aspects; they are not the resolved policy delivery graph.",
        "The module graphs record imports, not whether each option, package or service is enabled.",
        "Flake wiring registers configurations and public modules; it is not a deployed machine.",
        "The Den catalogue records actual registered aspect sources, including definitions not selected by a machine.",
        "Optional workstation variants show supported compositions, not additional machines.",
        "External work repositories and arbitrary extra modules are outside this evaluation.",
        "",
        "Run `just module-map-check` to detect stale diagrams and changed usage.",
        "A failed evaluation stops generation; partial results never replace the snapshot.",
        "",
        "## Machines and profiles",
        "",
        "| Context | Kind | Imported local files |",
        "| --- | --- | ---: |",
    ]
    rows.extend(
        f"| {c['label']} | {c['kind']} | {len(c['modules'])} |" for c in contexts
    )
    rows += [
        "",
        "## Software overlap",
        "",
        "The HTML software tab shows all six physical machines as overlapping circles, with clickable counts for every occupied host combination and zero labels for additional empty combinations.",
        "Circle areas are schematic, not proportional to package counts. A combination may have disconnected parts; its count is shown once. See [the circle-layout validation](software-overlap-circles.md).",
        "A separate three-machine Venn view supports arbitrary machine comparisons. Both views have searchable package names, versions and installation sources.",
        "Membership uses package names, so different versions can overlap. Counts deduplicate system and home installations of the same name.",
        "This inventory evaluates system packages, Home Manager packages and Homebrew brews and casks. It does not scan running machines.",
        "Dependencies, service-only packages, manual installations and external work profiles are excluded. Diagram areas are schematic.",
        "",
        "| Machine | Unique configured package names |",
        "| --- | ---: |",
    ]
    rows.extend(
        f"| {m['name']} | {len({p['name'] for p in m['packages']})} |"
        for m in report["software"]
    )
    rows += [
        "",
        "## Entry points",
        "",
        "Only direct local roots appear here. The HTML contains every local import edge.",
        "",
        "```mermaid",
        "flowchart LR",
    ]
    ids = {module["path"]: f"m{index}" for index, module in enumerate(modules)}
    for index, item in enumerate(contexts):
        rows.append(f'  c{index}["{item["label"]}"]')
        for path in item["roots"]:
            rows.append(f'  c{index} --> {ids[path]}["{path}"]')
    rows += [
        "```",
        "",
        "## Files outside the evaluated graphs",
        "",
        "These are investigation candidates, not proven dead code. Ordinary Nix imports used as",
        "helpers or consumers outside this repository can be absent from a module graph.",
        "",
    ]
    unseen = [module for module in modules if module["status"] == "unobserved"]
    rows.extend(f"- [{m['path']}](../{m['path']})" for m in unseen)
    if not unseen:
        rows.append("None.")
    rows += [
        "",
        "## Possible absorption",
        "",
        "Heuristic: at most 60 source lines, exactly one observed local importer and the same",
        "evaluated consumers as that importer. Review public exports and option boundaries",
        "before merging. These checks do not establish semantic redundancy.",
        "",
        "| Module | Lines | Only observed importer |",
        "| --- | ---: | --- |",
    ]
    rows.extend(
        f"| [{m['path']}](../{m['path']}) | {m['lines']} | {m['merge_into']} |"
        for m in modules
        if m["merge_into"]
    )
    rows += [
        "",
        "## Machine-module matrix",
        "",
        "S = system import; H = Home Manager import; I = flake wiring import; A = selected Den aspect owner.",
        "",
        "| Module | " + " | ".join(c["label"] for c in contexts) + " |",
        "| --- | " + " | ".join("---" for _ in contexts) + " |",
    ]
    for module in modules:
        cells = []
        for item in contexts:
            symbols = {
                "A"
                if layer == "aspects"
                else "S"
                if layer == "system"
                else "I"
                if layer == "flake"
                else "H"
                for layer, members in item["layers"].items()
                if module["path"] in members
            }
            cells.append("/".join(sorted(symbols)) or "·")
        rows.append(
            f"| [{module['path']}](../{module['path']}) | " + " | ".join(cells) + " |"
        )
    return "\n".join(rows) + "\n"


# shortcut: validated six-host layout; revise it when new hosts or unsupported combinations appear.
CIRCLES = [
    ("bragi", -0.70, 0.30, 0.80),
    ("donar", 0.15, 0.00, 1.00),
    ("frigg", -0.26, 0.20, 0.95),
    ("loki", 0.35, -0.65, 0.80),
    ("mimir2", 0.08, 0.10, 0.35),
    ("wodan", 0.00, -0.15, 1.05),
]
LABELS = {
    1: (-1.3189, 0.4986),
    2: (0.7788, 0.6702),
    4: (-0.1940, 1.0462),
    5: (-0.9508, 0.5916),
    6: (0.2295, 0.9364),
    7: (-0.2210, 0.9019),
    8: (0.6621, -1.1862),
    10: (1.0590, -0.3465),
    32: (-0.5701, -0.8714),
    33: (-0.9974, -0.4238),
    34: (0.7999, 0.3284),
    36: (-0.7469, -0.5526),
    37: (-0.8799, 0.2846),
    38: (0.3435, 0.6056),
    39: (-0.4583, 0.4056),
    40: (0.3639, -1.0539),
    42: (0.4887, -0.7009),
    46: (-0.0503, -0.4935),
    47: (-0.2183, -0.2229),
    54: (0.2264, 0.2687),
    55: (-0.0661, 0.2200),
    62: (0.2082, -0.0321),
    63: (-0.1020, -0.0946),
}


def membership(point: tuple[float, float]) -> tuple[int, float]:
    distances = [r - math.hypot(point[0] - x, point[1] - y) for _, x, y, r in CIRCLES]
    return sum(1 << i for i, d in enumerate(distances) if d > 0), min(
        map(abs, distances)
    )


def arc_angles() -> list[list[float]]:
    angles: list[list[float]] = [[] for _ in CIRCLES]
    for i, (_, x, y, r) in enumerate(CIRCLES):
        for j in range(i):
            _, u, v, s = CIRCLES[j]
            distance = math.hypot(u - x, v - y)
            if abs(r - s) < distance < r + s:
                angle = math.atan2(v - y, u - x)
                offset = math.acos(
                    (r * r + distance * distance - s * s) / (2 * r * distance)
                )
                for theta in (angle - offset, angle + offset):
                    px, py = x + r * math.cos(theta), y + r * math.sin(theta)
                    angles[i].append(theta % math.tau)
                    angles[j].append(math.atan2(py - v, px - u) % math.tau)
    return angles


def geometric_memberships() -> set[int]:
    """Sample both faces adjacent to every circle arc between crossings."""
    found = set()
    for i, ((_, x, y, r), intersections) in enumerate(
        zip(CIRCLES, arc_angles(), strict=True)
    ):
        angles = sorted(intersections) or [0.0]
        for k, start in enumerate(angles):
            end = angles[k + 1] if k + 1 < len(angles) else angles[0] + math.tau
            theta = (start + end) / 2
            dx, dy = math.cos(theta), math.sin(theta)
            px, py = x + r * dx, y + r * dy
            clearance = min(
                abs(math.hypot(px - u, py - v) - s)
                for j, (_, u, v, s) in enumerate(CIRCLES)
                if j != i
            )
            epsilon = min(r / 10, clearance / 3)
            for sign in (-1, 1):
                mask, _ = membership(
                    (px + sign * epsilon * dx, py + sign * epsilon * dy)
                )
                found.add(mask)
    return found - {0}


def physical_circle_layout(report: Report) -> dict:
    """Validate every occupied software group before publishing its circle layout."""
    machines = {m["name"]: m for m in report["software"] if m["kind"] == "physical"}
    if set(machines) != {c[0] for c in CIRCLES}:
        raise ValueError("Review the software circle layout for changed physical hosts")
    sets = [{p["name"] for p in machines[name]["packages"]} for name, *_rest in CIRCLES]
    groups: dict[int, list[str]] = {}
    for package in set.union(*sets):
        mask = sum(1 << i for i, names in enumerate(sets) if package in names)
        groups.setdefault(mask, []).append(package)
    represented = geometric_memberships()
    if represented != LABELS.keys():
        raise ValueError("Label each circle combination, including empty combinations")
    missing = groups.keys() - represented
    if missing:
        raise ValueError(
            f"Update the circle layout: occupied combinations {sorted(missing)} have no region"
        )
    clearances = {}
    for mask, point in LABELS.items():
        actual, clearance = membership(point)
        if actual != mask or clearance <= 1e-6:
            raise ValueError(f"Invalid interior circle label for {mask}")
        clearances[mask] = clearance
    return {
        "sets": CIRCLES,
        "regions": [{"mask": mask, "x": x, "y": -y} for mask, (x, y) in LABELS.items()],
        "groups": {mask: sorted(names) for mask, names in groups.items()},
        "counts": {mask: len(groups.get(mask, [])) for mask in LABELS},
        "extra_empty_masks": sorted(represented - groups.keys()),
        "minimum_occupied_clearance": min(
            (clearances[m] for m in groups), default=None
        ),
    }


def render_html(report: Report, root: Path) -> str:
    diagrams = {}
    for item in report["contexts"]:
        svg = run(
            ["dot", "-Tsvg"], cwd=root, source=dot_source(item, report["modules"])
        )
        diagrams[item["id"]] = svg[svg.index("<svg") :]
        if item.get("composition", {}).get("nodes"):
            svg = run(["dot", "-Tsvg"], cwd=root, source=composition_dot(item))
            diagrams[item["id"] + ":composition"] = svg[svg.index("<svg") :]
    template = (root / "scripts/module-map.html").read_text()
    data = json.dumps(
        {
            "report": report,
            "diagrams": diagrams,
            "vennSix": physical_circle_layout(report),
        },
        separators=(",", ":"),
    ).replace("<", "\\u003c")
    return template.replace('"__MODULE_MAP_DATA__"', data)


def compare(previous: Report, current: Report) -> list[str]:
    before = {module["path"]: module for module in previous["modules"]}
    after = {module["path"]: module for module in current["modules"]}
    messages = []
    for path in sorted(before.keys() | after.keys()):
        if path not in before:
            messages.append(f"Added {path}: {after[path]['status']}")
        elif path not in after:
            messages.append(f"Removed {path}")
        elif before[path] != after[path]:
            messages.append(f"Changed {path}: {after[path]['status']}")
    return messages


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("generate", "check"))
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Evaluate and render without writing files",
    )
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    raw: Graphs = json.loads(
        run(
            [
                "nix",
                "eval",
                "--impure",
                "--json",
                "--file",
                str(root / "scripts/module-graph.nix"),
                "--apply",
                "f: f {}",
            ],
            cwd=root,
        )
    )
    report = analyze(raw, root)
    physical_circle_layout(report)
    snapshot = root / "docs/module-map.json"
    serialized = json.dumps(report, indent=2, sort_keys=True) + "\n"
    document = markdown(report)
    if args.command == "check":
        if (
            not snapshot.exists()
            or snapshot.read_text() != serialized
            or (root / "docs/module-map.md").read_text() != document
        ):
            if snapshot.exists():
                previous: Report = json.loads(snapshot.read_text())
                for message in compare(previous, report):
                    print(message, file=sys.stderr)
            print("Module map is stale. Run: just module-map", file=sys.stderr)
            return 1
        print("Module map is current.")
        return 0
    rendered = render_html(report, root)
    outputs = {
        snapshot: serialized,
        root / "docs/module-map.md": document,
        root / "reports/module-map/index.html": rendered,
    }
    for path, content in outputs.items():
        if not args.dry_run:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        print(f"{'Would write' if args.dry_run else 'Wrote'} {path.relative_to(root)}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, sp.TimeoutExpired) as error:
        print(f"module-map: {error}", file=sys.stderr)
        sys.exit(1)
