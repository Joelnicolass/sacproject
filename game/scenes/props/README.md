# props
What: decoration scenes (arch, rock, pillar, ruin) you drag into a map's `Props` node; they show their real model in the editor and move with the gizmo.
Not: anything with health, a shelter or a sim role (that is a `MapBuilding`, `scenes/structures/buildings/`); no registry or resolver: the map instances the scene directly.
Talks to: nothing in the sim. `VegetationClear` clears grass and plants around it; the optional `StaticBody3D` collision is for physics only (the baked navmesh does not know it).
Edit: copy `persephone_arch.tscn`, change `model` on `Mesh` (BodyVisual), keep or delete `Collision` (box of the model, drag its handles) and `VegetationClear` (radius_m). Drag the scene under `Props`.
Debug: `debug/map/props_gallery.tscn` (F6) shows every scene in this folder side by side.
Known debt: a prop that must block units or have health is a building: do not add collision here for pathing (059e: per-god swap for neutral maps).

---
Template (5 lines): root `Node3D` (or `StaticBody3D` with layer 1 / mask 0 if it has `Collision`) · child `Mesh` = `MeshInstance3D` with `body_visual.gd` (`model`, `stand_on_feet` off) · optional `CollisionShape3D` sized to the model · optional `VegetationClear` · no script.
