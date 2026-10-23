# look/lights

What: the lights that units, wizards and spells carry (`ActorLight`) and the budget that decides which of them are on (`ActorLightBudget`). Empty until RFC-055 055b-3.
Not: the sun and the fill (Sun layer, `scenes/look/light/`) or the lights of the effects (FxLight layer, `scenes/look/fx/`).
Talks to: an `ActorLight` joins the budget's group; the budget turns the best N on with `set_budget_on(bool)`; `actor_max_lights` comes from `LookQuality`.
Edit: `scenes/look/lights/actor_light.tscn` (range, energy, fade) and `data/look/quality_*.tres` (`actor_max_lights`).
Debug: `debug/look/actor_lights_lab.tscn` (055b-3).
