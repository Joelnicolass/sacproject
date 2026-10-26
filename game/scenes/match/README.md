# scenes/match/

What: the match: rules, clock, defeat, biome and the `match.tscn` scene; the reaches of the places (a soul, a fount, an altar, the Manahoar aura, arming and leashing a Guardian) are shapes of `reach_places.tscn`.
Not: who wins by what (Match state only holds the result) or the radius numbers (they are not in MatchRules any more).
Talks to: MatchRules.reach_places -> ReachFacts (meters, cached per scene) -> SoulSystem, ManaSource, UnitManaSupport and the Guardian bond; ReachFrame lists the nodes.
Edit: move or resize a reach in `reach_places.tscn` (a variant is an inherited scene, e.g. debug/match/far_reach_places.tscn) · round numbers in `data/match_rules.tres`.
Check: `bash tools/lint/conventions.sh` · rules_suite reach_places_cases · debug/match/far_reach_places.tscn (F6).

---

La partida: reglas, reloj, derrota, bioma y la escena `match.tscn`. Las reglas de ronda son un `MatchRules.tres`.

- `match.tscn` (raiz `HighNoon`, nombre heredado: los benches lo usan) trae los sistemas, el HUD y la camara, y no sabe de ningun mapa. Al entrar al arbol, `match_world.gd` pone el mapa de la `MapDefinition` activa (`--map=<tag>`, High Noon por defecto) como primer hijo `Map` y conecta los sistemas a sus enchufes (`MapRoot`).
- `high_noon.tscn` es `match.tscn` heredada con el mapa de High Noon ya puesto: las escenas de `debug/` la instancian y pueden editar nodos del mapa (`HighNoon/Map/...`). Con otro `--map=` el mapa de la escena se reemplaza.
- `match_state.tscn` es el nodo `Match` (resultado y regla de derrota) que `match.tscn` instancia.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/match/`.
