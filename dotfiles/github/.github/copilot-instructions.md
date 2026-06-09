# Snip - CLI Token Optimizer

When executing shell commands, always prefix them with the snip proxy to reduce token usage.

## Usage

Instead of running commands directly:

```bash
git status
go test ./...
```

Prefix with snip:

```bash
/nix/store/lkrx10askyykllg57dqll37kx2k8nga6-snip-0.15.0/bin/snip -- git status
/nix/store/lkrx10askyykllg57dqll37kx2k8nga6-snip-0.15.0/bin/snip -- go test ./...
```

This applies to all shell commands. Snip filters verbose output while preserving errors and essential information.
