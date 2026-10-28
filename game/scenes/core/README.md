# core

What survives a scene change: `boot.tscn` (the main scene, the menu), the `SacrificeFlow` autoload (`flow/`), the
catalogs and `ActiveMatch` (`catalog/`), and `DebugLog`.
`ActiveMatch` is the only place that knows the map, mode and seed this process plays; catalogs only list and look up.
`ScreenGate.is_open()` says whether this process draws (false headless or on a dedicated server).
Edit: `flow/sacrifice_flow.tscn` → `default_pick` (the pick the menu starts with) and `vs_ai_seat` (the «Contra la IA» rival).
