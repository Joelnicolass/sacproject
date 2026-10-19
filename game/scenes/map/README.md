# scenes/map/

El mapa: layout, edificios, spawns de NPC, terreno, navegacion (`nav/`), props (`props/`) y los mapas mismos (`maps/`). El mapa se edita en Godot; la navegacion se hornea con `tools/bake/bake_nav.tscn`.

- `MapDefinition` (`map_definition.gd`) reune lo que el juego sabe de un mapa: escena, bandos (`MapSides`), navmesh, terreno, tiles, luz, asientos de jugador, imagen y entradas del horneado. `MapCatalog` (`data/maps/map_catalog.tres`) las lista; `MapCatalog.active()` es la del proceso (`--map=<tag>`).
- `MapRoot` (`map_root.gd`) es la raiz de una escena de mapa: terreno, region de navegacion, `Starts`, look, bake del minimapa y las raices del layout. La partida se conecta a esos enchufes.
- `SideRelations` separa asiento (slot de jugador) de bando del mapa: los asientos son los primeros `player_starts` slots y los bandos sin jugador (NPC) vienen despues.

## Agregar un mapa nuevo (sin tocar codigo)

1. Carpeta `scenes/map/maps/<tag>/` con `map.tscn` (raiz `MapRoot`; copiar `test_flat/map.tscn` y editarla), `<tag>.tres` (una `MapDefinition`) y `sides.tres`.
2. Sumar la definicion a `data/maps/map_catalog.tres`.
3. Hornear el navmesh: `bake_nav.tscn` de tools/bake con `-- --map=<tag>`.
4. Jugarlo: `--map=<tag>` (por ejemplo `res://scenes/match/match.tscn -- --map=test_flat`).

`test_flat` es el mapa de prueba: un cuadrado plano de 600 m, dos altares y un manantial. Sin edificios ni habitantes.

Agregar uno nuevo: poner el script y la escena aca, componer con nodos hijos y `@export` (nada de herencia profunda), y los datos de tipo en `data/` como `.tres`. Las pruebas de este dominio van en `debug/map/`.
