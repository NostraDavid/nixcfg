# Gedeelde agent-skills

Home Manager koppelt geselecteerde skills naar Codex, Copilot en OpenCode.

## Rechtstreekse imports

- matt-pocock-skills: selectie in pkgs/matt-pocock-skills/skills.nix.
- pstack-skills: selectie in pkgs/pstack-skills/skills.nix.
- awesome-copilot-skills: selectie in pkgs/awesome-copilot-skills/skills.nix.

Pocock is gepind op v1.2.3. flake.nix kiest de revisie; flake.lock legt de
inhoudshash vast. Dubbele skillnamen geven een evaluatiefout. Kies per naam één
bron.

## Lokale bronnen

Onder .agents/skill-sources staan codex-system, polars-inc, local. Onveranderde
baselines staan in .agents/skill-originals, met compare.sh.

Activeer wijzigingen met just switch.
