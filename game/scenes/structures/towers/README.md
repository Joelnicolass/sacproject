# structures/towers
What: the ten towers a wizard casts over a free manafount: five Manaliths (`tower.tscn`) and five Shrines (`shrine_tower.tscn`, which adds a RitualSite). Each is a `CastTower` (a MapBuilding): 5000 health, `HealthRegen` (full in 60 s), a `ManaSource` of 50 m (Manalith 33.3/s, Shrine 8.33/s, for the side and its allies), a `GuardPost` with its `AttachPoint`.
Not: who may cast one or where (StructureAction, TowerRules), how it reaches the other peers (StructureSpawner).
Talks to: StructureAction -> StructureSpawner.spawn_tower -> every peer instances the scene; CastTower takes the fount on enter and frees it on exit; `Health.died` frees it on the server.
Edit: open `tower.tscn` / `shrine_tower.tscn` (rate, sphere `Reach`, `AttachPoint`, `HealthRegen.refill_s`); the model and box live in `buildings/_<tag>.tscn`; role and name in `data/buildings/_<tag>.tres`. A new god's tower: a building scene instancing one of them, a `GodStructure` row, and an entry in `StructureSpawner.scenes`.
Check: rules_suite `tower_cases` (agent/harness/godot_run.sh ... debug/suite/rules_suite.tscn) · any `buildings/_*.tscn` open in the editor shows the 50 m sphere.
