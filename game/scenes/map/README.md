# map

One playable map: terrain, navmesh, buildings, NPC spawns, altars, manafounts and player starts, all edited in Godot.
`MapRoot` is the root of a map scene and exposes the sockets the match plugs into. `MapDefinition` (`maps/<tag>/<tag>.tres`)
is what the game knows of a map; `MapCatalog` finds the maps by walking `maps/`, so a new one needs no list.
- New map: Project > Tools > «New map…» (copies `maps/_template/`). Then «Bake navmesh» on `NavRegion` and «Validate map».
- Play one: `--map=<tag>`. Check: `tools/audit/check_map.tscn -- --map=<tag>`.
- Forest: `MapProps/Forest` (ForestScatter) plants `forest_tree.tscn` props with «Scatter» (or
  `tools/look/scatter_forest.tscn -- --map=<tag>` headless); bake the navmesh after. The match option «Bosque» turns it off.
- `*.import` is git-ignored: add a map's `.import` files with `git add -f`.
- Maps of the original are imported with `tools/import/import_map.py` and `scaffold_map.py` (see `docs/HOWTO.en.md`).
