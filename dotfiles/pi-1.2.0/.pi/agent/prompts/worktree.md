---
description: Create or reuse a Git worktree for an isolated task.
argument-hint: "[branch or task]"
---

Prepare a worktree for this task: $ARGUMENTS

Read repository instructions and inspect `git status --short` and
`git worktree list --porcelain`. Follow the installed wt or worktrunk skill when
available, otherwise use `git worktree`. Reuse a suitable existing worktree or
create a new branch and sibling worktree. Preserve existing changes and never
force, reset, remove, prune, merge, or push as part of this command.

Report the absolute worktree path and branch. To delegate the requested task,
pass that path as the subagent's `cwd`, including on each parallel task. Give
concurrent writers separate worktrees. Only delegate when the user requests it.
For interactive work, provide a shell-quoted `cd` command followed by `pi`.
Creating a worktree does not change this Pi session's working directory.
