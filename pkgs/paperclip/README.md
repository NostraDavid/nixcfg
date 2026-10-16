# Start Paperclip

Run the CLI from the repository root:

```bash
nix run .#paperclip -- onboard --yes --no-install-service
```

Open the local dashboard URL printed by the server. Paperclip stores its
configuration and database in `~/.paperclip`. Stop the server with Ctrl+C.

To start from the Linux application menu, choose Paperclip. Keep its terminal
open while you use the dashboard.

To isolate another instance, add `--data-dir /path/to/paperclip-data`.

Update the pinned package with the repository's updater:

```bash
just pkg-update paperclip
```

Build the package and run its CLI and server checks:

```bash
nix build .#paperclip --no-link
```
