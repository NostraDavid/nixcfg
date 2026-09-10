"""Validate local agent sources against evaluated Home Manager skill links."""

import json
import os
import re
import runpy
import unittest
from pathlib import Path

import yaml
import tiktoken


def shared_target(source, target):
    """Map installed shared paths to their canonical repository sources."""
    suffix = target.removeprefix("~/.agents/")
    if suffix.startswith("instructions/"):
        return source / suffix
    if suffix.startswith("skills/"):
        alias, rest = suffix.removeprefix("skills/").split("/", 1)
        catalog = json.loads((source / "skills.json").read_text())
        names = {short: name for name, short in catalog["aliases"].items()}
        return source / ".agents" / names[alias] / rest
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
        cls.descriptions = json.loads((cls.source / "descriptions.json").read_text())
        cls.encoding = tiktoken.encoding_for_model(cls.descriptions["model"])

    def test_trigger_contract_clauses(self):
        cases = json.loads(Path(os.environ["TRIGGER_CASES"]).read_text())
        for name, case in cases["skills"].items():
            with self.subTest(skill=name):
                text = self.descriptions["descriptions"][name]
                for pattern in case["required_patterns"]:
                    self.assertRegex(text, pattern)

    def test_description_token_budget(self):
        for name, text in self.descriptions["descriptions"].items():
            with self.subTest(skill=name):
                self.assertTrue(text.strip())
                self.assertLess(
                    len(self.encoding.encode(text)), self.descriptions["max_tokens"]
                )

    def test_description_rewrite_preserves_metadata_and_body(self):
        rewrite = runpy.run_path(os.environ["DESCRIPTION_REWRITER"])["rewrite"]
        for value in ['"Original description"', ">\n  Original\n  description"]:
            with self.subTest(value=value):
                text = (
                    f"---\nname: sample\ndescription: {value}\n"
                    "metadata:\n  short-description: Keep this\n"
                    "disable-model-invocation: true\n---\n\n# Original body\n"
                )
                updated = rewrite(text, {"sample": "Short description."})
                self.assertEqual(
                    yaml.safe_load(updated.split("---", 2)[1]),
                    {
                        **yaml.safe_load(text.split("---", 2)[1]),
                        "description": "Short description.",
                    },
                )
                self.assertEqual(updated.split("---", 2)[2], text.split("---", 2)[2])
                self.assertEqual(
                    rewrite(updated, {"sample": "Short description."}), updated
                )
                self.assertEqual(rewrite(text, {}), text)

    def test_installed_descriptions_match_catalog(self):
        for name, alias in self.catalog["aliases"].items():
            with self.subTest(skill=name):
                root = (
                    self.source / ".agents" / name
                    if name in self.names
                    else Path(self.links[f".codex/skills/{alias}"])
                )
                for path in root.rglob("SKILL.md"):
                    metadata = yaml.safe_load(path.read_text().split("---", 2)[1])
                    self.assertEqual(
                        metadata["description"],
                        self.descriptions["descriptions"][metadata["name"]],
                    )

    def test_catalog_names_are_unique(self):
        self.assertEqual(len(self.names), len(set(self.names)))

    def test_aliases_are_short_unique_and_installed(self):
        aliases = self.catalog["aliases"]
        self.assertEqual(len(aliases), len(set(aliases.values())))
        for name, alias in aliases.items():
            with self.subTest(skill=name, alias=alias):
                self.assertRegex(alias, r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
                self.assertLessEqual(len(alias), len(name))
                target = Path(self.links[f".codex/skills/{alias}"])
                for client in ["copilot", "config/opencode"]:
                    self.assertEqual(
                        self.links[f".{client}/skills/{alias}"], str(target)
                    )
                # Local out-of-store sources are checked separately below.
                if name not in self.names:
                    self.assertTrue((target / "SKILL.md").is_file())
                    metadata = yaml.safe_load(
                        (target / "SKILL.md").read_text().split("---", 2)[1]
                    )
                    self.assertEqual(metadata["name"], alias)

    def test_managed_skill_frontmatter(self):
        for name in self.names:
            with self.subTest(skill=name):
                path = self.source / ".agents" / name / "SKILL.md"
                text = path.read_text()
                match = re.match(r"\A---\n(.*?)\n---(?:\n|$)", text, re.DOTALL)
                self.assertIsNotNone(match, f"Missing YAML frontmatter: {path}")
                metadata = yaml.safe_load(match[1])
                self.assertIsInstance(metadata, dict)
                self.assertEqual(metadata.get("name"), self.catalog["aliases"][name])
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
                    alias = self.catalog["aliases"].get(name, name)
                    link = Path(self.links[f".{client}/skills/{alias}"])
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
