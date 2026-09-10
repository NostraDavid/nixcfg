# CLI output policy

For shell commands, use RTK when its wrapper supports the operation and
preserves required output; otherwise use Snip, then the direct command if
necessary. Keep errors and essential output visible, use only one proxy per
command, and briefly explain bypassing both. MCP calls are outside this policy.

For wrapper usage or full failure output, follow
`~/.agents/skills/cli-output/SKILL.md`.
