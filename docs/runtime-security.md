# Tijdelijke runtimevervanging van Brotli

Op Linux blijft de gedeelde Brotli-build in de pakketsets ongewijzigd. Daardoor
blijven afhankelijke pakketten geschikt voor de officiële binary cache. De
configuratie bouwt daarnaast `brotliPatched` met de beveiligingspatch.

Vóór installatie vervangt Nix de verwijzingen naar de oude Brotli-uitgangen in
de volledige runtime van het NixOS-systeem of de standalone Home
Manager-activatie. Dit omvat de gebruikersprofielen, gegenereerde launchers en
symlinks in `~/.local/bin`. Stable en unstable krijgen ieder hun eigen
vervangingsparen voor `out`, `dev` en `lib`. De tools in de development shell
krijgen dezelfde behandeling.

Dit gebruikt de bestaande `replaceDependencies` van nixpkgs. NixOS gebruikt zijn
geconfigureerde Nix als hulpmiddel; standalone Home Manager en de checks
gebruiken een ongewijzigde Nix uit dezelfde gepinde bron. De naam, versie en
directorystructuur van de gedeelde bibliotheek blijven gelijk. Iedere
uiteindelijke runtime controleert alle gevonden
`lib/libbrotlidec.so`-bibliotheken met de regressietest en weigert bekende oude
Brotli-paden. Een onbekende kopie die nog kwetsbaar is, laat de build mislukken.

De aparte fixes voor Node, Bun en de ingebakken DuckDB-decoder blijven staan.
Runtimevervanging repareert geen statisch ingebouwde decoder. Andere lokale
wijzigingen en backports kunnen nog steeds compilatie veroorzaken.

## Grenzen

- Deze vervanging geldt voor de beheerde Linux-systemen en profielen. Ze wijzigt
  geen bestaande projectomgevingen, containers of losse `nix run`/`nix shell`-
  pakketten buiten die profielen.
- De oorspronkelijke buildomgeving blijft ongewijzigd. De vervanging beschermt
  de uiteindelijke runtime, niet ieder programma tijdens het bouwen.
- `replaceDependencies` leest de gerealiseerde runtime via import from
  derivation. Daardoor kan zelfs evaluatie of een dry-run eerst ontbrekende
  oorspronkelijke pakketten bouwen of downloaden.
- De vervanging kopieert betrokken pakketten. Dit bespaart compilatie, maar kost
  extra schijfruimte en I/O.
- Op macOS blijft de gewone Brotli-overlay actief. Verwijzingen herschrijven kan
  Mach-O-handtekeningen ongeldig maken; dit wordt niet zonder native verificatie
  toegepast.
- Bestaande processen houden geladen bibliotheken vast. Activeer de nieuwe
  generatie en herstart de betrokken programma's.

Alle bestanden uit `dotfiles/` blijven direct naar de live checkout gesymlinked.
De vervanging kopieert of rendert deze bestanden niet.

## Controleren

```bash
just brotli-security-check
nix eval --impure --json --file checks/runtime-configuration.nix
```

De checks testen de gepatchte gedeelde bibliotheek, Bun en de DuckDB-bron. Een
extra test koppelt een echt programma aan de oude bibliotheek. Hetzelfde
programma moet de decoderregressie vóór de vervanging niet doorstaan en erna
wel. De test controleert ook beide pakketsets, alle uitgangen, de transitieve
runtime en het behoud van een externe symlink.

De tweede opdracht evalueert de oorspronkelijke systeemconfiguraties zonder
runtimevervanging en de overige pakketten en checks. CI gebruikt deze preflight
in plaats van `nix flake check --no-build`, omdat die laatste ook de
uiteindelijke systemen en images via import from derivation zou realiseren. De
native vervangingscheck en imagecheck worden afzonderlijk gebouwd. Deze
preflight bewijst niet dat een volledige nieuwe systeemgeneratie al gebouwd is.
Pakketten die hun gepinde broncode tijdens evaluatie lezen, kunnen die broncode
nog wel ophalen. Daarom kan import from derivation niet volledig worden
verboden.

Verwijder deze tijdelijke vervanging zodra de gepinde kanalen een veilige,
gecachete Brotli-build bevatten. Voer daarvoor opnieuw de decoderchecks uit.
