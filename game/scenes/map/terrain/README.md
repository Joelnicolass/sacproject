# map/terrain
What: the ground of a map. `TerrainShape` (child `Shape`) owns the numbers: heights, holes, tiles, lowest land; `Terrain` shows and collides; `GroundRay` reads the surface height a physics ray finds (roofs and units included).
Not: where a building stands (MapBuilding), the look of the ground (look/ground), pathing (map/nav).
Talks to: everyone asks `TerrainShape.of(node).height_at(x, z)`; `TerrainRules` is the pure arithmetic (also behind `shape.sampler()` for worker threads); Terrain reads `shape.data` for its mesh; `TerrainShape.changed(rect)` is reserved for later edits.
Edit: `data` (MapTerrainData) and `tiles_path` on the map scene's Terrain/Shape; `material_override` and `smooth_ground` on Terrain.
Debug: debug/map/terrain_shape.tscn (headless, prints TERRAIN SHAPE PASS), debug/map/building_gallery.tscn.
