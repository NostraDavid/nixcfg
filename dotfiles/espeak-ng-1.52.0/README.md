# Uitspraakregels voor say

## eSpeak en MBROLA

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

## Piper

Pas de vervangingsregels in `piper.sed` aan, bijvoorbeeld:

```sed
s/\<nixcfg\>/niks config/g
```

`\<` en `\>` begrenzen een volledig woord. Voor Engelse uitspraak kunnen
vervangingen een IPA-blok tussen `[[` en `]]` bevatten. `\xCB\x88` is de
UTF-8-notatie voor het IPA-klemtoonteken U+02C8.

Home Manager koppelt dit bestand aan `~/.config/say/piper.sed`. `say piper`
leest het bij elke aanroep, zowel voor argumenten als voor stdin. Na de eerste
`just switch` zijn wijzigingen aan de regels direct actief. Met
`XDG_CONFIG_HOME` kun je een andere configuratiemap gebruiken.
