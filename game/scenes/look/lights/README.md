# look/lights

The small lights carried by units, wizards and spells (`ActorLight`, no shadows), the glow of a lasting spell
(`StateLight`), and the budget (`ActorLightBudget`) that turns on only the best `actor_max_lights` of the quality preset.
A spell's glow is a `state_light.tscn` inside the spell's own scene; a burst's flash is an `FxLightSpec` on its `ParticleType`.
