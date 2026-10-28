# structures

Building types. `BuildingType` (`data/buildings/<name>.tres`) holds the role, health, shelter and ruin; the scene with
the same name in `buildings/` is the `MapBuilding` you drag into a map, with its parts under `Visuals` and a `Collision` box.
Edit a building in its scene: change part meshes, move parts with the gizmo, or press «Ajustar a las partes» on the root.
Cast towers are in `towers/`; what happens when a building falls is in `breaking/`.
