# PropKit

Props for 2D and 3D worlds, in three independent pieces:

1. **Scatter.** Plants props over any ground as saved, editable nodes: clusters from a noise, keep-outs around the game's own nodes, a painted mask, weighted variants.
2. **Batch drawing (3D).** Draws thousands of them in a few draw calls.
3. **Navmesh in zones.** Bakes the navmesh in square zones with the props as cheap projected obstructions, so a change re-bakes only the zones it touches, on worker threads.

There is no network, no game rule and no autoload, and PropKit depends on no other kit. Each piece works without the others.

```bash
./install.sh --addon /path/to/godot-project prop_kit
```

Enable the **PropKit** plugin: it adds the editor tools ([In the editor](#in-the-editor)). The kit's nodes work without it too.

Examples: `examples/forest_3d/forest_3d.tscn` (a forest, batches, a navmesh in 16 zones; click twice for a path, C chops, R gives a new forest) and `examples/grove_2d/grove_2d.tscn` (bushes around walls, a 2D navmesh; the same keys).

## The ground plane

Every kit point is on the ground plane: **(x, z) in 3D** and **(x, y) in 2D**, in global coordinates, as a `Vector2`. Distances are the world's units: metres in 3D, pixels in 2D.

## 1. Scatter

```
World
├── Ground              # anything with collision (3D, for PropRayGround)
├── Forest              # PropScatter3D: rules, ground, variants, keep_out, mask
│   ├── Prop0000        # the props: saved children, move or delete them like any node
│   └── …
└── Camps/Start         # in a group the scatter keeps out of
```

1. Add a **PropScatter3D** (or **PropScatter2D**).
2. Set **rules**: a `PropScatterRules`, which you can share between maps.
3. Set **ground** (see below). The editor draws its outline.
4. Add **variants**: a `PropVariant` per scene, each with a weight.
5. Press **Scatter** in the inspector. **Clear** removes the props. Ctrl+Z undoes either.

The same rules and seed always give the same props. Scattering again replaces every child of the node; a scatter that cannot run (no ground, no variant) leaves them as they are.

The props are ordinary children owned by the scene, so they are saved and you can edit them with the gizmo. From code: `scatter.scatter(scene_owner)`. From a build step or CI (a scene, so the project runs as the game does, autoloads included):

```bash
godot --headless --path . res://addons/prop_kit/tools/scatter_scene.tscn -- --scene=res://maps/forest.tscn
```

The `rules`:

| Rule | What it does |
|---|---|
| `random_seed` | The noise and every roll |
| `cluster_size`, `cover`, `edge`, `density`, `lone_chance` | Clusters: woods and clearings. `cover` 1 = an even scatter |
| `spacing` | Room between two props of scale 1, centre to centre. It grows with their scale |
| `scale_range`, `scale_jitter` | Small at a cluster's edge, big at its heart, plus a random part |
| `keep_out_shrink` | Smaller props near a keep-out |
| `random_rotation` | A random turn for each prop |
| `max_count` | The cap. The cut falls at cluster edges first |
| `sink`, `align_to_normal` | 3D: into the ground, and leaning with the slope |

**Ground** (`PropGround`): where props may stand. It gives the area, the height and normal (3D), and a weight from 0 (never) to 1 (fully).

- `PropFlatGround`: a rect or a polygon outline at one height. The usual ground in 2D.
- `PropRayGround` (3D): a ray straight down against `collision_mask`, with `max_slope_deg`. It works with any collider, in the editor and in play. Keep the props' own layer out of its mask.
- **The game's own ground**: a script that `extends PropGround` (or a kit ground) and answers from the game's terrain. It needs `@tool`, because the scatter calls it in the editor. `examples/grove_2d/grove_ground.gd` keeps bushes off the walls this way.

**Keep-outs** (`PropKeepOut`): `{group, radius, soft}`. There is no prop within `radius` of any node of that group, and fewer, smaller ones up to `radius * (1 + soft)`. The kit never knows the game's classes; the game puts its spawn points, buildings or markers in a group.

**Mask** (`PropMask`): a texture over an area. One channel thins props and one forbids them (above `forbid_above`).

- `density_strength` says how far the density channel thins: 1 takes the chance down to the channel's value, 0.6 thins by at most 60 %.
- `density_invert` reads the channel the other way round, so white = fewer props (rock painted white).

## 2. Batch drawing (3D)

Add a **PropBatch3D** and set **props** to the parents of the props (the PropScatter3D nodes).

- **Batches.** Every `MeshInstance3D` of every prop goes into a `MultiMeshInstance3D`, one per kind of part (mesh, material, shadow, layers, visibility range) and per `chunk_size` square, so the camera culls by square. The prop nodes stay for collision and the navmesh; only their parts are hidden. 1600 trees in the example are a few dozen draws.
- **Freeing a prop** redraws only its square, on the next frame.
- **`refresh(prop)`** after hiding a prop or moving it inside its square.
- **`rebuild_all()`** after adding props or changing what `mesh_of` answers.
- **`mesh_of`** (`func(prop, part) -> Mesh`) draws another look for the same prop, such as another biome's tree, without touching the scene.
- **Where it draws nothing:** in the editor (each prop shows itself, so you can move it), on a dedicated server or headless, and for a part with per-surface override materials, which is left as it is.

In 2D there is no batch: Godot already batches sprites.

## 3. Navmesh in zones

```
Game
├── World               # source_root: what is parsed (terrain, buildings) and where the props are
│   ├── Ground
│   └── Forest          # props in group prop_obstruction, on a collision layer the navmesh does not parse
└── Nav                 # PropNavZones3D (or PropNavZones2D): one NavigationRegion per zone, internal
```

1. Put the props in the group **`prop_obstruction`**, in the prop's own scene. Their direct, enabled collision shapes cut the navmesh:
   - in 3D: Cylinder, Capsule, Sphere, Box, ConvexPolygon and CollisionPolygon3D;
   - in 2D: Circle, Rectangle, Capsule, ConvexPolygon and CollisionPolygon2D.
2. Put the props on a **collision layer the navmesh does not parse**: take it out of the template's collision mask, and parse static colliders. Otherwise the bake pays for them twice; the inspector warns.
3. Add a **PropNavZones3D** with a `navigation_mesh` template: agent, cells, parsed geometry and collision mask. Set `source_root` and `zone_size` (a multiple of the cell size). The editor draws the zones.
4. Press **Bake** in the inspector. It saves the scene, bakes it the way the game will (in a separate headless Godot, with the project's autoloads) into a `.res` next to the scene, which is the node's `saved`, and reloads the scene. The inspector warns when the saved bake no longer matches the props or the settings. From CI or a build step:

   ```bash
   godot --headless --path . res://addons/prop_kit/tools/bake_scene.tscn -- --scene=res://maps/forest.tscn [--check]
   ```

   - Without `--check`, it bakes every zone of every zones node and saves the results. When a node had no `saved`, the scene file is updated from a fresh copy, so nothing its scripts did while baking is kept.
   - With `--check`, nothing is written. It prints each bake's content hash (two runs must print the same) and exits with 1 when a bake differs from the saved one.

In the game:

| You want to | Write |
|---|---|
| Wait until paths work | `if not nav.is_ready(): await nav.updated` |
| Free or add a prop | Nothing more: `prop.queue_free()` or `add_child(prop)`, and the zones it touches re-bake on their own (`follow_props`) |
| Tell it a prop moved | `nav.rebake_prop(prop)` |
| Tell it the ground or a building changed | `nav.rebake(position, radius)` |
| Re-bake everything | `nav.rebake_all()` |
| Know when paths see a change | `await nav.updated`, or `nav.is_updating()` |

| Signal or call | Means | Now you can |
|---|---|---|
| `updated` | The navigation map uses the latest pieces | Ask for paths and use `index`: they see every change asked for |
| `is_ready()` | The first pieces are in; it stays true | Ask for paths at all |
| `is_updating()` | A change is on its way (a bake, a result waiting, the map taking it) | Wait for `updated` if you need it |
| `stale` | The saved bake does not match the props or the settings | Nothing: every zone bakes again (`rebake_when_stale`). In the editor, press Bake |
| `bake_ready(zones)` | Apply MANUAL: a change in play is baked | Call `apply()` at the tick you choose (`has_result()`) |

- **On start** the saved bake loads with its index, and `updated` follows. When it does not match the props or the settings (the template, the zone grid, the game's `extra_fingerprint`), the node emits `stale`, bakes every zone again and never uses the stale pieces. `rebake_when_stale` off: it uses them.
- **Changes in play** re-bake only the zones they touch, on worker threads. Props alone need no parse: the parsed geometry is reused, and only the props near those zones are read (an index by zone, so the whole group is not walked). A change while a bake runs joins the next one.
- **`extra_fingerprint`** (`func() -> int`): a number from the game that changes when what the navmesh is baked from changes besides the props, such as the terrain's heights. It joins the fingerprint, so the saved bake goes stale when it differs. Set it any time: when the pieces in force are the saved bake's, they are checked again then.
- **`apply_mode` MANUAL** (Advanced, for lockstep): a change in play waits for `apply()`, so every peer swaps it in at the same tick. The kit's own bakes (the start, a stale saved bake) apply at once, so `is_ready()` never waits for the game.
- **`stats`** (PropNavStats) for logs: `parse_ms`, `obstruct_ms`, `bake_ms`, `index_ms`, `zones_baked` / `zones_total`, `obstructions`, `polygons`, `components`.

**How the zones meet.** Each zone bakes with its own filter (`filter_baking_aabb` / `baking_rect`) and a border (`zone_border`, 0 = from the agent radius), with the zone lines anchored at (0, 0). The pieces meet exactly on the zone lines and the navigation map joins them with no edge connections (`use_edge_connections` stays off, which keeps every swap cheap). A partial re-bake gives the same pieces as baking everything.

**Height (3D).** The bake measures heights in cells from each zone's floor, so the floor and ceiling of every zone are whole cells of `cell_height` from 0. A zone re-baked after the ground went lower or higher in play (a crater, a mound) still meets the zones that did not re-bake. They come from the parsed geometry with a margin. `height_range` (floor, ceiling) gives every zone the same box instead, whatever the geometry is when a zone re-bakes; nothing outside it is baked.

**Fewer polygons** (`merge_gap`):

- Props closer than the gap become one obstruction. It is a closing: each outline grows by gap / 2, the touching ones join, and they shrink back. So a passage wider than the gap stays open; set it under the agent's diameter.
- A clearing closed all around by narrower gaps is filled, because no agent could walk in or out of it. Leave an opening wider than the gap where one must exist.
- `obstruction_sides` (outline sides of a round shape) is the other knob.
- `carve` cuts exactly the outline, with no agent radius around it.

**The index** (`index`: PropNavIndex). It is built on a worker with every bake, so it is ready the moment its pieces are swapped in. It answers what the server does not:

| Query | Answer |
|---|---|
| `can_reach(a, b, max_distance)` | Can an agent walk from `a` to `b` at all. `max_distance`: points that far off the navmesh on the ground plane (a unit against a wall) count from the closest walkable point |
| `closest_point(point, max_distance, min_area)` | The nearest walkable point among those within `max_distance` of it on the ground plane, whatever the navmesh's height above the ground. With `min_area`, only on a component at least that large: the closest land, not the roof or the walled pocket a body is in |
| `component_at(point, max_distance)`, `component_area[c]` | The connected component at a point, and each one's area on the ground plane (m² in 3D, px² in 2D) |
| `polygon_at(point)` | The polygon under a point |
| `stitched(template)` | The whole navmesh as one NavigationMesh |

In 2D, the same queries end in `_2d`. `build_index` off: no index.

**2D** (`PropNavZones2D`, pixels): the walkable area is the template's outlines, or the whole zone when none are drawn; parsed colliders and the props block it. `rebake(position, radius)` takes a `Vector2`.

**When a NavigationRegion is enough.** A small level that never changes in play bakes fine with a NavigationRegion3D and its own Bake button. PropKit pays off when props change in play, when the world is big enough that a full bake is slow, or when the props should cut the navmesh from their colliders without a NavigationObstacle in each.

## In the editor

- **Scatter** and **Clear** (scatter node) can be undone: Ctrl+Z puts back the props they replaced, hand edits and all.
- **Bake** (zones node) saves the scene, bakes it the way the game will in a separate headless Godot (its autoloads and main loop run; where the scene sits in the editor plays no part), and reloads it.
- **Project > Tools**: *PropKit: Scatter the open scene* runs every scatter of the open scene, each undoable; *PropKit: Bake the open scene* is Bake for every zones node in it.
- **The 3D and 2D views** draw a scatter's ground outline (white) and a zones node's zones (blue).
- **Warnings** on a zones node: the saved bake does not match the props or the settings (press Bake); no node of the props' group under `source_root`; a prop's layer parsed as geometry; a zone size off the cell size; a cell size that is not the navigation map's.

## Multiplayer

PropKit has no network. A scatter is deterministic, so all peers that load the same scene have the same props.

When something blocks changes during a match (a prop chopped, a building up), every peer gets the change as game data, over its own transport (MpKit or anything else), and makes it: it frees the prop (the navmesh follows), or calls `rebake(position, radius)`. With `apply_mode` MANUAL, each one swaps the result in at the same tick (`bake_ready`, `apply()`). A lockstep game may also turn the navigation map's asynchronous iterations off (`navigation/world/map_use_async_iterations`); PropKit works either way.

## Godot issues it works around

- **Godot 4.7: a region's update can be lost.** With asynchronous region iterations, a navmesh set on a region while its previous iteration is still running is lost: the map keeps the old one for good. The zones node holds a new piece until the region has taken the previous one, so nothing is lost. It reproduces on its own: one region, two navmeshes set one frame apart. `test_a_saved_bake_loads_and_goes_stale` covers it.
- **2D: vertices closer than a map cell.** Godot's 2D baker can leave two vertices less than a cell apart (sub-pixel slivers where outlines meet). The map joins edges by the cells of their ends, so it finds more than two edges on one, warns "More than 2 edges tried to occupy the same map rasterization space" and leaves them unjoined. The kit welds the vertices of a baked 2D piece that share a map cell and drops the polygons that collapse. `test_a_weld_drops_what_the_map_cannot_tell_apart` and `test_grove_2d_runs` cover it.

## Measured

On a Mac, headless, with the forest example at 1365 props, 16 zones and 11 678 polygons:

| Bake | Obstructions (main thread) | Bake (workers) | Index (worker) |
|---|---|---|---|
| Every zone | 24 ms | 32 ms | 62 ms |
| Chopping a clearing (1 zone of 16) | 3.3 ms | 10 ms | 61 ms |

In a window the first bake of a scene takes longer while Godot compiles its shaders. After that, the example's 343 props bake in about 24 ms.

The zones bake in the kit's own worker tasks, not the server's asynchronous bake, so freeing the node or quitting the game in the middle of a bake waits for the workers instead of hanging.

## Tests

```bash
godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd
```

The result is `PROPKIT TESTS PASS (n)`. The tests cover:

- **the planner**: determinism, room, keep-outs, masks (thinning part way, inverted), outlines, variants and the cap;
- **the scatter**: saved children, ray ground, slopes, normals, 2D, saving a scene;
- **the command-line tools**: `scatter_scene` saves the props, `bake_scene --check` gives the same hash twice, and bakes a scene whose script uses an autoload;
- **every obstruction shape**, merging, and the fingerprint;
- **the zone grid**;
- **the 3D and 2D zones**: zones that meet, props that block, ready and updated, freed, added and moved props followed, partial = full, `follow_props` off, MANUAL apply of changes in play while the kit's own bakes apply at once, joined changes, saved and stale bakes (props, settings or the game's fingerprint), merging, a seam after the ground went lower, a fixed height range, `can_reach` near the navmesh, the closest point on the plane and past islands, the 2D weld, synchronous navigation iterations;
- **the batch**;
- **both examples, end to end.**

The editor tools have their own check, a real editor doing what a person does (Scatter, Clear, undo and redo, a hand edit undo keeps, Bake and the scene it reloads, the stale warning):

```bash
PROPKIT_EDITOR_CHECK=1 godot --headless --editor --path propkit_lab
```

It prints `EDITOR CHECK PASS`.

## Not in the kit

These are the game's:

- what a prop is (health, loot, network sync);
- the transport, and when a change in play applies (MANUAL);
- what else changed besides the props (`rebake`), and the ground's data.

Grass is a separate kit, GrassKit, planned next.
