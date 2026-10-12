# Wodan security reports and advisory VEX

The security workflow compares unfiltered vulnerability findings with a
configuration-aware OpenVEX feed. The upstream feed is advisory. It cannot make
a failing raw scan pass.

## Generate a report

Run on a machine with Nix, Git, Bash, jq, sbomnix, Grype, OSV-Scanner, and
vulnix:

```bash
just security-vex wodan
just security-report wodan
```

`security-vex` builds the feed and exports its conditions without building the
system. `security-report` realizes the configured Wodan system, generates a full
runtime SBOM, and runs the scanners. Realizing a changed system may require
downloads and source builds. Neither command activates the system. The first
vulnix run downloads NVD data and can take several minutes.

Both commands print a fresh directory under `reports/security/wodan/run.*`. An
optional second argument changes the output parent directory:

```bash
just security-report wodan /tmp/security-reports
```

The pilot is enabled only for Wodan. Another host must explicitly import the
upstream module before these commands can generate its feed. Existing individual
`security-sbom`, `security-grype`, `security-osv`, and `security-vulnix`
commands remain available.

## Read the artifacts

| Artifact                                      | Purpose                                                                                                              |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `manifest.json`                               | Host, immutable source snapshot, realized system, upstream revision, scanner versions, exit statuses, and timestamps |
| `snapshot.json`                               | Nix archive paths for the source and its inputs                                                                      |
| `vex.openvex.json`                            | Generated upstream feed with its original author attribution                                                         |
| `vex.conditions.json`, `vex.dropped.json`     | Condition results and the statements omitted when their conditions failed                                            |
| `sbom.csv`, `sbom.cdx.json`, `sbom.spdx.json` | Runtime package inventory in CSV, CycloneDX, and SPDX formats                                                        |
| `grype.raw.json`                              | Grype findings without VEX, using the existing critical severity gate                                                |
| `grype.advisory.json`                         | The same SBOM scanned with the advisory VEX feed                                                                     |
| `grype-db.json`, `grype-db-after.json`        | Database identity before and after the paired scans                                                                  |
| `osv.json`, `vulnix.json`                     | Independent scanner results, without upstream VEX filtering                                                          |
| `*.stderr.log`, `*.validation.log`            | Tool diagnostics and artifact validation results                                                                     |

The command archives one source snapshot with its existing lock file and uses
that snapshot for both system and VEX evaluation. sbomnix scans the immutable
flake reference, preserving package metadata and the full runtime closure. It
does not use `--buildtime` or a dependency-depth limit. See the
[sbomnix documentation](https://github.com/tiiuae/sbomnix#buildtime-vs-runtime-dependencies).

Grype uses one temporary database per report. The command updates it once,
disables automatic updates, and verifies that its metadata remains unchanged
between scans. It clears inherited Grype settings and uses an empty controlled
configuration so local ignore rules or VEX files cannot contaminate the raw
scan. The temporary database is removed at exit; its metadata remains in the
report.

Grype retains suppressed findings in `ignoredMatches`, including the applied
ignore rules. An absent `ignoredMatches` field means there were no suppressions.
See
[Grype filtering](https://oss.anchore.com/docs/guides/vulnerability/filter-results/).

## Interpret failures

The weekly and manually triggered CI security job runs `security-report` and
uploads the reports even when the job fails. The blocking policy remains:

- Raw Grype findings at `critical` or above fail the job.
- OSV's nonzero finding status fails the job.
- Vulnix's nonzero finding status fails the job.
- Scanner errors, malformed artifacts, and a changed Grype database fail the
  job.

The command continues to the other scanners after findings or scanner failures
when their inputs are available. A failure to create the snapshot, feed, system,
or valid SBOM stops dependent work. Partial artifacts and the final exit status
remain in the run directory. Always inspect stderr alongside exit codes: vulnix
uses exit code 2 for both findings and some operational errors.

The advisory Grype scan has no vulnerability severity gate. A successful
advisory scan cannot override any raw failure. Failed VEX conditions omit
statements; they do not require you to change the host configuration.

## Review suppressions

For a finding in `ignoredMatches`, identify the matching upstream statement and
read its supporting sources. Verify the package, version, source, patches, build
options, and relevant host configuration. Record whether the justification holds
for the exact system path in the report. A package name and version alone do not
establish that a custom package includes an upstream patch.

The pinned [nixos-vex project](https://github.com/datosh/nixos-vex) targets an
x86_64 `nixos-unstable` baseline. This repository uses NixOS 26.05 and custom
overlays. The pilot evaluates successfully, but that does not establish the
correctness of every retained statement for this repository.

The feed covers only its baseline packages. Its conditions inspect declarative
configuration, not imperative changes to the running machine. A runtime Nix SBOM
also does not guarantee complete inventories of dependencies bundled inside
prebuilt applications. Neither an empty report nor a suppression proves the
absence of exploitable vulnerabilities.

Do not disable desktop mounting, change authentication, replace kernels, or
change filesystems merely to satisfy the feed. Promotion of reviewed
suppressions into blocking-scan policy is a separate change requiring explicit
review.

## Update the upstream input

The source-only input is pinned explicitly to commit
`6c6bbba6d30cf474dcf102d555ed8f8957b14c39`. Changing the revision in `flake.nix`
requires a reviewed change. Inspect upstream module and feed changes against
NixOS 26.05, update only the `nixos-vex` lock entry, and run:

```bash
nix flake update nixos-vex
python3 checks/test-security-report.py
nix eval --impure --json --file checks/vex.nix
just security-vex wodan
just security-report wodan
```

The conditional regression uses a synthetic feed and toggles removable-media
support in an evaluated test configuration. It does not change the running host.
It verifies that a statement is retained only while its condition holds.

This workflow follows
[The Unreasonable Effectiveness of VEX in NixOS](https://blog.kammel.dev/post/nixos_vex/).
