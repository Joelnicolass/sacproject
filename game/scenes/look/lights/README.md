# look/lights

What: the small light that units, wizards and spells carry (`ActorLight`, no shadows, fades at 60 m + 20 m) and the budget layer (`ActorLightBudget`, `Look/Layers/ActorLights`) that turns on only the best `actor_max_lights`.
Not: the sun and the fill (Sun layer, `scenes/look/light/`) or the lights of the effects (FxLight layer, `scenes/look/fx/`).
Talks to: an `ActorLight` joins `ActorLight.GROUP`; every 0.2 s the budget ranks them by `priority / distance` (hysteresis x1.25) and calls `set_budget_on(bool)`; `CorpseLook` drives `set_lit`; `enabled` (off on units) keeps a light dark; `always_on` (the wizard reveal) skips the budget; `actor_max_lights` comes from `LookQuality` (low 4, medium 12, high 24).
Edit: `scenes/look/lights/actor_light.tscn` (range, energy, fade, specular); per owner in `unit.tscn`, `wizard_body.tscn` and the spell projectiles; `data/look/quality_*.tres` (`actor_max_lights`).
Debug: `debug/look/actor_lights_lab.tscn` (200 lights, `-- --setup=low|medium|high`).
