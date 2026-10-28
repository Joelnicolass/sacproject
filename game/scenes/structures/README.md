# scenes/structures/

What: the building types of the map. `BuildingType` (data/buildings/<name>.tres) holds the role (scenery, Manalith, Shrine), the max health, the shelter, the flattening and the ruin; the scene with the same name (scenes/structures/buildings/<name>.tscn) is the building you drag into a map: a `MapBuilding` whose parts (a `MeshInstance3D` with its mesh from scenes/props/meshes/, VegetationClear) are saved children of `Visuals` and whose `Collision` is the BoxShape3D that holds the parts (the body at play is that box minus an inset). A building that flattens the ground (`flattens_ground`: trees, rocks, huts of the original) has no box body; a tree's `Trunk` (a CylinderShape3D child, set as `trunk`) still stops creatures and wizards, on the dedicated server too, and enters the navmesh.
Not: health at play time (MapBuilding, scenes/map/map_building.gd); what happens when one falls (breaking/: StructureBreak, BuildingRuin). The towers a wizard casts (Manalith, Shrine) live in towers/.
Talks to: maps instance the building scenes; ManafountBody takes its mesh from `BuildingType.base_mesh()`; code that spawns by type (debug, tools) uses `BuildingType.scene()`; GameCatalog and TypeRef find a type by `tag`.
Edit: open the building scene, drop another `scenes/props/meshes/<tag>.res` on a part's `Mesh`, move the parts with the gizmo, drag the handles of `Collision` or press «Ajustar a las partes» on the root; on a tree, drag the radius of `Trunk` to the trunk (then «Hornear navmesh» on the maps that use it). A new building: duplicate a .tres and its scene. In a map, «Hijos editables» shows the parts of one instance.

---
Estructuras: tipos, torres, spawner e inspector.
