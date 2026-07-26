# Mogelijke uitbreiding van dprint

Onderzocht op 26 juli 2026. De tellingen hieronder komen uit de door Git
gevolgde bestanden in deze repository.

## Conclusie

TOML, CSS, XML en Dockerfile zijn nu opgenomen in de centrale
dprint-configuratie. De bestaande TOML-, CSS- en XML-bestanden zijn
proefgeformatteerd en beoordeeld; er zijn momenteel geen gevolgde Dockerfiles.
Voor Python, Shell, Lua, Nix en Terraform blijven de bestaande gespecialiseerde
formatters de betere eigenaar.

De huidige afbakening:

1. dprint beheert TOML, CSS/SCSS/Sass/Less, XML en toekomstige Dockerfiles;
2. GraphQL en SQL worden pas toegevoegd wanneer zulke bestanden in de eigen
   repositorycode voorkomen;
3. Ruff, shfmt, StyLua, Alejandra en OpenTofu blijven rechtstreeks aangeroepen.

## Beschikbare dekking

| Formaat            | dprint-mogelijkheid                                       | Status volgens dprint                     | Advies voor deze repo                                                            |
| ------------------ | --------------------------------------------------------- | ----------------------------------------- | -------------------------------------------------------------------------------- |
| JSON/JSONC         | `dprint-plugin-json`                                      | officiële Wasm-plugin                     | Reeds actief; behouden                                                           |
| Markdown           | `dprint-plugin-markdown`                                  | officiële Wasm-plugin                     | Reeds actief voor gewone Markdown                                                |
| MDX                | geen expliciet geadverteerde MDX-parser                   | Markdown-plugin gebruikt `pulldown-cmark` | Niet als volwaardig ondersteund behandelen; MDX-zware imports uitgesloten houden |
| JS/TS/JSX/TSX      | `dprint-plugin-typescript`                                | officiële Wasm-plugin                     | Reeds actief; behouden                                                           |
| HTML               | `markup_fmt`                                              | standaard wrapper-Wasm-plugin             | Reeds actief; behouden                                                           |
| YAML               | `pretty_yaml`                                             | standaard wrapper-Wasm-plugin             | Reeds actief; behouden                                                           |
| TOML               | `dprint-plugin-toml`                                      | officiële Wasm-plugin                     | Actief voor acht eigen bestanden; imports blijven uitgesloten                    |
| CSS/SCSS/Sass/Less | Malva                                                     | officiële Wasm-plugin                     | Actief; één eigen CSS-bestand                                                    |
| Dockerfile         | `dprint-plugin-dockerfile`                                | officiële Wasm-plugin                     | Actief voor toekomstige Dockerfiles; momenteel geen gevolgd bestand              |
| GraphQL            | `pretty_graphql`                                          | standaard wrapper-Wasm-plugin             | Ondersteund, maar momenteel geen gevolgd GraphQL-bestand                         |
| Python             | Ruff-adapter                                              | officiële Wasm-plugin                     | Niet migreren: de elf eigen bestanden gebruiken Ruff al rechtstreeks             |
| SQL                | `dprint-plugin-sql` rond `sqlformat-rs`                   | nieuwe plugin onder de dprint-organisatie | Nu niet nodig; momenteel geen gevolgd SQL-bestand                                |
| XML                | `markup_fmt`                                              | standaard wrapper-Wasm-plugin             | Actief; de formatterdiff van het ene bestand is beoordeeld                       |
| Shell              | alleen via de Exec-procesplugin en bijvoorbeeld shfmt     | geen eigen taalplugin                     | shfmt rechtstreeks blijven gebruiken                                             |
| Lua                | alleen via de Exec-procesplugin en bijvoorbeeld StyLua    | geen eigen taalplugin                     | StyLua rechtstreeks blijven gebruiken                                            |
| Nix                | alleen via de Exec-procesplugin en bijvoorbeeld Alejandra | geen eigen taalplugin                     | Alejandra rechtstreeks blijven gebruiken                                         |
| Terraform/HCL      | alleen via Exec en bijvoorbeeld OpenTofu                  | geen eigen taalplugin                     | De drie `*.tf`-bestanden en lockfile bij `tofu fmt` houden                       |

De indeling “officieel” versus “wrapper” volgt de [actuele dprint-homepage](https://dprint.dev/); de volledige standaardlijst en actuele
plugin-URL's staan in het [pluginregister](https://plugins.dprint.dev/) en het
algemene [pluginoverzicht](https://dprint.dev/plugins/). Plugins van derden
kunnen eveneens in het register staan; aanwezigheid daar alleen maakt een plugin
dus niet first-party.

## Embedded code en code-fences

De Markdown-plugin laat fenced code blocks formatteren door de andere
geconfigureerde plugins. De officiële documentatie noemt JSON, TypeScript en
JavaScript als voorbeeld. Een nieuwe taalplugin kan daardoor ook extra
code-fences bereiken, mits de fence-taal wordt herkend en de inhoud geldige code
voor die formatter is. Dit moet per nieuw formaat worden getest; het is geen
reden om een taalplugin ongezien repo-breed te activeren. Zie [Markdown: code block formatters](https://dprint.dev/plugins/markdown/#code-block-formatters).

`markup_fmt` formatteert zelf alleen de markup. Voor code in `<script>` en
`<style>` delegeert het aan respectievelijk de TypeScript-plugin en Malva; JSON
in bekende JSON-scripttypes kan aan de JSON-plugin worden gedelegeerd. Dat
gedrag staat in de
[`markup_fmt`-documentatie](https://github.com/g-plane/markup_fmt#dprint).

MDX is een aparte risicocategorie. De officiële Markdown-plugin presenteert zich
als Markdown-formatter en gebruikt
[`pulldown-cmark`](https://github.com/dprint/dprint-plugin-markdown#dprint-plugin-markdown);
MDX wordt niet als ondersteund formaat genoemd. De waargenomen herschikking van
`<Tabs>` en `<Tab>` is daarom geen betrouwbare MDX-formattering. De huidige
uitsluiting van `docs/agentskills.io/**` is passend. Voor een lokale
uitzondering in gewone Markdown zijn [`<!-- dprint-ignore -->` en bereik-comments](https://dprint.dev/plugins/markdown/#ignore-comments)
beschikbaar.

## Bestandsselectie en uitsluitingen

De configuratie heeft een expliciete top-level `includes`-lijst. Een nieuwe
plugin vereist daarom ook passende extensies of bestandsnamen in `includes`.
dprint past eerst `includes` en `excludes` toe en bepaalt pas daarna via
extensies en eventuele plugin-`associations` welke plugin een bestand krijgt.
`overrides` veranderen alleen instellingen en nemen geen extra bestanden op.
Pluginvolgorde bepaalt de voorrang wanneer meerdere plugins hetzelfde bestand
ondersteunen. Zie de officiële
[configuratiedocumentatie](https://dprint.dev/config/).

Top-level `excludes` gebruiken uitgebreide gitignore-globs. dprint negeert
standaard ook repository-`.gitignore`-regels, maar niet automatisch de globale
Git-ignore van één werkstation. Geïmporteerde skillbronnen, gegenereerde
bestanden en applicatieconfiguratie met gevoelige of bewust handgeschreven
structuur moeten expliciet uitgesloten blijven. Voor TOML is een gerichte
uitsluiting van bijvoorbeeld een authenticatieconfiguratie verstandiger dan
onnodige formatter-churn. Zie [dprint CLI: gitignore-gedrag](https://dprint.dev/cli/#gitignore-files).

## Waarom niet alles via dprint Exec

Wasm-plugins draaien volgens dprint zonder netwerk- of bestandssysteemtoegang.
Procesplugins draaien niet gesandboxd. De officiële Exec-plugin kan vrijwel
iedere geïnstalleerde formatter via stdin of een bestandspad aanroepen, maar
vereist extra configuratie voor commando's, extensies, time-outs en
cache-invalidatie. Zie het [veiligheidsverschil tussen plugintypen](https://dprint.dev/plugins/) en de
[`dprint-plugin-exec`-configuratie](https://github.com/dprint/dprint-plugin-exec#configuration).

Voor shfmt, StyLua en Alejandra zou Exec alleen een extra tussenlaag toevoegen
rond de al bestaande tools. De huidige directe Just- en pre-commit-aanroepen
zijn eenvoudiger en houden de taalconfiguratie zichtbaar.

Terraform/HCL heeft dezelfde afweging. De repository controleert `infra/proxmox`
al rechtstreeks met `tofu fmt`; dprint heeft hiervoor geen eigen
standaardtaalplugin. Wrappen via Exec zou geen formatteermogelijkheden
toevoegen.

Hetzelfde geldt voorlopig voor Python. De dprint Ruff-adapter is bruikbaar, maar
zijn pluginversie volgt volgens de [eigen versie-uitleg](https://github.com/dprint/dprint-plugin-ruff#versioning) niet
één-op-één de Ruff-versie die erin zit. Rechtstreeks Ruff gebruiken voorkomt een
tweede versie- en configuratiepad en behoudt de huidige gerichte
repo-uitsluitingen.

## Beheer

Pin pluginversies zoals nu al gebeurt. Controleer beschikbare updates zonder de
configuratie te wijzigen met `dprint config update --dry-run`; de
[configuratiedocumentatie](https://dprint.dev/config/#updating-plugins-via-cli)
beschrijft ook de expliciete updateflow. Beoordeel bij iedere nieuwe plugin
eerst een geïsoleerde formatterdiff en voeg hem daarna pas toe aan pre-commit.
