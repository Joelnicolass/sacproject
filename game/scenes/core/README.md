# scenes/core/

What: arranque (`boot`), flujo de la partida (`SacrificeFlow`, un autoload que es escena), catalogo (`GameCatalog`, `GameData`, `MapCatalog`, `GameModeCatalog`), `ActiveMatch` (el mapa y el modo que juega este proceso) y `debug_log`. Es lo que sobrevive al cambio de escena. `ScreenGate.is_open()` dice si este proceso dibuja (no headless ni dedicado): lo preguntan el temblor de camara y los numeros de dano.
Not: reglas de partida (eso es `scenes/match/`) ni el cable de red (eso es `scenes/net/match_wire.gd`). Los catalogos solo listan y buscan; no recuerdan cual se juega.
Talks to: `boot` y las pantallas llaman a `SacrificeFlow`; el flujo guarda un `WizardPick` (mago + dios) y un `MatchSetup` tipado (mapa, modo, tierra) y se los pasa a `ActiveMatch.choose`; el mundo lee `ActiveMatch.map()` / `mode()`. Con la red habla solo por `MatchWire`, `LaunchFlags` y `TicketPlan`.
Edit: `flow/sacrifice_flow.tscn` -> `default_pick` (lo que esta elegido al abrir el menu) y `vs_ai_seat` (el rival de «Contra la IA»): se cambian arrastrando un mago, un dios o un asiento. Un mapa nuevo es una carpeta en `scenes/map/maps/`; un modo nuevo, un `.tres` en `data/modes/` arrastrado a `mode_catalog.tres`.
Check: `debug/suite/catalog_cases.gd`, `debug/ui/team_screens_check.tscn`, `debug/net/vs_ai_mode.tscn`.
