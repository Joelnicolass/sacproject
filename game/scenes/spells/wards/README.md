# spells/wards

A body's shields and temporary forms. `Wards` (one per body) owns what protects it now; each `Ward` child is one of them
(Life Shield, Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective Swarm, Healing Aura). `Health` asks
`Wards.factor()` / `immune()`, `Afflictions` asks `shielded()`.
New ward: a scene, a child of `Wards` in `wizard_body.tscn`, its `shown` in the replicated properties, and a spell with
`ward_action.tscn`.
