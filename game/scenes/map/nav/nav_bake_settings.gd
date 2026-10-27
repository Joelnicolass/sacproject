@tool
class_name NavBakeSettings
extends Resource

## The numbers of the map's navmesh bake (RFC-035 035f): data/nav/nav_bake.tres is their only source. tools/bake/bake_nav.gd and
## MapNavRegion read them; nothing else hardcodes a radius or a cell. Never mutated at runtime.

## Voxel size of the bake (m). The RFC asks 0.5; 1.0 keeps the headless bake of the 2.56 km map light (RFC-035 R12 note).
@export var cell_size := 1.0
@export var cell_height := 0.25
## The common body radius (0.5 m) plus the NavService box clearance (0.5 m), RFC-035 R7.
@export var agent_radius := 1.0
@export var agent_height := 2.0
## Recast drops a span whose neighbour is more than this below (a «ledge») and does not step over more than this. The grid takes the
## land as flat, so the navmesh must too: at 1 m cells a slope of 70 degrees rises 2.7 m per cell. 0.5 m (the step of move_and_slide)
## cut the hills into 30 islands (F201); 3 m keeps them one piece, bodies walk those slopes (floor_max_angle 85).
@export var agent_max_climb := 3.0
## Degrees. High on purpose: every ground triangle of Terrain.is_on_ground must be walkable (floor_max_angle is 85).
@export_range(0.0, 90.0) var agent_max_slope := 85.0
@export var region_min_size := 8.0
@export var region_merge_size := 20.0
## The most voxel columns one bake may have. Godot's Recast crashes the process (signal 11) past about 26 M (a «Mapa nuevo» flat
## map is land over its whole 2.55 km: 26 M at 0.5 m) and only warns at 30 M; 13 M bakes in 7 s. A bigger source bakes at a
## coarser cell (`fit_to`), so every map can be baked; the maps of the original stay far below and keep `cell_size`.
@export var max_grid_cells := 16000000
## The scene that bakes (a tool, left out of the exported game): MapNavRegion's «Hornear navmesh» button runs it. Not a bake number.
@export var bake_tool := ""


## Copies the numbers into `navmesh` and fixes the geometry source: static colliders of the `nav_source` group and its children.
func apply_to(navmesh: NavigationMesh) -> void:
	navmesh.cell_size = cell_size
	navmesh.cell_height = cell_height
	navmesh.agent_radius = agent_radius
	navmesh.agent_height = agent_height
	navmesh.agent_max_climb = agent_max_climb
	navmesh.agent_max_slope = agent_max_slope
	navmesh.region_min_size = region_min_size
	navmesh.region_merge_size = region_merge_size
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	navmesh.geometry_source_group_name = NavFingerprint.GROUP


## After the parse: when `geometry` spans more than `max_grid_cells` columns at `cell_size`, `navmesh` bakes at the finest
## coarser cell that fits and still holds `agent_radius` in whole cells (Recast rounds the radius up to cells). The game's map
## takes the cell of the navmesh (NavMeshBackend), so the stored bake and a re-bake agree.
func fit_to(navmesh: NavigationMesh, geometry: NavigationMeshSourceGeometryData3D) -> void:
	var size := geometry.get_bounds().size
	if size.x * size.z <= max_grid_cells * cell_size * cell_size:
		return
	var needed := sqrt(size.x * size.z / max_grid_cells)
	var cells_per_radius := floorf(agent_radius / needed)
	var cell := agent_radius / cells_per_radius if cells_per_radius >= 1.0 else ceilf(needed / agent_radius) * agent_radius
	navmesh.cell_size = maxf(cell, cell_size)


## Every number that changes the bake, as text, for the source hash.
func fingerprint() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [cell_size, cell_height, agent_radius, agent_height, agent_max_climb,
		agent_max_slope, region_min_size, region_merge_size]
