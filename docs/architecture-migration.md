# Den migration validation

The migration replaces composition and source ownership while preserving the
deployment contract from commit `a831ba6`. No machine was activated during this
validation.

## Configuration comparison

Before editing, the original flake was captured as an immutable Nix source. The
before/after projection covered nine NixOS configurations, Loki, Mimir2, two
optional workstation profiles, and custom-user/extension factory variants.

The comparison preserved:

- Every existing public configuration and module export, including the two
  work-profile factories and their extension arguments.
- Exact Home Manager application package identities and package multiplicities.
- User names, homes, groups, state versions, filesystem assignments, and network
  and firewall settings.
- Native MCP definitions, memory backends, session settings, and activation
  dependencies.
- Server persistence and initialization safeguards.

Changed derivation paths were investigated separately from effective values.
Wodan's old/new nix-ld aggregates contained the same 160 entries and exact
symlink targets. Its old/new home profiles contained the same 16,727 entries
apart from generated font caches. Decoding those caches showed equivalent font
entries. The system profile differed only by the equivalent nix-ld target.
Certificate bundles were byte-identical.

The changed generated activation and unit texts differed only in their store
references. The same independent udev rule groups appeared in another order.
Donar and Frigg retained the same kernel arguments and multiplicities; repeated
`mem_sleep_default` values remained identical.

The moved skill-description helper also received type annotations and equivalent
Path operations required by the current Ruff rules. Existing helper regression
tests verify its output and idempotence.

## Executed checks

- Complete Wodan system build and every Linux home activation-package build.
- `checks.x86_64-linux.architecture` build and all architecture predicates.
- Nineteen real-evaluator positive/negative policy tests, including forbidden
  dependencies, private imports, missing capabilities, cycles, platform errors,
  and inline Den option provenance.
- Existing MCP, agent instructions, OpenCode, keyboard, bootstrap, and external
  work-flake consumer checks.
- All tooling package-source assertions and flake evaluation checks.
- Module-map analysis, freshness, and browser checks for composition/native
  diagrams, matrix navigation, and synchronized scroll zoom.

The architecture documentation describes ongoing commands. These migration
comparisons establish the original behavior baseline; they do not replace the
ongoing policy tests.

## Existing style failures

Repository-wide `just check` fails because Dprint proposes changes in existing
files, including Python indentation that conflicts with Ruff formatting. The
failing `checks/test-freeipa-policy.py` is byte-identical to the original
snapshot.

Repository-wide `just lint` reports 527 Ruff violations outside the completed
scoped checks. Running the same Ruff rules against the immutable original
snapshot reports 534 violations. The difference is the seven violations fixed in
the moved skill-description helper. No formatter or lint rule was disabled to
make this migration pass.

## Unverified boundaries

macOS configurations and custom-user contracts were evaluated on Linux; native
macOS applications and activation were not executed. Image derivations were
evaluated; QEMU boot tests were not repeated because the stateful runtime
scripts and effective storage settings were preserved. Remote work checkouts
were not activated. Branch protection was not changed.
