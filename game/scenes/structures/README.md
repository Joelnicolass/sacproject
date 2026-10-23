# scenes/structures/

What: the building types of the map. `BuildingType` (data/buildings/<name>.tres) names the scene of parts (scenes/structures/buildings/<name>.tscn: BodyVisual parts, a `BuildingFootprint` box and a `VegetationClear`), the max health, the shelter and the ruin.
Not: placing a building or its health (MapBuilding, scenes/map/map_building.gd); casting structures (StructureBody, StructureSpawner).
Talks to: MapBuilding instances `BuildingType.scene` as an unsaved child and reads the Footprint for its body; ManafountBody takes its model from `BuildingType.base_model()`; GameCatalog and TypeRef find a type by `tag`.
Edit: open the type's scene, move the parts with the gizmo and press «Ajustar a las partes» on Footprint. A new building: duplicate a .tres and its scene.
Debug: debug/map/building_gallery.tscn (F6): the 82 types the maps use, with their name and role.

---
Estructuras: tipos, cuerpo, spawner e inspector. Las pruebas de este dominio van en `debug/suite/`.
