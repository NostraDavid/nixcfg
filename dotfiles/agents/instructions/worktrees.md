# Git-worktrees

Repositories zijn ingedeeld met een aparte checkout voor de gebruiker genaamd
`trunk`, eventueel met daarnaast worktrees voor agents:

```text
<repo>/
├── trunk/                 # checkout van de gebruiker
├── codex-<taak>/          # worktree van een agent
└── codex-<andere-taak>/   # worktree van een andere agent
```

## Werk standaard in `trunk`

Gebruik de huidige checkout als werkplek. Als dat `trunk` is, voer de taak daar
dan standaard uit. Bestandswijzigingen, builds, tests, formattering, staging en
commits mogen in `trunk` worden uitgevoerd voor zover de taak daarom vraagt.
Behoud niet-gerelateerde en reeds bestaande wijzigingen van de gebruiker.

De map die `trunk` bevat is een container voor worktrees, niet een checkout
waarin bronbestanden mogen worden gewijzigd.

## Optionele sibling-worktree

Een agent mag zelfstandig een sibling-worktree maken wanneer isolatie een
concreet voordeel heeft, bijvoorbeeld bij parallel werk, een langdurige of
risicovolle wijziging, conflicterende lokale wijzigingen of wanneer de gebruiker
erom vraagt. Een nieuwe worktree is niet vereist en heeft niet de voorkeur voor
regulier werk dat veilig in `trunk` kan worden uitgevoerd.

Als een sibling-worktree wordt gebruikt:

1. Gebruik de huidige worktree als die al bij dezelfde taak hoort.
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

Maak voor alleen-lezenvragen en gewone inspectie geen worktree aan.

## Overdracht en opruimen

Als een agent-worktree is gebruikt, houd dan alle taakwijzigingen beperkt tot de
bijbehorende branch en worktree. Meld bij de overdracht aan de gebruiker de
bijbehorende paden en branchnaam.

Merge niet naar en rebase niet op de branch van de gebruiker. Push niet,
verwijder geen branches of worktrees en prune geen worktrees, tenzij de
gebruiker daar expliciet om vraagt. Behoud overal niet-gerelateerde en reeds
bestaande wijzigingen.
