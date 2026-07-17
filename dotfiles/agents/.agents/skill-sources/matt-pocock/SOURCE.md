# Matt Pocock

- Bron: <https://github.com/mattpocock/skills>
- Upstream-revisie: `9603c1cc8118d08bc1b3bf34cf714f62178dea3b`
- Licentie: MIT; zie `LICENSE.txt`
- Lokale importcommit: `fc353990fcf8b784a1ba3b3af1bdb26ba7665768`
- Selectie: de 22 door upstream als `engineering` en `productivity` gepromote
  skills

De upstream-mappen `misc`, `personal`, `in-progress` en `deprecated` zijn niet
meegenomen. Claude-specifieke frontmatter en aanroepnotatie zijn vervangen door
de lokale Agent Skills- en `agents/openai.yaml`-conventies.

De shelltemplate van `diagnosing-bugs` is lokaal herontworpen als een
gevalideerde, zelftestende Python 3.14-CLI met een TOML-plan voor menselijke
stappen en captures. Behoud die aanpassing bij een upstream-update en voer de
Python-pariteitsaudit opnieuw uit.
