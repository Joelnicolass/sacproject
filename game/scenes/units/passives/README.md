# units/passives

What a creature has all the time. `unit.tscn` carries every passive node (`FireShield`, `LightningCharge`, `DamagePassive`,
`ManaSupport`…); each asks `CreatureType.has_passive()` and the ones that do not match sleep. Add one: a `.tres` in
`data/passives/` dragged to the creature's `on_damage` or `passives`.
