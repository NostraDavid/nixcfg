# Shared agent instructions

## Common rules

Read and follow every instruction file below.

### Tool calls and shell commands

`~/.agents/instructions/batch-instructions.md` to batch independent tool calls
while keeping dependent operations sequential.

`~/.agents/instructions/cli-proxy-policy.md` to choose CLI output wrappers while
preserving errors and essential output.

`~/.agents/instructions/shell-command-history.md` to run shell commands with
`login: false` and keep them out of shell history.

### Code navigation

`~/.agents/instructions/qartez.md` to choose code navigation tools and their
fallbacks.

`~/.agents/instructions/semble.md` to locate code by meaning when exact text
searches are too broad.

### Project memory

`~/.agents/instructions/memory.md` to retrieve prior project context and save
durable decisions to the configured memory backend.

### Application configuration

`~/.agents/instructions/application-configuration.md` to choose dotfiles for
application settings and Home Manager for links and integrations.

### Commits and working checkout

`~/.agents/instructions/commit-style.md` to write commit messages with the
required scope-first format.

`~/.agents/instructions/worktrees.md` to choose the working checkout and
preserve existing changes and branches.

### AI use

`~/.agents/instructions/eu-ai-act.md` to identify AI uses that need a risk
check, human oversight, or approval before sharing sensitive data.

## Conditional skills

Read and follow each skill when its condition applies.

### Audio notifications

Before asking the user a question or handing over a completed task, follow
`~/.agents/audio-notify/SKILL.md` to play the required audio notification.

### Library documentation

When external library documentation is needed, use
`~/.agents/skills/c7/SKILL.md` to retrieve documentation for the relevant API
and version.

### Large tool outputs

When large raw outputs need compression or compressed details need retrieval,
use `~/.agents/skills/hr/SKILL.md` to compress output and recover original
details before relying on them.

### Task tracking

When tracking work in a repository configured for Beads, use
`~/.agents/skills/beads/SKILL.md` to track tasks, dependencies, ownership, and
completion in the repository's existing tracker.
