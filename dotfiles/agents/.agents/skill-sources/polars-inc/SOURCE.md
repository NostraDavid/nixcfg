# Herkomst: polars-inc/skills

- Upstream: <https://github.com/polars-inc/skills>
- Revisie: `v0.2.0`
- Selectie: `polars`
- Licentie: MIT; zie [`LICENSE.txt`](LICENSE.txt)
- Exacte snapshot:
  [`../../skill-originals/polars-inc/v0.2.0`](../../skill-originals/polars-inc/v0.2.0)

De actieve variant behoudt de inhoudelijke Polars-referenties, maar scherpt de
activatie en workflow aan. Zij kiest Polars niet automatisch boven een expliciet
gevraagde bibliotheek, staat zowel lazy als gepast eager gebruik toe, maakt
correctheidscontroles expliciet en vermijdt absolute prestatieregels. De
upstream `.claude-plugin`-metadata en skill-README zijn alleen in de exacte
snapshot bewaard; de actieve skill gebruikt de gedeelde agent-skillindeling.

Bij een update wordt een nieuwe onveranderde snapshot naast de bestaande revisie
geplaatst. Vergelijk daarna upstream met de actieve variant via
`skill-originals/compare.sh polars-inc polars` en beoordeel de lokale
aanpassingen opnieuw.
