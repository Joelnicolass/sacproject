# units

Every creature on the map: `unit.tscn`, a thin `UnitBody` with one child per responsibility and one `UnitState` per mode
under `States` (an `FsmMachine`). `UnitSpawner` sets its `CreatureType` (`creatures/<name>/<name>.tres`; the creature's own files live in that folder) before it
enters the tree.
- The body runs its physics step in a fixed order (`Locomotion.begin` → `Regeneration.age` → current state →
  `Regeneration.step` → `Locomotion.finish`); none of those nodes processes by itself.
- `UnitBody.mode` is the only writer of the mode; `BodyCollider` the only writer of the capsule.
- The server owns the creature: `MpActor` sends the pose and the properties in its `sync_extra`, and on a client only
  `MpActor` writes the position. After editing `sync_extra`, save the scene so `MpSync` is rebuilt.
- Weapons, abilities, passives and afflictions are children; each subfolder has the details.
