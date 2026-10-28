# spells

Casting. `Spellbook` (what the wizard knows, cooldowns) and `Caster` (mana, target, range, timing) are children of the
wizard; each spell is a `SpellAction` scene in `actions/`, named by `SpellType.action` (`data/catalog/spells/<tag>.tres`).
- A client calls `Caster.request_*`, which becomes a `submit_*` RPC; the server (or solo) casts.
- The action spawns what the spell needs through `SpellSpawner`. A new kind of projectile or zone is a scene added to the
  spawner's `projectiles` / `zones` in `match.tscn`, not a preload (it would make the type, the action and the spawner
  load each other in a circle).
- Projectiles and spell effects use `MpReplicate`, not a buffered `MpActor`: they live briefly and a buffered pose would
  draw the impact late.
- Subfolders hold the families: `zones/`, `drops/`, `walls/`, `wards/`, `carrier/`, `chain/`, `effects/`, `stalks/`, `tornado/`.
