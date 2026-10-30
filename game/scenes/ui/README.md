# ui

The interface, one subfolder per screen or widget. Screens call `SacrificeFlow` (or `MpLobby`); they never build network
ids (only `MatchWire` does). A picker lists a catalog and returns the chosen resource, so a new god, map or mode shows up
by itself. Player-facing text goes through `tr()` with keys in `scenes/ui/i18n/strings.csv`.
