# props/meshes
What: one `ArrayMesh` `.res` per static prop the game draws (buildings, plants, rocks), with its materials saved as references to `scenes/bodies/materials/`. The name is the one of the original's file (`cat1.res`, `CAF1.res`).
Not: the animated bodies (their scene is in `scenes/bodies/models/`) nor the hybrid bodies (`scenes/bodies/meshes/`). Nothing here reads the original at run time.
Talks to: a building part, a `VegetationSpecies`, a `ShotLook`, a map prop or a spell scene holds its mesh with `mesh = …`; `BuildingFit` and `ManafountBody` read `get_aabb()` and the first part of a building.
Edit: drag a `.res` on the `Mesh` of a part, a species or a shot look. A new prop: `tools/import/import_props.py`, then save its mesh as a `.res` here from the editor and give its surfaces the materials of `scenes/bodies/materials/`.
