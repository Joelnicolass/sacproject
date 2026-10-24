# spells/animate_dead
What: what everybody sees while Animate Dead brings a creature back: `AnimateDeadFx` (a violet burst over the creature, and a stream every other tick one time in two) and `StreamerFx` (one comet from the wizard to the creature, a ribbon on a curve).
Not: the revival (`FastRevive` with the slow knobs, `scenes/units/abilities/revive_slow.tscn`), the casting (`AnimateDeadAction`), the soul (`Soul`).
Talks to: `AnimateDeadAction.started` starts the revival on the creature and asks `SpellSpawner` for an `AnimateDead` effect (every peer gets it); the effect finds the wizard and the creature by path and frees itself when the revival ends.
Edit: `animate_dead_fx.tscn` (stream rate, the burst emitter) · `streamer_fx.tscn` (arc, length of the comet, `travel_s`) · `data/fx/animate_dead_burst.tres` (sparks) · `data/fx/beams/animate_dead_streamer.tres` (strip, width, brightness).
Check: `debug/spells/cast_souls.tscn` (F6, Animate Dead on the dead Trogg) · rules_suite `animate_dead_cases` · `match_shots --cast=deda`.
