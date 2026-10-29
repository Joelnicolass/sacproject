# structures/towers

The towers a wizard casts over a free manafount: Manaliths (`tower.tscn`) and Shrines (`shrine_tower.tscn`). Each is a
`CastTower` (a `MapBuilding`) with `HealthRegen`, a `ManaSource` and a `GuardPost`. While it rises it takes no damage,
gives no mana and has no collision. A new god's tower: a building scene instancing one of these, a `GodStructure` row on
the god, and an entry in `StructureSpawner.scenes`.
