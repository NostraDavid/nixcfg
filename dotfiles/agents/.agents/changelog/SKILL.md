---
name: changelog
description: Create or update human-readable project changelogs for notable user-facing changes. Use for CHANGELOG.md authoring or review; exclude commit-log dumps, pull-request descriptions, and release automation.
---

# Changelog

Write a concise, curated record for people who use or contribute to the project.
Follow [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). Read
[`templates/CHANGELOG.md`](templates/CHANGELOG.md) when creating a changelog.

## Workflow

1. Inspect the existing changelog and the requested change or release scope.
   Preserve useful project conventions and existing history.
2. Select notable changes supported by the diff, release evidence, or user-provided
   facts. Combine implementation details into clear outcomes and user impact;
   omit routine work and raw commit-title lists. When naming a package, use its
   exact verified package name in backticks (e.g. `example-http-client`), not a
   humanized substitute. Check the package manifest or other authoritative source;
   do not guess the name.
3. Keep `[Unreleased]` first. Group entries under populated categories only:
   `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, and `Security`. Omit
   empty category headings. Make upgrade impact, deprecations, and removals clear.
4. Put released versions below `Unreleased`, newest first. Use
   `## [version] - YYYY-MM-DD`; verify both the version and date. Leave changes
   under `Unreleased` or request confirmed release metadata when either is
   unknown.
5. Verify that entries are factual and concise, release dates use ISO 8601, and
   sections are ordered correctly.

Do not invent versions or dates. State that the project follows Semantic
Versioning only when its versioning policy confirms this.
