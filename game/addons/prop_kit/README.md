# PropKit

Props for 2D and 3D worlds, in three independent pieces:

1. **Scatter.** Plants props over any ground as saved, editable nodes: clusters from a noise, keep-outs around the game's own nodes, a painted mask, weighted variants.
2. **Batch drawing (3D).** Draws thousands of them in a few draw calls.
3. **Navmesh in zones.** Bakes the navmesh in square zones with the props as cheap projected obstructions, so a change re-bakes only the zones it touches, on worker threads.

There is no network, no game rule and no autoload, and PropKit depends on no other kit. Each piece works without the others.

```bash
./install.sh --addon /path/to/godot-project prop_kit
```

Enable the **PropKit** plugin. It adds Project > Tools > *PropKit: Scatter the open scene*, which runs every scatter of the open scene. The kit's nodes work without the plugin too.

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
3. Set **ground** (see below).
4. Add **variants**: a `PropVariant` per scene, each with a weight.
5. Press **Scatter** in the inspector. **Clear** removes the props.

The same rules and seed always give the same props. Scattering again replaces every child of the node.

The props are ordinary children owned by the scene, so they are saved and you can edit them with the gizmo. From code: `scatter.scatter(scene_owner)`. From a build step or CI:

```bash
godot --headless --path . --script res://addons/prop_kit/tools/scatter_scene.gd -- --scene=res://maps/forest.tscn
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
2. Put the props on a **collision layer the navmesh does not parse**: take it out of the template's collision mask, and parse static colliders. Otherwise the bake pays for them twice, and the kit warns once.
3. Add a **PropNavZones3D** with a `navigation_mesh` template: agent, cells, parsed geometry and collision mask. Set `source_root` and `zone_size` (a multiple of the cell size).
4. Press **Bake** in the inspector. It bakes every zone and saves them next to the scene in a `.res`, which is the node's `saved`. From CI or a build step:

   ```bash
   godot --headless --path . --script res://addons/prop_kit/tools/bake_scene.gd -- --scene=res://maps/forest.tscn [--check]
   ```

   - Without `--check`, it bakes every zone of every zones node and saves the results. When a node had no `saved`, the scene file is updated from a fresh copy, so nothing its scripts did while baking is kept.
   - With `--check`, nothing is written. It prints each bake's content hash (two runs must print the same) and exits with 1 when a bake differs from the saved one.

In the game:

- **On start** the saved bake loads at once. If the props differ from the saved ones (for example, a match played without its forest), it emits `stale` and bakes every zone again on worker threads. `rebake_when_stale` off: only `stale`.
- **`extra_fingerprint`** (`func() -> int`, set in the game's `_ready`): a number from the game that changes when what the navmesh is baked from changes besides the props, such as the terrain's heights. It joins the props' fingerprint, so the saved bake goes stale when either changes.
- **`rebake(areas, reparse)`** after something that blocks changed there. Areas are Rect2 on the ground plane. `PropObstructions.area_of(prop, true)` gives a prop's area, so read it before freeing the prop. `reparse = false` when only props changed: the parsed geometry is reused and only the obstructions near the touched zones are read (an index by zone, so the whole group is not walked).
- **Requests while a bake runs** wait and are joined into the next one.
- **`apply_mode` MANUAL**: the result waits (`bake_ready`, `has_result()`) for `apply()`. A lockstep game swaps it in at a tick it chooses; `is_done()` says without blocking whether it can. Pieces always go in in zone order, so the result depends only on the inputs, never on which zone finished first.
- **`applied`** says the regions have the new pieces. **`synced`** (`is_synced()`) says the navigation map uses them: paths and server queries see them a few physics frames after `applied`.
- **`stats`** (PropNavStats) for logs: `parse_ms`, `obstruct_ms`, `bake_ms`, `index_ms`, `zones_baked` / `zones_total`, `obstructions`, `polygons`, `components`.

**How the zones meet.** Each zone bakes with its own filter (`filter_baking_aabb` / `baking_rect`) and a border (`zone_border`, 0 = from the agent radius), with the zone lines anchored at (0, 0). The pieces meet exactly on the zone lines and the navigation map joins them with no edge connections (`use_edge_connections` stays off, which keeps every swap cheap). A partial re-bake gives the same pieces as baking everything.

**Fewer polygons** (`merge_gap`):

- Props closer than the gap become one obstruction. It is a closing: each outline grows by gap / 2, the touching ones join, and they shrink back. So a passage wider than the gap stays open; set it under the agent's diameter.
- A clearing closed all around by narrower gaps is filled, because no agent could walk in or out of it. Leave an opening wider than the gap where one must exist.
- `obstruction_sides` (outline sides of a round shape) is the other knob.
- `carve` cuts exactly the outline, with no agent radius around it.

**The index** (`index`: PropNavIndex). It is built on a worker with every bake, so it is ready the moment its pieces are swapped in. It answers what the server does not:

| Query | Answer |
|---|---|
| `component_at(point)`, `same_component(a, b)` | Can an agent get from here to there at all |
| `polygon_at(point)` | The polygon under a point |
| `closest_point(point)` | The closest walkable point |
| `stitched(template)` | The whole navmesh as one NavigationMesh |

In 2D, the same queries end in `_2d`. `build_index` off: no index.

**2D** (`PropNavZones2D`, pixels): the walkable area is the template's outlines, or the whole zone when none are drawn; parsed colliders and the props block it.

## Multiplayer

PropKit has no network. A scatter is deterministic, so all peers that load the same scene have the same props.

When something blocks changes during a match (a prop chopped, a building up), every peer gets the change as game data, over its own transport (MpKit or anything else). Then each one calls `rebake(areas, false)`. With `apply_mode` MANUAL, each one swaps the result in at the same tick.

## Godot issues it works around

- **Godot 4.7: a region's update can be lost.** With asynchronous region iterations, a navmesh set on a region while its previous iteration is still running is lost: the map keeps the old one for good. The zones node holds a new piece until the region has taken the previous one, so nothing is lost. It reproduces on its own: one region, two navmeshes set one frame apart. `test_a_saved_bake_loads_and_goes_stale` covers it.
- **2D: a harmless warning.** Godot's 2D baker can leave sub-pixel slivers around round outlines, and the map then warns "More than 2 edges tried to occupy the same map rasterization space". It happens inside a single piece, not on the zone lines. Paths are not affected.

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
- **the command-line tools**: `scatter_scene` saves the props, `bake_scene --check` gives the same hash twice;
- **every obstruction shape**, merging, and the fingerprint;
- **the zone grid**;
- **the 3D and 2D zones**: zones that meet, props that block, partial = full, added props, MANUAL apply, joined requests, saved and stale bakes (props or the game's fingerprint), merging, components;
- **the batch**;
- **both examples, end to end.**

## Not in the kit

These are the game's:

- what a prop is (health, loot, network sync);
- when to rebake;
- the transport;
- the ground's data.

Grass is a separate kit, GrassKit, planned after PropKit 0.1.
