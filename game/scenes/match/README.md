# match

The match: `match.tscn` (root `MatchWorld`, which knows no map: it adds the active map as `World/Map`), `MatchState`
(altars, defeated sides, winner; its `Defeat` child decides), the clock, the seed, the sky clock and the biome.
Round numbers are in `data/match_rules.tres`; the reaches of places (soul, fount, altar, Manahoar aura, Guardian) are
shapes in `reach_places.tscn`, moved with the gizmo.

Tree: the root holds five plain groups. `World` (Node3D: camera, map, bodies, spells, shots, structures, their spawners,
biome), `Systems` (souls, sacrifices, `MatchState`, `Nav`, `AiRoster`, seat, warm-up, option appliers), `Input` (selection,
orders, commands, radial menu, inspector), `Hud` (CanvasLayer with the interface and the pause menu) and `Audio`.
Link nodes with `@export` or `%UniqueName`, never with a path from the root.
