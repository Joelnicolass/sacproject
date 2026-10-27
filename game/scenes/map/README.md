# map
What: one playable map: terrain, navmesh, buildings, NPC spawns, altars/manafounts, player starts. Maps are edited in Godot.
Not: the match rules (`scenes/match/`), the look and sky (`scenes/look/`), the creatures that live there (`scenes/units/`).
Talks to: `MapRoot` exposes sockets (`terrain`, `nav_region`, `starts`, `look`, `buildings`, `npcs`, `props`); the match plugs into them.
Talks to: `Terrain/Shape` (the `Terrain`, which `MapRoot.terrain` points at) moves the ground and `Terrain/Collision` collides it after it loaded (see `terrain/README.md`); `MapBuilding.damaged(fraction_left)` (every hit) and `MapBuilding.destroyed` (once) fire on every peer from the replicated `Health:current`: `NavService` updates the navmesh, and the children `StructureBreak` / `BuildingRuin` (`scenes/structures/breaking/`) burst and show the ruin; a new reaction is one more child that listens; `MapPopulation` asks `UnitSpawner` for creatures and emits `populated`.
Edit: `maps/<tag>/map.tscn` + `<tag>.tres` (`MapDefinition`); drag building scenes under `Buildings`, decoration scenes (`scenes/props/`) under `Props`, `NpcSpawn` under `Npcs`, move `WizardSpot` under each start; the `GroundFootprint` box of `props/altar.tscn` and `props/manafount.tscn` is the base that must lie level (`FootprintRules` measures it); the `BuildArea` cylinder of `props/manafount.tscn` (radius with the gizmo, `core_m`/`push_mps`/`push_caster` in the inspector) is the ground a tower cast clears; bake the navmesh with the «Hornear navmesh» button of `NavRegion`.
Check: `debug/map/*.tscn` (F6; e.g. `village.tscn`, `nav_cross.tscn`, `ground_probe.gd`) · `debug/spells/cast_terrain.tscn` (F6, the ground that moves) · rules_suite `terrain_cases`, `build_area_cases` · `tools/audit/check_map.tscn -- [--map=<tag>]` (headless, `CHECK MAP <tag> PASS`).
Known debt: 5 representations of the ground with no single owner (055d-t `Terrain`).

---
El mapa: edificios, spawns de NPC, terreno, navegacion (`nav/`), props (`props/`) y los mapas mismos (`maps/`). El mapa se edita en Godot; la navegacion se hornea con el boton «Hornear navmesh» de `NavRegion` (corre `tools/bake/bake_nav.tscn`).

- `MapDefinition` (`map_definition.gd`) reune lo que el juego sabe de un mapa: escena, terreno, luz, navmesh (todos tipados), asientos de jugador e imagen. `MapCatalog` las encuentra recorriendo `scenes/map/maps/`; `MapCatalog.active()` es la del proceso (`--map=<tag>`). Los bandos salen de los nodos del mapa (`MapSides`): cada `PlayerStart` es un asiento (`slot`, `team`) y cada `side` de un `NpcSpawn` es un bando sin jugador.
- `MapRoot` (`map_root.gd`) es la raiz de una escena de mapa: terreno, region de navegacion, `Starts`, look, bake del minimapa, `Buildings` y `Npcs`. La partida se conecta a esos enchufes.
- `SideRelations` separa asiento (slot de jugador) de bando del mapa: los asientos son los primeros `player_starts` slots y los bandos sin jugador (NPC) vienen despues.

## Agregar un mapa nuevo (sin tocar codigo)

1. En el editor: Proyecto → Herramientas → «Mapa nuevo…», escribir el tag (`mi_mapa`, minusculas) y el nombre, y «Crear». Copia `maps/_template/` a `maps/<tag>/` (suelo plano, todo pasto, dos inicios y tres manantiales), escribe `<tag>.tres` y `nav.res`, hornea el navmesh, abre la escena y corre «Validar mapa» (tiene que dar PASS). El catalogo lo ve solo: sin lista que editar.
2. Editarlo: pinceles del `Terrain`, arrastrar edificios, props y `NpcSpawn`, mover inicios y manantiales con el gizmo; despues, «Hornear navmesh» en `NavRegion` y «Validar mapa».
3. Jugarlo: `--map=<tag>` (por ejemplo `res://scenes/match/match.tscn -- --map=mi_mapa`).

Lo que todo mapa nuevo trae se cambia en `maps/_template/map.tscn` (ver su README). Copiar `test_flat` a mano ya no es el camino. Al versionar el mapa, `*.import` esta en `.gitignore`: sumá sus `.import` con `git add -f` (el de `ground_roles.png` lleva `fix_alpha_border=false`).

Ojo: `tools/import/bake_ground_roles.py` pisa el `ground_roles.png` de los mapas importados; si ya pintaste sus roles a mano, no lo vuelvas a correr sobre ese mapa.

Los mapas del original (High Noon, `peaks`, `peasantville`, `roads`, `winter_wonder`) se importan con `tools/import/import_map.py` y `scaffold_map.py`: el paso a paso está en `docs/HOWTO.md` («Un mapa») y la lista de los 31 en `rfcs/RFC-050-original-maps.md`.

`test_flat` es el mapa de prueba: un cuadrado plano de 600 m, dos altares y un manantial. Sin edificios ni habitantes.

