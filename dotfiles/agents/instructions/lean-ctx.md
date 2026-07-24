# LeanCTX

Use LeanCTX as the primary local context and shell-output layer.

```bash
lean-ctx -c "git status"
lean-ctx -c "cargo build --release"
lean-ctx read src/lib/auth.ts -m map
lean-ctx grep "authenticate" src/
```

Prefer:

- `read -m map` for a structural first read;
- normal `read` when implementation detail is required;
- cached re-reads instead of reopening the same file through another tool;
- `grep` for exact textual matches; and
- `-c` for commands whose output benefits from compression.

Use `lean-ctx raw "<command>"` when exact uncompressed command output is
required. Fall back to RTK and then Snip according to `cli-proxy-policy.md`
when LeanCTX is unavailable, unsuitable for the command's quoting, or loses
required diagnostic output.

Do not run `setup`, `wrap`, `onboard`, or other configuration-writing commands
unless the user explicitly asks to change agent or shell configuration.
