# map/terrain

The ground of a map: `terrain.tscn`, instanced by every map. Its root `Terrain` is the single owner and the whole API:
heights, holes, ground roles, baked light, bounds, and the only writer of how the ground moves during a match.
- The source is the map's `heights.png` + `void.png` (a 256² grid). Triangles, mesh and collision are derived on load and
  never saved. Paint the PNGs in any image editor, in Blender, or with the editor brushes.
- Everyone asks `Terrain.of(node)` or holds a `terrain: Terrain` socket. Nothing outside this folder sees grid cells or
  vertex ids: the API takes metres.
- Whatever bends the land is a `TerrainStamp` (or a `HoleCutter`) node in its own scene; `Terrain` emits `changed(rect)`
  for every change and `settled(rect)` when it stays. The grid constants live only in `TerrainGrid` and their mirror in
  `look/ground/terrain_deform.gdshaderinc`: change both together.
- `GroundScars` (a child) owns the burn and crack marks painted on the ground; presentation only.
