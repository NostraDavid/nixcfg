# Per-user plocate database

All interactive machine profiles use a private database at
`$XDG_CACHE_HOME/plocate/plocate.db`, normally `~/.cache/plocate/plocate.db`.
The database directory has mode 0700. Each user builds and searches their own
index without `sudo`.

```bash
updatedb
locate filename
plocate filename
```

The index scans the filesystem from `/` and includes paths the user can read. It
cannot index directories the user cannot access. On macOS, protected folders
remain subject to macOS privacy permissions.

Home Manager links the shared exclusions to `~/.config/plocate/updatedb.conf`.
Edit `dotfiles/plocate/.config/plocate/updatedb.conf` to change them. The native
configuration format controls exclusions; the command wrappers supply the
database location.

Linux uses a systemd user timer at 03:15, with a run five minutes after the user
manager starts and catch-up for missed daily runs. macOS uses a launchd user
agent at login and at 03:15 while logged in. The old system-wide indexing jobs
are no longer configured. Existing system databases are left on disk.

Apply the machine's NixOS, nix-darwin or Home Manager configuration to install
the commands and user job. Run `updatedb` after activation to build the first
index immediately. Remote machines also need their own activation.

Verify the commands and private database with:

```bash
bash checks/test-user-locate.sh
```
