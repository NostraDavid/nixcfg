#!/usr/bin/env python3
"""Check package aliases in the category overlap."""

import importlib.util
import sys
from pathlib import Path

script = Path(__file__).resolve().parent.parent / "scripts/software-category-circles.py"
sys.path.insert(0, str(script.parent))
spec = importlib.util.spec_from_file_location("software_category_circles", script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

machines = [
    {"name": "wodan", "kind": "physical", "packages": [{"name": "coreutils-full"}]},
    {"name": "loki", "kind": "physical", "packages": [{"name": "coreutils"}]},
    {"name": "apps", "kind": "virtual", "packages": [{"name": "coreutils-full"}]},
]
page = module.render(machines)
assert '<tr id="group-7"><td>Home + Work + Virtual</td><td>1</td>' in page
assert page.count("<li>coreutils</li>") == 1
assert "<li>coreutils-full</li>" not in page
spec = importlib.util.spec_from_file_location(
    "six_circles", script.parent / "check-software-overlap-circles.py"
)
six = importlib.util.module_from_spec(spec)
spec.loader.exec_module(six)
page = six.render({24: ["example"]})
assert "1 occupied combinations cannot be shown" in page
assert 'id="group-24"' in page and "<li>example</li>" in page
print("Package aliases appear once in the combined category.")
