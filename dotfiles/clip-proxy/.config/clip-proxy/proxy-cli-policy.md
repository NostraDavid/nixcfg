# CLI proxy policy

Use CLI output proxies in this order:

1. Use the matching `rtk` subcommand when RTK has a dedicated filter.
2. If RTK has no matching filter, run the original command through `snip`.
3. If `snip` is unavailable or cannot invoke the command, run the original
   command directly.

Examples:

```bash
rtk git status
rtk pytest
snip <original command>
<original command>
```

Do not force an unrelated `rtk` subcommand onto a command. Preserve the
original command, arguments, and intent when falling back.

An underlying command returning a non-zero exit code is not a proxy failure.
Do not rerun it through the next proxy, because that could repeat side effects.
Only fall back after determining that the proxy itself is unavailable or cannot
invoke the command. Both proxies preserve the underlying command's exit code.
