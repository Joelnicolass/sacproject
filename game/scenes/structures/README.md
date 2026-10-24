# scenes/structures/

What: the building types of the map. `BuildingType` (data/buildings/<name>.tres) holds the max health, the shelter, the flattening and the ruin; the scene with the same name (scenes/structures/buildings/<name>.tscn) is the building you drag into a map: a `MapBuilding` whose parts (BodyVisual, VegetationClear) are saved children of `Visuals` and whose `Collision` is the BoxShape3D that holds the parts (the body at play is that box minus an inset).
Not: health and ruin at play time (MapBuilding, scenes/map/map_building.gd); casting structures (StructureBody, StructureSpawner).
Talks to: maps instance the building scenes; ManafountBody takes its model from `BuildingType.base_model()`; code that spawns by type (debug, tools) uses `BuildingType.scene()`; GameCatalog and TypeRef find a type by `tag`.
Edit: open the building scene, move the parts with the gizmo, drag the handles of `Collision` or press «Ajustar a las partes» on the root. A new building: duplicate a .tres and its scene. In a map, «Hijos editables» shows the parts of one instance.
Debug: debug/map/building_gallery.tscn (F6): the 82 types the maps use, with their name and role.

---
Estructuras: tipos, cuerpo, spawner e inspector. Las pruebas de este dominio van en `debug/suite/`.
