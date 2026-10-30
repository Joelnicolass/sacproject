# bodies

The size, sockets and models of every creature and wizard body.
- A body wears a `BodyFrame` scene (`units/bodies/<name>.tscn`, `wizards/bodies/<name>.tscn`): capsule, footprint and
  `Sockets/` markers, edited with the gizmo. `BodyFacts` reads them for melee, avoidance and spells.
- The model is `models/<name>_model.tscn` with its clip library (`<name>_model_clips.tres`: one Animation per role, with
  the `hit`/`shoot` markers). Only clients build the look; the rules read clip lengths through `ClipFacts`, never play a clip.
- A new model: `tools/bake/new_creature.gd` (or Project > Tools > Sacrifice). Ragdolls: `tools/bake/bake_ragdolls.gd`.
