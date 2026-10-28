# spells

Casting. `Spellbook` (what the wizard knows, cooldowns) and `Caster` (mana, target, range, timing) are children of the
wizard; each spell is a `SpellAction` scene in `actions/`, named by `SpellType.action` (`data/catalog/spells/<tag>.tres`).
- A client calls `Caster.request_*`, which becomes a `submit_*` RPC; the server (or solo) casts.
- The action spawns what the spell needs through `SpellSpawner`. A projectile is dragged into the action's `projectile`
  (a `PackedScene`); a zone or wall scene is listed in the spawner's `zones` in `match.tscn` (a zone points at its
  `SpellType`, so the action cannot point back at it without a load cycle).
- Projectiles and spell effects use `MpReplicate`, not a buffered `MpActor`: they live briefly and a buffered pose would
  draw the impact late.
- Subfolders hold the families: `zones/`, `drops/`, `walls/`, `wards/`, `carrier/`, `chain/`, `effects/`, `stalks/`, `tornado/`.
