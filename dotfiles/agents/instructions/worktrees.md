# Git-worktrees

Gebruik de huidige checkout als werkplek, ook als die `trunk` heet. Voer daar
wijzigingen, builds, tests, formattering en geautoriseerde commits uit. Behoud
niet-gerelateerde en reeds bestaande wijzigingen van de gebruiker.

De map boven `trunk` is een container voor worktrees; wijzig daar geen
bronbestanden. Maak voor alleen-lezenvragen en gewone inspectie geen worktree.

Gebruik de skill `wt` via `~/.agents/skills/wt/SKILL.md` wanneer de gebruiker
een worktree vraagt of isolatie een concreet voordeel heeft. Een extra worktree
is niet vereist.

Merge niet naar en rebase niet op de branch van de gebruiker. Push niet,
verwijder geen branches of worktrees en prune geen worktrees, tenzij de
gebruiker daar expliciet om vraagt.
