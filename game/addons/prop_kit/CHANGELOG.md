# PropKit changelog

## 0.1.0

- **Scatter** (`PropScatter3D`, `PropScatter2D`): props over any ground as saved, editable children, from the inspector («Scatter», «Clear»), from code (`scatter()`), from the Tools menu or headless (`tools/scatter_scene.gd`). Deterministic. Shared `PropScatterRules`: clusters from a noise, spacing that grows with scale, size from a cluster's edge to its heart, a cap that cuts at the edges, sink and lean with the slope (3D).
- **Grounds** (`PropGround`): `PropFlatGround` (a rect or an outline), `PropRayGround` (3D: rays against any collider, a maximum slope), or the game's own (`extends PropGround`). **Keep-outs** by group (`PropKeepOut`), a painted **mask** (`PropMask`: thin part way with `density_strength`, `density_invert`), weighted **variants** (`PropVariant`).
- **Batch drawing** (`PropBatch3D`): a MultiMesh per kind of part and per square, the parts hidden, a square redrawn when a prop goes, `refresh()`, `rebuild_all()`, a `mesh_of` hook. Nothing in the editor, headless or on a dedicated server.
- **Navmesh in zones** (`PropNavZones3D`, `PropNavZones2D`):
  - square zones that meet exactly, one region per zone with no edge connections, bakes and index on worker threads (the kit's own tasks: freeing the node or quitting mid-bake waits for them, never hangs);
  - `rebake(areas, reparse)`, with an index of the obstruction nodes by zone, and requests joined while a bake runs;
  - apply AUTO or MANUAL (`bake_ready`, `has_result()`, `is_done()`, `apply()` in zone order), `applied` and `synced`;
  - a saved bake (`PropNavBake`, «Bake», `save_bake()`) that loads at once and goes `stale` when the props or the game's `extra_fingerprint` differ;
  - headless bakes for CI (`tools/bake_scene.gd`, `--check` prints a reproducible content hash);
  - `stats` (PropNavStats).
- **Obstructions** (`PropObstructions`): props of the group `prop_obstruction` cut the navmesh as projected obstructions from their shapes:
  - 3D: Cylinder, Capsule, Sphere, Box, ConvexPolygon and CollisionPolygon3D;
  - 2D: Circle, Rectangle, Capsule, ConvexPolygon and CollisionPolygon2D;
  - `merge_gap` joins close props with a closing that never covers a passage wider than the gap;
  - the fingerprint detects a stale bake.
- **Index** (`PropNavIndex`): connected components across zones, the polygon and component at a point, the closest walkable point, the stitched navmesh.
- **Works around a Godot 4.7 bug**: a navmesh set on a region during its previous asynchronous iteration is lost, so the zones node holds the piece until the region is ready.
- **Examples**: `forest_3d` and `grove_2d` (with the game's own ground). **Tests**: `propkit_lab` (54).
