# structures/breaking
What: what a building does when it falls, on every peer: `StructureBreak` bursts each part of `Visuals` (`building_break.tscn`, the Explosion blast with 35 rocks and no scar, plus `bursts` explosion_blast/explosion_blast2) and `BuildingRuin` hides `Visuals` and adds `BuildingType.ruin_scene` as a normal child. Both are children of `map_building.tscn`, so every building and tower has them.
Not: the fall itself (MapBuilding owns «fallen»: collision, groups, shelter; CastTower frees the fount and lingers `linger_s`), damage (Health), the cut of a rising tower (065 BuildCues).
Talks to: `Health:current` (replicated, spawn=true) -> `MapBuilding.damaged(fraction_left)` on every hit and `MapBuilding.destroyed` once, on every peer -> each child that listens. Local FxBus.play_scene / play only: 0 RPC; headless only emits `played` and `broke`. A peer that joins with the building already down sees the ruin and no burst (`arm_after_s`).
Edit: force, rocks and shake in the root of `building_break.tscn` (`pieces`, radii, `camera_trauma` 0.35); the sprites in data/fx/explosion_blast*.tres; one part's burst point = drop a `Marker3D` in that part and drag it; another fall for one building = duplicate `building_break.tscn` and set it as `StructureBreak.scene` in that building's scene.

---
Add a behaviour (sound when hurt, smoke, fire, a rule): a new child node in `map_building.tscn` (all buildings) or in one building's scene, with `@export var building: MapBuilding` assigned to the root, connecting in `_ready`:

```gdscript
@export var building: MapBuilding

func _ready() -> void:
	building.damaged.connect(_on_damaged)      # fraction_left 0..1, every hit, every peer
	building.destroyed.connect(_on_destroyed)  # once, every peer; collision and groups already off
```

No code of MapBuilding changes; take the node out and the behaviour is gone. `StructureBreak` and `BuildingRuin` are written this way.
