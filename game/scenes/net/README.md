# net

Sacrifice's network glue on top of `addons/mp_kit`. Nothing generic lives here (who sits and when the match starts is
the kit's `MpMatchGate`).
- `MatchWire` is the only id ↔ resource conversion of the game (pick, map, mode, room options).
- `PickBoard` (picks by seat) and `SeatPresence` (the server log of each seat, defeat on abandon) are children of `SacrificeFlow`.
- `MatchStateNet` and `BiomeLink` carry the match state and the god of the land to clients and to a seat that rejoins.
- `LaunchFlags` (command line) and `TicketPlan` (a room's ticket) return a `LaunchPlan`; the flow applies it.
Check: `grep "^partida "` in the server log.
