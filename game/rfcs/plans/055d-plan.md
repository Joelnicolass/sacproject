# 055d: el mapa como nodos del editor + terreno con un dueño (055d-t). Plan aprobado 2026-10-23

Aprobado por el usuario con P1 (flora pintable como **nodo** `FloraLayer`; se corrige el ejemplo de CONVENTIONS §4), P2 (los árboles del original siguen como `MapBuilding`; `BiomeProp` es para RFC-059), P3 (renombrar `Bld008_car1` → nombres humanos, en commit aparte), P4 (mostrar `ruin_scene` al caer), P5 (los 114 sin uso como `<dios>_<tag>`), P6 (botón «Hornear navmesh» por subproceso), P7 (rayos detrás de `GroundRay`, sin cambiar comportamiento), P8 (sin variante de bioma por edificio).
**Agregado del usuario:** poder previsualizar en el editor **cualquier mapa con cualquier dios**: escena `debug/look/look_preview.tscn` con `@export var map: MapDefinition` (lista de mapas) y `@export var god: GodType`, que instancia el `map.tscn` elegido y le aplica `god.look` en vivo (`@tool`; cambiar cualquiera de los dos recarga). Va en d4.

## Hoy (medido sobre b30367de)
- Edificios (424 en 5 mapas) ya son `MapBuilding`, pero dentro de `maps/<m>/layout.tscn` instanciado como `*Layout` sin hijos editables; partes armadas en `_ready` desde `BuildingType.components: Array[Dictionary]` con caché estático `bldg()`.
- NPC (118): `NpcSpawn` en `layout.tscn/NpcSpawns` → `MapPopulation` (servidor).
- Flora: `FloraField` → `MeshPlanter` (hilos) desde `flora.res` (`FloraMap`: bytes 320², horneado de `widgets.json`).
- Props/arcos/pilares: no existen.
- Terreno: 5 representaciones sin dueño (`MapTerrainData`, `terrain.glb`, trimesh, índice de `terrain.gd`, `nav.res`). 42 lecturas de altura en 24 archivos: 15 leen datos, **27 son rayos de física** que también pegan en techos.
- Mover un edificio: 7 archivos (2 editados, 2 horneados por CLI, 3 leídos).

## Árbol
```
Map : MapRoot                     map_root.gd [~] ≤60  sockets tipados: terrain, nav_region, starts, look, minimap_bake, buildings, npcs, props, vegetation
├── Look : LookRig                (055b) + Layers/Props : PropLayer [+]
├── Terrain : Terrain             terrain.gd [~] 462→≤150: malla y vista previa
│   ├── Shape : TerrainShape      terrain/terrain_shape.gd [+] ≤150 ÚNICO dueño de alturas, agujeros, celdas, tiles, sampler()
│   ├── Collision (StaticBody3D)
│   └── Missing (Label3D)
├── MapProps/Starts, Founts       (igual; Manafount toma el modelo de BuildingType.scene)
├── Buildings/                    [~] sacados de layout.tscn; map_building.tscn con building = <name>.tres
│   └── JamesHut008 : MapBuilding map_building.gd [~] 238→≤140 (Visuals = instancia de BuildingType.scene, nunca se guarda)
├── Npcs/                         [~] NpcSpawn + visual de la criatura solo en el editor
├── Props/                        [+] BiomeProp (map/props/biome_prop.gd/.tscn ~100): gris en el editor, modelo del dios en el juego
├── Vegetation/                   [+] FloraLayer (look/vegetation/flora_layer.gd ~60, PNG de densidad) · VegetationPatch (~120: especie, radio, cantidad, seed)
├── NavRegion : MapNavRegion      [~] @export_tool_button «Hornear navmesh» (subproceso bake_nav.tscn)
└── MinimapBake
```
Nuevos: `terrain_rules.gd` (estático, seguro en hilos), `ground_ray.gd` (una copia de los rayos), `terrain_ground_material.gd`, `scenes/structures/building_footprint.gd`, `prop_kind.gd`, `look/props/prop_set.gd` + `prop_layer.gd`.
Hablan: `MatchWorld._bind_map` → `Nav.terrain_shape = map.terrain.shape`, `Population.buildings_root = map.buildings`; `PropLayer.apply_look(profile)` → `BiomeProp.show_model(...)`; `FloraLayer/VegetationPatch.changed` → `FloraField`; `MapBuilding.destroyed` → `NavService`; `TerrainShape.changed(rect)` declarado para RFC-057.

## BuildingType
`display_name`, `max_health` (0 = indestructible), `shelters_peasants`, `flattens_ground`, `scene: PackedScene` (partes `BodyVisual` + `Footprint` + `VegetationClear`), `ruin_scene`, `tag` (solo lectura). La escena no apunta al tipo (sin ciclo). Migración `tools/migrate/d1_buildings.gd` en 2 commits (forma con snapshot que aborta si difiere; nombres → `data/buildings/<name>.tres`, nombres humanos para los 82 usados desde `d1_building_names.csv`). Checklist de 82 filas desde `055R-original-reference §2` (Shrine sin hechizo → 055e/RFC-056).

## Flora
`FloraLayer : Node3D` (`species`, `density` PNG L8 320², `cell_m` 8, `max_per_cell`) y `VegetationPatch : Node3D @tool` (MultiMesh interno, respeta `VegetationClear`, preset y switch). Migración única `d3_flora_png.gd`: ubicación **idéntica** (se conserva el tag en la especie); lo verifica `flora_cases`. Cada edificio trae su `VegetationClear`: mover la casa mueve el claro. `MeshPlanter` y sus hilos iguales; presupuesto ≤1,0 ms medido en `flora_lab`.

## TerrainShape (055d-t)
API: `height_at`, `is_on_ground`, `lowest`, `cell_counts`, `tile_ids`, `sampler`, `is_loaded`, `static of(node)`; `signal changed(rect)`. Los 15 de datos pasan a `TerrainShape`; los 27 de rayo a `GroundRay.surface_y(...)` con su fallo propio. 48 archivos fuera de `scenes/` se reescriben en el mismo commit; no queda API de compatibilidad. RFC-057: Δh 256² dentro de `TerrainShape` + `apply_stamp()`; RFC-059: `data` desde cualquier importador.

## Se borra
`BuildingType.flags/folder/components/tileset/to_record()`, `MapBuilding.bldg()` y cachés; `maps/*/layout.tscn` ×5 y `MapDefinition.layout_scene_path/ntts_path/widgets_path`; `FloraMap`, `maps/*/flora.res`, `DensitySource.MAP_*`, `model_substitutes`, `trees.tres`, `flora_map_cases.gd`; `Terrain.ground_height/height_in/triangle_in/height_sampler/ground_cell_counts`; `tools/bake/bake_map_layout.gd`, `migrate_layout_043.*`, `bake_flora_map.gd`, `flora_map_builder.gd`, `plant_clears.gd`, `tools/audit/check_layout_transforms.*`; congelar `import_terrain.gd`, `terrain_glb_export.gd` en `tools/import/legacy/`; `tools/migrate/d1*–d3*` al cerrar.

## Recorridos
Mover un edificio: 7 → 2 (gizmo + botón). Grupo de árboles: imposible → 1 nodo. Arco: → 1 nodo (+ modelo por dios una vez en `data/look/props/<god>_props.tres`).

## MP y determinismo
Sim: `MapBuilding`, `NpcSpawn`, nav, `TerrainShape`, colisión, `GroundRay`, `BiomeProp` solo con `blocks_radius_m > 0`. Presentación: partes, ruinas, modelo de props, flora. Ningún digest de `quick`/`all` debe cambiar; la ruta de `Sync` pasa de `Map/PeaksLayout/Buildings/X` a `Map/Buildings/X`: correr `run_net_quick.sh`.

## Sub-cortes (un developer)
| Día | Corte | Entrega |
|---|---|---|
| ½ | d0 | `debug/map/building_gallery.tscn`, checklist de 82 filas, `d1_building_names.csv` |
| 1 | d-t1 | `TerrainShape`, `TerrainRules`, `terrain_ground_material`, `terrain.gd` ≤150; los 15 de datos + debug/agent/tools; `debug/map/terrain_shape.tscn` PASS; quick sin cambio |
| 2 | d-t2 | `GroundRay` (27), `GrassLabGround` con shape, sin `.call`; quick sin cambio |
| 3–4 | d1 | `BuildingType`, `BuildingFootprint`, migración en 2 commits, `MapBuilding` ≤140; quick sin cambio |
| 5 | d2 | aplanar layouts ×5, `MapRoot`/`MatchWorld`, botón navmesh, `NpcSpawn` visual, borrar layouts y tools; quick, all, `run_net_quick` (espera a 055b-3 en main) |
| 6–7 | d3 | `FloraLayer`, PNG, especies, `VegetationPatch`, claros, borrar `FloraMap`; `flora_cases`, `flora_lab`, `debug/map/vegetation_patch.tscn` |
| 8–9 | d4 | `PropKind`, `PropSet`, `PropLayer`, `LookProfile.props`, `BiomeProp`, `debug/map/biome_props.tscn`, **`debug/look/look_preview.tscn` (cualquier mapa × cualquier dios)**; READMEs; baseline; review; playtest con ventana |

Lint esperado: C1a 109→107, C1b 25→24, C5 223→221, C6 64→63, C7 70→61, C8 27→24, C9 370→~360, C13 40→36, C14 227→220.
