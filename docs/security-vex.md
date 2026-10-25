# Wodan security reports and advisory VEX

The security workflow compares unfiltered vulnerability findings with a
configuration-aware OpenVEX feed. The upstream feed is advisory. It cannot make
a failing raw scan pass.

## Generate a report

For an additional advisory check without building a system, run:

```bash
just security-check
just security-check --sbom /path/to/sbom.cdx.json
just security-check --sbom /path/to/sbom.cdx.json --package uv
```

The default scans the running NixOS generation at `/run/current-system`.
`--target` accepts another existing store output, including a user profile on
Linux or macOS. It rejects flake references and derivation files. sbomnix reads
that realized output; the command never invokes `nix build` or activates a
configuration. An existing CycloneDX SBOM needs only Python and network access.

The check queries the
[NixOS Security Tracker](https://tracker.security.nixos.org/) for accepted or
published package bindings and [EUVD](https://euvd.enisa.europa.eu/) for exact
product-name matches. It follows pagination, merges matching CVE IDs, and puts
known exploited EUVD records first. Product-name candidates are not proof that
the installed version is affected. Both sources' version constraints, tracker
branch context, local versions, and available SBOM derivation properties remain
in the JSON for review. A local backport needs evidence for that exact
derivation; the latest tracker branch status does not settle an older pinned
revision.

EUVD's EPSS value is retained as `epss_raw`, without converting its scale.

Each standalone run creates `reports/security-intel/run.*/intelligence.json`.
`--output FILE` chooses another report path. `--vex FILE` retains OpenVEX as
context without applying suppressions. These options work together:

```bash
just security-check --sbom sbom.cdx.json --vex vex.openvex.json --output intelligence.json
```

Responses are cached for 24 hours under
`${XDG_CACHE_HOME:-~/.cache}/nixcfg-security-intel`; `--refresh` fetches new
data. The report records each response URL, fetch timestamp, and cache use.
SBOMs stay local; requests contain package names. Python-package prefixes,
renamed Nix attributes, vendor bundles, and unknown product names can limit
matching.

Exit status 0 means all requested source queries completed, even when candidates
were found. Empty results are marked `unknown`, never safe. Exit status 2 means
an input, source, schema, or pagination error made the report `incomplete`.
Independent results survive a source failure. Missing exploitation data remains
unknown rather than being interpreted as no exploitation. The check does not
block `just switch`, change locks, or apply fixes.

An exploitation value of false means the record was not in the retrieved EUVD
known-exploited listing, not that exploitation is impossible. A full inventory
can require many API requests; `--package` limits a quick check to selected
components. A rate limit or network outage stops further requests to that source
for the current run and leaves its remaining queries unavailable.

The existing full report and scheduled security job also retain
`intelligence.json` next to the scanner outputs. They reuse the generated SBOM
and immutable source snapshot. Their existing build behavior and raw scanner
failure gates remain unchanged; an incomplete intelligence result fails the
report without deleting other artifacts.

Run the offline API/cache and report-orchestration regression tests with:

```bash
just security-intel-check
```

Run on a machine with Nix, Git, Bash, jq, sbomnix, Grype, OSV-Scanner, and
vulnix, plus Python for the advisory-source step:

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
| `intelligence.json`                           | EUVD and NixOS tracker candidates, response provenance, coverage limits, and unapplied VEX context                   |
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
