class_name NavService
extends Node

## The world's pathfinder (RFC-024 §3.1, 024b): %Nav in high_noon. It builds the NavGrid once, after the
## world is ready (terrain, manafounts and altars exist), and answers find_path / component_at for the
## player, the AI and the perception. Only where the world is simulated: a client never asks.
## Blockers come from the scene: the collision shapes of the nodes in `blocker_groups` (manafounts, the
## altars in play and the buildings of the map, RFC-024 addendum 1; `nav_blocker` is for whatever else a scene puts in the way, a
## pillar of the test of the Sac Doctors). Nothing here moves a body; PathFollower hands waypoints to begin_walk.

signal built(ms: float)

const GROUP := &"nav_service"

@export var terrain: MeshInstance3D
## Margin added to every blocker (sacengine blockingTolerance, state.d:790).
@export var margin_m := 1.5
## A node needs whole land around it too (sacengine isFree asks the cells around the node).
@export var erode_edges := true
@export var blocker_groups: PackedStringArray = PackedStringArray(["manafount", "altar", "map_building", "nav_blocker"])
## What the players build (Manaliths, RFC-021): their collision blocks too, and the grid is built again when one
## appears or falls (024c; the debt of F72/F73). `structures` is the node they are put under (%Structures).
@export var built_group: StringName = &"structure"
@export var structures: Node
## Frames to wait after a structure enters or leaves before building again (it needs its own _ready first).
@export var rebuild_delay_frames := 2
## At most this many A* searches per physics tick; the rest of the callers wait for the next tick
## (a count, never a clock, so the match stays reproducible).
@export var max_searches_per_tick := 3
@export var build_on_ready := true

var grid := NavGrid.new()
## Microseconds of the last A* search, for the report.
var last_find_us := 0
## Microseconds of every A* search so far (for the report; never read by the simulation).
var search_us_total := 0
var searches := 0
var searches_this_tick := 0
var rebuilds := 0

var _rebuild_in := -1


func _ready() -> void:
	add_to_group(GROUP)
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
		return
	if structures != null:
		structures.child_entered_tree.connect(_on_structure_changed.unbind(1))
		structures.child_exiting_tree.connect(_on_structure_changed.unbind(1))
	if build_on_ready:
		build.call_deferred()


func _physics_process(_delta: float) -> void:
	searches_this_tick = 0
	if _rebuild_in >= 0:
		_rebuild_in -= 1
		if _rebuild_in < 0:
			rebuilds += 1
			build()


func _on_structure_changed() -> void:
	if grid.built:
		_rebuild_in = rebuild_delay_frames


func is_ready() -> bool:
	return grid.built


## Builds the grid (again). Returns the milliseconds it took.
func build() -> float:
	if terrain == null or not terrain.has_method("ground_cell_counts"):
		return 0.0
	grid.build(terrain, _blockers(), margin_m, erode_edges)
	_watch_buildings()
	print("nav: grilla %d nodos libres, %d regiones, %.0f ms" % [grid.free_count, grid.component_count, grid.build_ms])
	built.emit(grid.build_ms)
	return grid.build_ms


## A building that falls leaves no wall: the grid is built again without it (its collision is off by then).
func _watch_buildings() -> void:
	for node in get_tree().get_nodes_in_group(MapBuilding.GROUP):
		var building := node as MapBuilding
		if building != null and not building.destroyed.is_connected(_on_building_destroyed):
			building.destroyed.connect(_on_building_destroyed)


func _on_building_destroyed(_building: MapBuilding) -> void:
	build.call_deferred()


## True while the tick still has room for another A* search; takes one slot.
func take_search_slot() -> bool:
	if searches_this_tick >= max_searches_per_tick:
		return false
	searches_this_tick += 1
	return true


## Waypoints from `from` (not included) to `to`; [to] when nothing is in the way or there is no grid.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not grid.built:
		return PackedVector3Array([to])
	var started := Time.get_ticks_usec()
	var path := grid.find_path(from, to)
	last_find_us = Time.get_ticks_usec() - started
	search_us_total += last_find_us
	searches += 1
	if path.is_empty():
		return PackedVector3Array([to])
	for k in path.size():
		var ground: float = terrain.call("ground_height", path[k].x, path[k].z) if terrain else NAN
		path[k].y = from.y if is_nan(ground) else ground
	return path


func line_clear(from: Vector3, to: Vector3) -> bool:
	return not grid.built or grid.line_clear(from, to)


func component_at(point: Vector3) -> int:
	return grid.component_at(point) if grid.built else -1


func same_region(a: Vector3, b: Vector3) -> bool:
	return not grid.built or grid.same_region(a, b)


## One entry per collision shape of the blocker nodes: [Vector2 center, radius] for a cylinder or a sphere and
## [Vector2 center, Vector2 half extents, yaw] for a box (the buildings of the map).
func _blockers() -> Array:
	var discs := []
	for group in blocker_groups:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D:
				_collect(node as Node3D, discs, 0)
	for node in get_tree().get_nodes_in_group(built_group):
		var built := node as Node3D
		if built != null and not built.is_in_group(MapBuilding.GROUP) and not built.is_queued_for_deletion() and not blocker_groups.has(String(built_group)):
			_collect(built, discs, 0)
	return discs


func _collect(node: Node3D, discs: Array, depth: int) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			var shape_node := child as CollisionShape3D
			if shape_node.disabled:
				continue
			var at := shape_node.global_position
			var scale := shape_node.global_transform.basis.get_scale()
			if shape_node.shape is CylinderShape3D:
				var cylinder := shape_node.shape as CylinderShape3D
				discs.append([Vector2(at.x, at.z), cylinder.radius * maxf(scale.x, scale.z)])
			elif shape_node.shape is BoxShape3D:
				var half := (shape_node.shape as BoxShape3D).size * 0.5 * scale
				discs.append([Vector2(at.x, at.z), Vector2(half.x, half.z), shape_node.global_transform.basis.get_euler().y])
			elif shape_node.shape is SphereShape3D:
				discs.append([Vector2(at.x, at.z), (shape_node.shape as SphereShape3D).radius * maxf(scale.x, scale.z)])
		elif child is Node3D and depth < 2:
			_collect(child as Node3D, discs, depth + 1)
