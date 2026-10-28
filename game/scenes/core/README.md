# core

What survives a scene change: `boot.tscn` (the main scene, the menu), the `SacrificeFlow` autoload (`flow/`), the
catalogs and `ActiveMatch` (`catalog/`), and `DebugLog`.
`ActiveMatch` is the only place that knows the map, mode and seed this process plays; catalogs only list and look up.
`ScreenGate.is_open()` says whether this process draws (false headless or on a dedicated server).
Edit: `flow/sacrifice_flow.tscn` → `default_pick` (the pick the menu starts with) and `vs_ai_seat` (the «Contra la IA» rival).
`Events` (`events.gd`, autoload) is the game-wide event bus: only typed signals (`body_hurt`, `ritual_started`, `ritual_ended`, `match_ended`); the owner of each fact emits it on every peer.
