# core

What survives a scene change: `boot.tscn` (the main scene, the menu), the `SacrificeFlow` autoload (`flow/`), the
catalogs and `ActiveMatch` (`catalog/`), and `DebugLog`.
`ActiveMatch` knows the map, mode and seed this process plays; the one of the game is `SacrificeFlow.active_match` (flow
state: chosen before the world loads, forgotten when the match ends). Catalogs only list and look up.
`ScreenGate.is_open()` says whether this process draws (false headless or on a dedicated server).
Edit: `flow/sacrifice_flow.tscn` → `default_pick` (the pick the menu starts with) and `vs_ai_seat` (the «Contra la IA» rival).
`Events` (`events.gd`, autoload) is the game-wide event bus: only typed signals (`body_hurt`, `ritual_started`, `ritual_ended`, `match_ended`); the owner of each fact emits it on every peer.
