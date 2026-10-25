# props/meshes
What: one `ArrayMesh` `.res` per static prop the game draws (buildings, plants, rocks), with its materials saved as references to `scenes/bodies/materials/`. The name is the one of the original's file (`cat1.res`, `CAF1.res`).
Not: the animated bodies (their scene is in `scenes/bodies/models/`) nor the hybrid bodies (`scenes/bodies/meshes/`). Nothing here reads the original at run time.
Talks to: a building part, a `VegetationSpecies`, a `ShotLook`, a map prop or a spell scene holds its mesh with `mesh = …`; `BuildingFit` and `ManafountBody` read `get_aabb()` and the first part of a building.
Edit: drag a `.res` on the `Mesh` of a part, a species or a shot look. A new prop: `tools/import/import_props.py`, then `tools/bake/bake_props_055s.py --list`, `bake_props_055s.gd`, `bake_props_055s.py --apply`.
Check: rules_suite `prop_facts_cases` (`PROP FACTS props=… orphans=0`) · `tools/bake/check_props_055s.gd` (the surfaces equal what the game built before).
