# Uitspraakregels voor say

Voeg Nederlandse uitspraakregels toe aan `nl_extra`, bijvoorbeeld:

```text
nixcfg    niks config    $text
```

`$text` laat eSpeak de vervangende tekst uitspreken. Zie de
[eSpeak-woordenboekdocumentatie](https://github.com/espeak-ng/espeak-ng/blob/master/docs/dictionary.md)
voor fonemen en aanvullende regels.

Voer na wijzigingen `just switch` uit. Nix compileert de lijst samen met het
oorspronkelijke Nederlandse woordenboek. Home Manager koppelt de resulterende
datamap aan `~/.config/say/espeak-ng-data`; `say` gebruikt die via `--path`.
Voor een andere datamap kan `SAY_DATA_PATH` wijzen naar de map die
`espeak-ng-data` bevat.
