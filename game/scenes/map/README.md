# map
What: one playable map: terrain, navmesh, buildings, NPC spawns, altars/manafounts, player starts. Maps are edited in Godot.
Not: the match rules (`scenes/match/`), the look and sky (`scenes/look/`), the creatures that live there (`scenes/units/`).
Talks to: `MapRoot` exposes sockets (`terrain`, `nav_region`, `starts`, `look`, `buildings_root`, `npc_spawns_root`); the match plugs into them.
Talks to: `MapBuilding.destroyed` goes up to `NavService` (it updates the navmesh); `MapPopulation` asks `UnitSpawner` for creatures and emits `populated`.
Edit: `maps/<tag>/map.tscn` + `<tag>.tres` (`MapDefinition`) + `sides.tres`; list it in `data/maps/map_catalog.tres`; bake the navmesh with `tools/bake/bake_nav.tscn`.
Debug: `debug/map/*.tscn` (F6; e.g. `village.tscn`, `nav_cross.tscn`, `ground_probe.gd`).
Known debt: 5 representations of the ground with no single owner (055d-t `TerrainShape`).

---
El mapa: layout, edificios, spawns de NPC, terreno, navegacion (`nav/`), props (`props/`) y los mapas mismos (`maps/`). El mapa se edita en Godot; la navegacion se hornea con `tools/bake/bake_nav.tscn`.

- `MapDefinition` (`map_definition.gd`) reune lo que el juego sabe de un mapa: escena, bandos (`MapSides`), navmesh, terreno, tiles, luz, asientos de jugador, imagen y entradas del horneado. `MapCatalog` (`data/maps/map_catalog.tres`) las lista; `MapCatalog.active()` es la del proceso (`--map=<tag>`).
- `MapRoot` (`map_root.gd`) es la raiz de una escena de mapa: terreno, region de navegacion, `Starts`, look, bake del minimapa y las raices del layout. La partida se conecta a esos enchufes.
- `SideRelations` separa asiento (slot de jugador) de bando del mapa: los asientos son los primeros `player_starts` slots y los bandos sin jugador (NPC) vienen despues.

## Agregar un mapa nuevo (sin tocar codigo)

1. Carpeta `scenes/map/maps/<tag>/` con `map.tscn` (raiz `MapRoot`; copiar `test_flat/map.tscn` y editarla), `<tag>.tres` (una `MapDefinition`) y `sides.tres`.
2. Sumar la definicion a `data/maps/map_catalog.tres`.
3. Hornear el navmesh: `bake_nav.tscn` de tools/bake con `-- --map=<tag>`.
4. Jugarlo: `--map=<tag>` (por ejemplo `res://scenes/match/match.tscn -- --map=test_flat`).

Los mapas del original (High Noon, `peaks`, `peasantville`, `roads`, `winter_wonder`) se importan con `tools/import/import_map.py` y `scaffold_map.py`: el paso a paso está en `docs/HOWTO.md` («Un mapa») y la lista de los 31 en `rfcs/RFC-050-original-maps.md`.

`test_flat` es el mapa de prueba: un cuadrado plano de 600 m, dos altares y un manantial. Sin edificios ni habitantes.

