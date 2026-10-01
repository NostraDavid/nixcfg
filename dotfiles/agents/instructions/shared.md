# Shared agent instructions

## Common rules

Read and follow every instruction file below.

| File                                           | Reason to read                                                                                       |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `~/.agents/instructions/batch-instructions.md` | Batch independent tool calls while keeping dependent operations sequential.                          |
| `~/.agents/instructions/qartez.md`             | Choose code navigation tools and their fallbacks.                                                    |
| `~/.agents/instructions/semble.md`             | Locate code by meaning when exact text searches are too broad.                                       |
| `~/.agents/instructions/memory.md`             | Retrieve prior project context and save durable decisions to the configured memory backend.          |
| `~/.agents/instructions/cli-proxy-policy.md`   | Choose CLI output wrappers while preserving errors and essential output.                             |
| `~/.agents/instructions/commit-style.md`       | Write commit messages with the required scope-first format.                                          |
| `~/.agents/instructions/worktrees.md`          | Choose the working checkout and preserve existing changes and branches.                              |
| `~/.agents/instructions/eu-ai-act.md`          | Identify AI uses that need a risk check, human oversight, or approval before sharing sensitive data. |

## Conditional skills

Read and follow each skill when its condition applies.

| When to read                                                                  | File                              | Reason to read                                                                             |
| ----------------------------------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------------------ |
| Before asking the user a question or handing over a completed task.           | `~/.agents/audio-notify/SKILL.md` | Play the required audio notification.                                                      |
| When external library documentation is needed.                                | `~/.agents/skills/c7/SKILL.md`    | Retrieve documentation for the relevant API and version.                                   |
| When large raw outputs need compression or compressed details need retrieval. | `~/.agents/skills/hr/SKILL.md`    | Compress output and recover original details before relying on them.                       |
| When tracking work in a repository configured for Beads.                      | `~/.agents/skills/beads/SKILL.md` | Track tasks, dependencies, ownership, and completion in the repository's existing tracker. |
