# scenes/core/

What: arranque (`boot`), flujo de la partida (`SacrificeFlow`, un autoload que es escena), catalogo (`GameCatalog`, `GameData`) y `debug_log`. Es lo que sobrevive al cambio de escena.
Not: reglas de partida (eso es `scenes/match/`) ni el cable de red (eso es `scenes/net/match_wire.gd`).
Talks to: `boot` y las pantallas llaman a `SacrificeFlow`; el flujo guarda un `WizardPick` (mago + dios) y habla con la red solo por `MatchWire`.
Edit: `flow/sacrifice_flow.tscn` -> `default_pick` (lo que esta elegido al abrir el menu) y `vs_ai_seat` (el rival de «Contra la IA»): se cambian arrastrando un mago, un dios o un asiento.
Check: `debug/suite/catalog_cases.gd`, `debug/ui/team_screens_check.tscn`, `debug/net/vs_ai_mode.tscn`.
