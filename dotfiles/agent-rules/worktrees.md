# Git-worktrees

Repositories zijn ingedeeld met een aparte checkout voor de gebruiker genaamd
`trunk`, met daarnaast worktrees voor agents:

```text
<repo>/
├── trunk/                 # checkout van de gebruiker
├── codex-<taak>/          # worktree van een agent
└── codex-<andere-taak>/   # worktree van een andere agent
```

## Bescherm `trunk`

Behandel `trunk` als de persoonlijke werkcheckout van de gebruiker. Wijzig er
geen bestanden en voer er geen staging, branchwissels, commits, rebases, merges,
pulls of opschoonacties uit. Alleen-lezeninspectie is toegestaan.

De map die `trunk` bevat is een container voor worktrees, niet een checkout
waarin bronbestanden mogen worden gewijzigd.

## Werk in een sibling-worktree

Voor een taak waarvoor wijzigingen aan de repository nodig zijn:

1. Gebruik de huidige worktree als die al een aparte sibling-worktree is.
2. Maak anders een sibling-worktree genaamd `codex-<korte-taaknaam>` met een
   nieuwe branch genaamd `codex/<korte-taaknaam>`.
3. Baseer de nieuwe branch op de gecommitte `HEAD` van `trunk`. Wijzig `trunk`
   nooit om de basis voor te bereiden. Niet-gecommitte wijzigingen in `trunk`
   zijn van de gebruiker en worden bewust niet overgenomen.
4. Voer alle wijzigende commando's, builds, tests, formattering, staging en
   commits uit vanuit de worktree van de agent.
5. Als de gewenste map- of branchnaam al bestaat, inspecteer die dan. Gebruik
   hem alleen opnieuw als hij duidelijk bij dezelfde taak hoort; kies anders een
   unieke suffix.

Voor alleen-lezenvragen en inspectie van de repository hoeft geen worktree te
worden aangemaakt.

## Overdracht en opruimen

Houd alle taakwijzigingen beperkt tot de branch en worktree van de agent. Meld
bij de overdracht aan de gebruiker de bijbehorende paden en branchnaam.

Merge niet naar en rebase niet op de branch van de gebruiker. Push niet,
verwijder geen branches of worktrees en prune geen worktrees, tenzij de
gebruiker daar expliciet om vraagt. Behoud overal niet-gerelateerde en reeds
bestaande wijzigingen.
