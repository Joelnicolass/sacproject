# units/afflictions

States that change what a body can do (stunned, frozen, vined, petrified, slimed…). `Afflictions` owns the questions and
the replicated mask; each `Affliction` child is one state, laid with `Affliction.lay(spell, slot)`.
`afflictions.tscn` is instanced in both `unit.tscn` and `wizard_body.tscn` with editable children: the wizard's
differences and the creature-only states are set on those instances.
