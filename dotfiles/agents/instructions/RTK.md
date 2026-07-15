# RTK - CLI proxy

Use RTK's dedicated wrappers for supported commands, for example:

```bash
rtk git status
rtk pytest
rtk cargo test
rtk npm run build
```

Use `rtk gain` for savings statistics. RTK stores full failed-command output in
its tee directory when enabled; inspect the reported file instead of rerunning a
command solely to obtain verbose failure details.
