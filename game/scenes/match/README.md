# scenes/match/

La partida: reglas, reloj, derrota, bioma y la escena `match.tscn`. Las reglas de ronda son un `MatchRules.tres`.

- `match.tscn` (raiz `HighNoon`, nombre heredado: los benches lo usan) trae los sistemas, el HUD y la camara, y no sabe de ningun mapa. Al entrar al arbol, `match_world.gd` pone el mapa de la `MapDefinition` activa (`--map=<tag>`, High Noon por defecto) como primer hijo `Map` y conecta los sistemas a sus enchufes (`MapRoot`).
- `high_noon.tscn` es `match.tscn` heredada con el mapa de High Noon ya puesto: las escenas de `debug/` la instancian y pueden editar nodos del mapa (`HighNoon/Map/...`). Con otro `--map=` el mapa de la escena se reemplaza.
- `match_state.tscn` es el nodo `Match` (resultado y regla de derrota) que `match.tscn` instancia.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/match/`.
