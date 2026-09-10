"""Validate local agent sources against evaluated Home Manager skill links."""

import json
import os
import re
import unittest
from pathlib import Path

import yaml


def shared_target(source, target):
    """Map installed shared paths to their canonical repository sources."""
    suffix = target.removeprefix("~/.agents/")
    if suffix.startswith("instructions/"):
        return source / suffix
    if suffix.startswith("skills/"):
        return source / ".agents" / suffix.removeprefix("skills/")
    return source / ".agents" / suffix


def references(document, source):
    """Find concrete shared file pointers and relative Markdown links."""
    text = document.read_text()
    for target in re.findall(r"~/.agents/[\w./-]+\.(?:md|json|py|sh)\b", text):
        yield shared_target(source, target)
    for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
        if "://" not in target and not target.startswith(("#", "~", "/")):
            yield document.parent / target.split("#", 1)[0]


class AgentInstructions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = Path(os.environ["AGENT_SOURCE"])
        cls.catalog = json.loads((cls.source / "skills.json").read_text())
        cls.names = cls.catalog["local"] + cls.catalog["workflow"]
        cls.links = json.loads(Path(os.environ["AGENT_LINKS"]).read_text())

    def test_catalog_names_are_unique(self):
        self.assertEqual(len(self.names), len(set(self.names)))

    def test_managed_skill_frontmatter(self):
        for name in self.names:
            with self.subTest(skill=name):
                path = self.source / ".agents" / name / "SKILL.md"
                text = path.read_text()
                match = re.match(r"\A---\n(.*?)\n---(?:\n|$)", text, re.DOTALL)
                self.assertIsNotNone(match, f"Missing YAML frontmatter: {path}")
                metadata = yaml.safe_load(match[1])
                self.assertIsInstance(metadata, dict)
                self.assertEqual(metadata.get("name"), name)
                self.assertRegex(name, r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
                self.assertLessEqual(len(name), 64)
                description = metadata.get("description")
                self.assertIsInstance(description, str)
                self.assertTrue(description.strip())

    def test_home_manager_links(self):
        for client in ["codex", "copilot", "config/opencode", "agents"]:
            names = self.catalog["workflow"] if client == "agents" else self.names
            for name in names:
                with self.subTest(client=client, skill=name):
                    link = Path(self.links[f".{client}/skills/{name}"])
                    self.assertTrue(link.is_symlink(), f"Not a symlink: {link}")
                    self.assertTrue(
                        os.readlink(link).endswith(f"/dotfiles/agents/.agents/{name}"),
                        f"Wrong target: {link} -> {os.readlink(link)}",
                    )

    def test_instruction_and_workflow_references(self):
        documents = list((self.source / "instructions").glob("*.md"))
        for name in self.catalog["workflow"]:
            documents.extend((self.source / ".agents" / name).rglob("*.md"))
        for document in documents:
            for target in references(document, self.source):
                with self.subTest(document=document, target=target):
                    self.assertTrue(target.is_file(), f"Missing reference: {target}")


if __name__ == "__main__":
    unittest.main()
