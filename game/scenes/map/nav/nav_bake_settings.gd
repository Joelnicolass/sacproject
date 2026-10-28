@tool
class_name NavBakeSettings
extends Resource

## The numbers of the map's navmesh bake: data/nav/nav_bake.tres is their only source. tools/bake/bake_nav.gd and
## MapNavRegion read them; nothing else hardcodes a radius or a cell. Never mutated at runtime.

## Voxel size of the bake (m): the same for every map (zones keep each bake small).
@export var cell_size := 0.5
@export var cell_height := 0.25
## The common body radius (0.5 m) plus the NavService box clearance (0.5 m).
@export var agent_radius := 1.0
@export var agent_height := 2.0
## Recast drops a span whose neighbour is more than this below (a «ledge») and does not step over more than this. The grid takes the
## land as flat, so the navmesh must too: at 1 m cells a slope of 70 degrees rises 2.7 m per cell. 0.5 m (the step of move_and_slide)
## cut the hills into 30 islands; 3 m keeps them one piece, bodies walk those slopes (floor_max_angle 85).
@export var agent_max_climb := 3.0
## Degrees. High on purpose: every ground triangle of Terrain.is_on_ground must be walkable (floor_max_angle is 85).
@export_range(0.0, 90.0) var agent_max_slope := 85.0
@export var region_min_size := 8.0
@export var region_merge_size := 20.0
## The side of a bake zone (m): the map is baked in a fixed grid of squares from (0, 0), so a change re-bakes only the zones it
## touches (NavZones). A multiple of `cell_size`; MapNavRegion warns when it is not.
@export var zone_m := 160.0
## How far past its square a zone is baked (m), so the walls and ramps next to a zone line are seen from both sides and the
## pieces meet exactly on the line. A multiple of `cell_size`.
@export var zone_border_m := 8.0
## The fixed height of every zone's bake box (m, world Y): the lowest ground and the highest roof a map has, with room (a crater
## digs below the land; the land is metres above the lowest vertex). The same box for every zone is what keeps the seams exact.
@export var floor_m := -50.0
@export var ceiling_m := 400.0
## The scene that bakes (a tool, left out of the exported game): MapNavRegion's «Bake navmesh» button runs it. Not a bake number.
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


## Fits `navmesh` to the zone `zone` (x, z in metres): its bake box is the zone grown by `zone_border_m` on x and z, with the
## fixed height of every zone. The border keeps the engine from closing the box's edge, so the zone's piece reaches its own line.
func apply_zone(navmesh: NavigationMesh, zone: Rect2) -> void:
	navmesh.border_size = zone_border_m
	var box := zone.grow(zone_border_m)
	navmesh.filter_baking_aabb = AABB(
		Vector3(box.position.x, floor_m, box.position.y),
		Vector3(box.size.x, ceiling_m - floor_m, box.size.y)
	)


## Every number that changes the bake, as text, for the source hash.
func fingerprint() -> String:
	return (
		"%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s"
		% [
			cell_size,
			cell_height,
			agent_radius,
			agent_height,
			agent_max_climb,
			agent_max_slope,
			region_min_size,
			region_merge_size,
			zone_m,
			zone_border_m,
			floor_m,
			ceiling_m
		]
	)
