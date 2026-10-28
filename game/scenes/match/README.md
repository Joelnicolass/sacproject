# match

The match: `match.tscn` (root `MatchWorld`, which knows no map: it adds the active map as child `Map`), `MatchState`
(altars, defeated sides, winner; its `Defeat` child decides), the clock, the seed, the sky clock and the biome.
Round numbers are in `data/match_rules.tres`; the reaches of places (soul, fount, altar, Manahoar aura, Guardian) are
shapes in `reach_places.tscn`, moved with the gizmo.
