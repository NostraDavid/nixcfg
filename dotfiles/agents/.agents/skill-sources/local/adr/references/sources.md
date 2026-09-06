# Sources and design rationale

Consulted 2026-09-06. The schema is a local convention based on the supplied
template, not an industry standard imposed by these sources.

- [Michael Nygard, Documenting Architecture Decisions (2011)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions):
  one significant decision per short record; capture context, status, rationale,
  and consequences. Keep replaced records and reference their successors.
- [Martin Fowler, Architecture Decision Record (2026)](https://martinfowler.com/bliki/ArchitectureDecisionRecord.html):
  write for future readers and for clearer present discussion. Put key material
  early and keep lightweight records near the code.
- [npryce/adr-tools](https://github.com/npryce/adr-tools):
  inspiration for sequential naming and explicit relationships. Its commands
  and file schema are not assumed compatible with this skill's domain IDs.
- Local `awesome-copilot/create-architectural-decision-record/SKILL.md`:
  consulted for machine-readable metadata and explicit alternatives; no files
  copied or changed. The user's supplied layout takes precedence.

Markdown is the source because it is readable, diffable, and renderable with
existing repository tooling. Independent HTML would duplicate the contract.
The extra relationship fields make collection checks possible. Relative driver
weights are ordinal High/Medium/Low, not invented numerical precision.
