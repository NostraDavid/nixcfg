# Herdr-app spaces snapshot

`spaces.snapshot.json` is a static snapshot captured on 2026-10-30 with
`herdr-app ls`. It contains only each space's `name` and `folder`, in the
reported order. It is documentation for manual recovery, not a Herdr-app import
file: the app does not read it, and it is not linked to or written over live
state. Recent entries, runtime IDs, tabs, terminals, and process data are
intentionally excluded.

## Actualiseren

Run `herdr-app ls`. Replace the JSON array in `spaces.snapshot.json` with the
current `spaces` entries, preserving their order and keeping only `name` and
`folder`. Do not include the separate `recent` list or any other fields.

## Handmatig herstellen

For each missing space, check that its recorded folder exists, then use
Herdr-app's interface to create a space with that exact name and folder. Repeat
one at a time and verify the result with `herdr-app ls`. Do not copy this file
over Herdr-app's live state or symlink it there; it is not a supported import
format.
