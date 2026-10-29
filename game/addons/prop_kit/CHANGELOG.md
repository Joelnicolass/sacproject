# PropKit changelog

## 0.2.1

- **Synchronous navigation iterations.** With `navigation/world/map_use_async_iterations` off (a lockstep game sets it so, for the same swap tick on every machine), `is_ready()` never came and `updated` never arrived: the map rebuilds with the regions in the same step, and the node waited for one more map iteration that never comes. Now a synchronous map counts as up to date once its regions have rebuilt. `tools/bake_scene.tscn` finishes in such projects too.
- **Tests**: 68.

## 0.2.0

The navmesh API, rethought for people. **It breaks 0.1.**

- **The navmesh follows its props.** A prop freed or added in play re-bakes its zones on its own (`follow_props`, the changes of a frame joined); a group added right after `add_child()` counts. `rebake_prop(prop)` for one that moved. The game's code to chop a tree is `tree.queue_free()`.
- **Re-bakes said by name.** `rebake(position, radius)` (the ground or a building changed: parse again), `rebake_prop(prop)`, `rebake_all()`. Gone: `rebake(areas, reparse)` and `rebake_all(reparse)`.
- **One signal for "the paths see it".** `updated` (the navigation map uses the latest pieces, with their `index`), `is_ready()` (the first pieces are in; it stays true) and `is_updating()`. Gone: `applied`, `synced`, `is_done()`, `is_synced()`.
- **MANUAL waits only for changes in play.** The kit's own bakes (the start, a stale saved bake) apply at once.
- **A stale saved bake is never used**: it bakes again first (`rebake_when_stale`). A saved bake loads with its index, swapped in together.
- **The fingerprint covers the settings**: the template, the zone grid, `height_range`, the obstruction settings. A saved bake cut on another grid emits `stale` too. `extra_fingerprint` can be set any time; the pieces in force are checked again then. Bakes saved with 0.1 are stale: press «Bake».
- **The index**: `can_reach(a, b, max_distance)` (was `same_component`), `component_at(point, max_distance)`, and `closest_point(point, max_distance, min_area)` measures `max_distance` on the ground plane, whatever the navmesh's height above it.
- **The inspector**: what most games set first, the rest under Advanced.
- **The command-line tools are scenes**: `tools/bake_scene.tscn` and `tools/scatter_scene.tscn`, so the project runs as the game does (its main loop, its autoloads).
- **In the editor**: «Bake» saves the scene, bakes it in a separate headless Godot and reloads it (the scene's place in the editor plays no part); «Scatter» and «Clear» can be undone, and a scatter that cannot run keeps the props; Project > Tools > *PropKit: Bake the open scene*; the 3D and 2D views draw a scatter's ground and a zones node's zones; warnings for a stale saved bake, no props, props parsed as geometry, a zone size or cell size off.
- **2D: no edge errors.** Godot's 2D bake can leave vertices closer than a cell of the navigation map, which then leaves edges unjoined ("More than 2 edges…"). The kit welds them in each piece; `merge_gap` outlines lose their edges shorter than a cell.
- **Tests**: 66, and an editor check (`PROPKIT_EDITOR_CHECK=1`, 17 checks in a real editor).

## 0.1.1

- **Seams that hold when the ground changes height (3D).** The floor and ceiling of every zone's bake are whole cells of `cell_height` from 0. Before, they came straight from the parse's bounds: a zone re-baked after the ground went below its lowest point measured its heights from another floor, and the navigation map no longer joined it to the zones next to it. `height_range` (floor, ceiling) gives every zone the same box. A bake saved with 0.1.0 can have its floor off the cell grid: press «Bake» again.
- **Islands in the index.** `PropNavIndex.component_area` (each component's area on the ground plane) and `closest_point(point, max_distance, min_area)` (and `closest_point_2d`): the closest land, skipping a walkable roof or a pocket closed off by walls.
- **Tests**: 58.

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
