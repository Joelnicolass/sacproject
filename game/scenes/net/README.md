# scenes/net/

What: glue de red de Sacrifice sobre `addons/mp_kit`: servidor de salas, host local, tickets, `PickBoard` (los picks por asiento) y `MatchWire`.
Not: nada generico de red (eso es el addon); quien juega con el pick (eso es `SacrificeFlow`).
Talks to: `MatchWire` es la unica conversion id <-> recurso del producto (pick, picks por slot, dios de un bot, mapa y modo del snapshot, opciones de una sala); `SacrificeFlow`, `PickBoard`, `SacrificeRoomRules` y `MatchTicketGlue` la llaman. `LaunchFlags` (linea de comandos) y `TicketPlan` (ticket de una sala) devuelven un `LaunchPlan` con datos y no tocan el flujo: el flujo los aplica. Lo que viaja es el mismo texto de siempre: `{wizard, model, god}`, `{map, mode}`.
Edit: un mago, un dios, un mapa o un modo nuevo no toca nada aca (su `.tres` o su carpeta; `offered` saca un mago o un dios del lobby). Un nodo nuevo: script y escena aca, componer con hijos y `@export`.
Check: `debug/net/` (`lobby_cases`, `lobby_net_cases`, `local_server_e2e`, `vs_ai_mode`, `late_join`) y `debug/suite/catalog_cases.gd`.
