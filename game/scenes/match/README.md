# scenes/match/

What: the match: rules, clock, defeat, biome and the `match.tscn` scene; the reaches of the places (a soul, a fount, an altar, the Manahoar aura, arming and leashing a Guardian) are shapes of `reach_places.tscn`.
Not: who wins by what (Match state only holds the result) or the radius numbers (they are not in MatchRules any more).
Talks to: MatchBiome draws the land (`rules.biome` or BiomeRules over the gods of the catalog), BiomeLink and MatchStateNet (scenes/net/) tell the clients (MatchState emits `snapshot_changed`/`finished`), `applied(god)` -> music, ambience; MatchRules.reach_places -> ReachFacts (meters, cached per scene) -> SoulSystem, ManaSource, UnitManaSupport and the Guardian bond; ReachFrame lists the nodes.
Edit: move or resize a reach in `reach_places.tscn` (a variant is an inherited scene) · round numbers in `data/match_rules.tres`.
Check: `bash tools/lint/conventions.sh`

---

La partida: reglas, reloj, derrota, bioma y la escena `match.tscn`. Las reglas de ronda son un `MatchRules.tres`.

- `match.tscn` (raiz `Match`, script `MatchWorld`) trae los sistemas, el HUD y la camara, y no sabe de ningun mapa. Al entrar al arbol, `match_world.gd` pone el mapa de la `MapDefinition` activa (`--map=<tag>`, High Noon por defecto) como primer hijo `Map` y conecta los sistemas a sus enchufes (`MapRoot`).
- `match_state.tscn` es el nodo `Match` (resultado y regla de derrota) que `match.tscn` instancia.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`.
