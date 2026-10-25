# scenes/net/

What: glue de red de Sacrifice sobre `addons/mp_kit`: servidor de salas, host local, tickets y `MatchWire`.
Not: nada generico de red (eso es el addon); quien juega con el pick (eso es `SacrificeFlow`).
Talks to: `MatchWire` es la unica conversion id <-> recurso del producto (pick, picks por slot, dios de un bot); `SacrificeFlow`, `SacrificeRoomRules` y `MatchTicketGlue` la llaman. Lo que viaja es el mismo texto de siempre: `{wizard, model, god}`.
Edit: un mago o un dios nuevo no toca nada aca (su `.tres` en `data/catalog/wizards/` o `data/gods/`; `offered` lo saca del lobby). Un nodo nuevo: script y escena aca, componer con hijos y `@export`.
Check: `debug/net/` (`lobby_cases`, `lobby_net_cases`, `local_server_e2e`, `vs_ai_mode`) y `debug/suite/catalog_cases.gd`.
