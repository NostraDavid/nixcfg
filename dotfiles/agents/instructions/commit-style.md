# Commit Style

Gebruik Scoped Commits tijdens een git commit.

## Formaat

```text
<scope>: <omschrijving>

[optionele body]

[optionele trailers]
```

* Zet altijd de `<scope>` vooraan; dit is het onderdeel, domein of subsystem dat
  gewijzigd is.
* Gebruik een korte, duidelijke omschrijving van de wijziging na de dubbele
  punt.
* Voeg indien nodig een body toe met extra uitleg.
* Voeg indien nodig trailers toe voor metadata, zoals referenties of co-auteurs.
* Speciale commits zoals merges en reverts mogen een afwijkend formaat hebben.
* Definieer binnen een project een vaste lijst met geldige scopes en gebruik die
  consequent.

Voorbeelden:

```text
auth: voeg SSO-ondersteuning toe
api: corrigeer foutafhandeling bij time-outs
pipeline: upgrade Databricks-runtime
docs: werk installatiehandleiding bij
```

Het belangrijkste verschil met Conventional Commits, wat verboden is, is dat
**de scope centraal staat**, niet het type commit (`feat`, `fix`, `chore`, enz).
