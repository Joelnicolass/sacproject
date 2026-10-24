# map/terrain
What: the ground of a map. `TerrainShape` (child `Shape`) owns the numbers: heights, holes, tiles, lowest land; `Terrain` shows and collides; `GroundRay` reads the surface height a physics ray finds (roofs and units included).
Not: where a building stands (MapBuilding), the look of the ground (look/ground), pathing (map/nav).
Talks to: everyone asks `TerrainShape.of(node).height_at(x, z)`; `TerrainRules` is the pure arithmetic (also behind `shape.sampler()` for worker threads); Terrain reads `shape.data` for its mesh; `TerrainShape.changed(rect)` is reserved for later edits.
Edit: `data` (MapTerrainData) and `tiles_path` on the map scene's Terrain/Shape; `material_override` and `smooth_ground` on Terrain.
Check: debug/map/terrain_shape.tscn (headless, prints TERRAIN SHAPE PASS), debug/map/building_gallery.tscn.

---

Marks on the ground (061k-5): `GroundScars` (child of `Terrain`, in every map) is the one owner of the burns, cracks and craters painted into the ground: 64 x 64 tiles of 10 m in a `Texture2DArray` plus a 256 x 256 index, both shader globals (`scar_index`, `scar_tiles`) that `ground_scars.gdshaderinc` reads in the two ground shaders; `GroundScarRules` is the arithmetic (tiles touched, oldest tile out, height filter). The limit is the option «Cantidad de marcas» (32-256). Presentation only: headless it holds nothing. Effects ask for a mark with a `ScarMark` (scenes/spells/scar_mark.gd). Check: `debug/look/scars_lab.tscn` (F6: click to paint, 1..9 picks the mark, F throws a burst to see the oldest tiles go) · rules_suite `scar_cases` (or `debug/suite/scar_cases.tscn` alone).
