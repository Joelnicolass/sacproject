# units/vision
What: a body sees who stands inside its `Vision` (a cylinder, or a sphere, with an optional cone) and its side keeps in mind the foes it saw for `forget_s`; the sight of a side is the union of its bodies' Visions.
Not: who to attack (`TargetPicker`, `Engagement`), what the AI knows (`AiPerception` asks `VisionSides`), terrain fog (the port has none).
Talks to: `Vision.seen` / `lost` report in name order; `UnitBody`, `WizardBody` and the Divine Sight eye each own one (`vision`) and give it the range of their type (`adopt_range`); `TargetPicker` and `AiPerception` ask `VisionSides.sees(side, node)` / `seen_by(side)`; `VisionSides.reveal(attacker, victim)` makes the victim's side see the attacker and fires `Vision.hurt_by` on the victim.
Edit: `unit.tscn` / `wizard_body.tscn` → `Vision` (drag the `Shape` handle, or set `radius_m`, `fov_deg`, `spherical`, `forget_s`, `refresh_s`) · `data/catalog/creatures/<name>.tres` `vision_m` · `data/catalog/wizards/<name>.tres` `vision_m`.
Check: `debug/units/vision_range.tscn` (F6) · `debug/units/vision_perf.tscn` (150 bodies) · rules_suite `vision_rules`, `vision_range`.
---
Everything is ordered by node name (then path), never by the order physics or groups list things, so two runs and two peers agree. `use_area` lets the physics area narrow the candidates (bodies on its collision mask) and gives the same answer as walking the groups; it is off by default. Mana founts have no body, so they are always found by walking their group.
