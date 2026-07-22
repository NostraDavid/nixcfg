# Codex system

- Bron: gebundelde system-skills uit Codex CLI `0.144.3`
- Bronlocatie: `~/.codex/skills/.system`
- Bronmarker: `2575ff8690bf93c7`
- Lokale importcommit: `8325a250`
- Selectie: `imagegen`, `openai-docs`, `plugin-creator`, `skill-creator` en
  `skill-installer`

Dit zijn snapshots, inclusief scripts, assets, referenties en skill-specifieke
licenties. Lokale bytecodecaches zijn uitgesloten. De enige integratiepatch
vervangt in `skill-creator` de verwijderde `$python-script-builder`-verwijzing
door de expliciete native- en uv-varianten. Bijwerken betekent de vijf volledige
upstream-mappen opnieuw kopiëren, deze patch opnieuw toepassen, de bronmarker
verversen en de clientprojecties en validaties opnieuw controleren.

Codex zelf blijft zijn ingebouwde exemplaren gebruiken. Alleen Copilot krijgt
deze snapshots via Home Manager, om dubbele Codex-discovery te voorkomen.
