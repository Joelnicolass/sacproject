@tool
class_name PropNavZones3D
extends Node3D

## The navmesh of a 3D world, baked in square zones so a change re-bakes only the zones it touches,
## on worker threads, with props cutting it as cheap projected obstructions (PropObstructions).
## «Bake» in the inspector bakes every zone and saves them in `saved` (a .res next to the scene); a
## game loads that at once. It bakes again on its own when the saved bake does not match the props
## or the settings (`stale`), and, with `follow_props`, where a prop is freed or added in play.
## After something else changed (the ground, a building): `rebake(at, radius)`. `updated` says the
## paths see the change; `is_ready()` says the navmesh can be used at all. `index` answers what the
## server does not (can an agent get there, the closest land). One NavigationRegion3D per zone
## (internal children, not saved). Keep this node and `source_root` at the origin.

## The navigation map uses the latest pieces: paths and `index` see them. The first one makes
## `is_ready()` true.
signal updated
## Apply MANUAL: a result of a change in play is baked and waits for `apply()` (`zones`: the zones
## it re-baked).
signal bake_ready(zones: PackedInt32Array)
## The saved bake does not match the props or the settings. With `rebake_when_stale` every zone
## bakes again.
signal stale

enum Apply { AUTO, MANUAL }

## The settings of every zone: agent, cells, parsed geometry and collision mask. Leave the props'
## collision layer out of its collision mask.
@export var navigation_mesh: NavigationMesh
## What is parsed, with its children (as the navmesh's source geometry mode says), and where the
## props are looked for. Empty = the parent.
@export var source_root: Node
## Side of a zone. A multiple of the navmesh's cell size.
@export_range(1.0, 10000.0, 0.25, "or_greater", "suffix:m") var zone_size := 64.0:
	set(value):
		zone_size = value
		_redraw_in_editor()
## Props closer than this (edge to edge) are one obstruction: fewer polygons, faster paths. Keep
## it under the agent's diameter, so it closes no passage an agent could walk through. 0 = off.
@export_range(0.0, 100.0, 0.05, "or_greater", "suffix:m") var merge_gap := 0.0
## Re-bake on its own where a prop (a node of `obstruction_group`) is freed or added in play. A
## prop that moves: `rebake_prop()`.
@export var follow_props := true

@export_group("Saved")
## The baked zones the game loads («Bake» writes it next to the scene).
@export var saved: PropNavBake
## When the saved bake does not match the props or the settings: bake every zone again on start.
## Off: use it as it is.
@export var rebake_when_stale := true
## Saves the scene, bakes it the way the game will (in a separate Godot, with the project's
## autoloads) and loads the result.
@export_tool_button("Bake", "Bake") var bake_button := _bake_in_editor

@export_group("Advanced")
## MANUAL: a re-bake of a change in play waits for `apply()`, so a lockstep game swaps it in at a
## tick it chooses. The kit's own bakes (the start, a stale saved bake) apply at once.
@export var apply_mode := Apply.AUTO
## The area the zones cover (x, z). Empty = the parsed geometry's bounds.
@export var area := Rect2():
	set(value):
		area = value
		_redraw_in_editor()
## The margin baked around each zone so pieces meet exactly. 0 = from the agent radius.
@export_range(0.0, 1000.0, 0.05, "or_greater", "suffix:m") var zone_border := 0.0
## Floor (x) and ceiling (y) of every zone's bake, for a ground whose height changes in play (a
## crater, a mound): the same box for every zone, whatever the geometry is when a zone re-bakes.
## (0, 0) = the parsed geometry's, with a margin. Both are rounded out to the cell height.
@export var height_range := Vector2.ZERO
## Keep `index` (PropNavIndex) up to date with every bake.
@export var build_index := true
@export_flags_3d_navigation var navigation_layers := 1
## Off: the zones already meet, and edge connections make every swap slower.
@export var use_edge_connections := false
## The group of the props whose shapes cut the navmesh.
@export var obstruction_group: StringName = PropObstructions.GROUP
## Sides of a round shape's outline: fewer = fewer navmesh polygons.
@export_range(3, 32) var obstruction_sides := 6
## Cut exactly the props' outlines, with no agent radius around them.
@export var carve := false

## What the last bake cost and made.
var stats: PropNavStats:
	get:
		return _baker.stats if _baker != null else PropNavStats.new()
## The PropNavIndex of the pieces in force (null before the first, or without build_index).
var index: PropNavIndex:
	get:
		return _baker.index if _baker != null else null
## Optional: `func() -> int`, a number from the game that changes when what the navmesh is baked
## from changes besides the props (the terrain's heights, where the buildings stand). It joins the
## fingerprint, so `saved` goes stale when it differs. Set it any time: when the pieces in force
## are the saved bake's, they are checked again then.
var extra_fingerprint := Callable():
	set(value):
		extra_fingerprint = value
		if _baker != null and _baker.template != null:
			_baker.extra_fingerprint = value
			if _started:
				_baker.recheck_saved(rebake_when_stale and not Engine.is_editor_hint())

var _baker: PropZoneBaker
var _regions: Dictionary[int, NavigationRegion3D] = {}
var _started := false
var _ready_once := false
## Pieces were applied and the map has not used them yet.
var _waiting_map := false
## Regions waiting for the map to take their new piece: RID -> their iteration when it was set.
var _unsynced: Dictionary[RID, int] = {}
## Pieces held for a region still taking its previous one, by zone: Godot drops a navmesh set
## while the region's last asynchronous iteration is still running.
var _held: Dictionary[int, Resource] = {}
## The map's iteration once every region had rebuilt (-1 = not yet).
var _map_iteration := -1


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if navigation_mesh == null:
		out.append("Set navigation_mesh: the settings of every zone.")
		return out
	if not global_transform.is_equal_approx(Transform3D.IDENTITY):
		out.append("Keep this node at the origin with no rotation or scale.")
	var parsed := navigation_mesh.geometry_parsed_geometry_type
	if parsed != NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS:
		out.append(
			"The navmesh parses meshes: the props' meshes are baked as geometry too. Parse "
			+ "static colliders, with the props' layer out of the collision mask."
		)
	var map_cell: float = ProjectSettings.get_setting("navigation/3d/default_cell_size", 0.25)
	if not is_equal_approx(navigation_mesh.cell_size, map_cell):
		out.append(
			"The navmesh's cell size (%s) is not the navigation map's (%s, Project Settings > "
			% [navigation_mesh.cell_size, map_cell]
			+ "Navigation > 3D > Default Cell Size)."
		)
	out.append_array(_fresh_baker().problems(saved))
	return out


func _ready() -> void:
	set_process(false)
	_baker = PropZoneBaker.new()
	_baker.is_3d = true
	_baker.piece_changed.connect(_on_piece_changed)
	_baker.bake_ready.connect(bake_ready.emit)
	_baker.applied.connect(_on_applied)
	_baker.stale.connect(stale.emit)
	if navigation_mesh == null:
		if not Engine.is_editor_hint():
			push_error("%s: set navigation_mesh" % name)
		return
	# After the whole scene is ready: the props stand where they will.
	_start.call_deferred()


func _enter_tree() -> void:
	if _started:
		_follow(true)


func _exit_tree() -> void:
	if _started:
		_follow(false)


## Something the navmesh is baked from changed around `at` (the ground, a building): parses it
## again and re-bakes the zones within `radius`. Props freed or added need no call (`follow_props`).
func rebake(at: Vector3, radius: float) -> void:
	if _configure():
		_baker.request([Rect2(at.x - radius, at.z - radius, radius * 2.0, radius * 2.0)], true)


## `prop` moved or changed shape: re-bakes where it was and where it is now.
func rebake_prop(prop: Node) -> void:
	if _configure():
		_baker.request_prop(prop)


## Parses everything again and re-bakes every zone.
func rebake_all() -> void:
	if _configure():
		_baker.request_all(true)


## Apply MANUAL: swaps the waiting result in, in zone order.
func apply() -> void:
	if _baker != null:
		_baker.apply()


## True once the navmesh can be used: the first pieces are in the navigation map, with their
## `index`. It stays true while later changes bake.
func is_ready() -> bool:
	return _ready_once


## True while a change is on its way: a bake runs, a result waits for `apply()`, or the map has
## not taken the latest pieces yet. False: paths and `index` see everything asked for.
func is_updating() -> bool:
	if _waiting_map or not _held.is_empty():
		return true
	return _baker != null and (_baker.is_busy() or _baker.has_pending())


## Apply MANUAL: true when a result waits for `apply()`.
func has_result() -> bool:
	return _baker != null and _baker.has_result()


## The region of `zone` (null before its first piece).
func region_of(zone: int) -> NavigationRegion3D:
	return _regions.get(zone)


## The zone grid in force.
func grid() -> PropZoneGrid:
	return _baker.grid if _baker != null else PropZoneGrid.new()


## The zones in force as a PropNavBake (what «Bake» saves).
func to_saved() -> PropNavBake:
	return _baker.to_saved() if _baker != null else PropNavBake.new()


## Saves the zones in force to `path` (a .res) and keeps them as `saved`.
func save_bake(path: String) -> Error:
	var out := to_saved()
	var err := ResourceSaver.save(out, path)
	if err != OK:
		push_error("%s: could not save %s (%s)" % [name, path, error_string(err)])
		return err
	out.take_over_path(path)
	saved = out
	return OK


func _bake_in_editor() -> void:
	# Loaded only when pressed: the editor's scripts are not in an exported game.
	(load("res://addons/prop_kit/editor/prop_bake_run.gd") as Script).call(&"bake_open_scene")


func _start() -> void:
	if not _configure():
		return
	var editor := Engine.is_editor_hint()
	var loaded := saved != null and _baker.load_saved(saved, rebake_when_stale and not editor)
	if not loaded and not editor:
		_baker.request_all(true, false)
	_started = true
	_baker.start_following()
	_follow(true)


## Props entering the tree reach the baker (it sees the ones leaving on its own).
func _follow(on: bool) -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var signal_ := get_tree().node_added
	if on and not signal_.is_connected(_baker.on_node_added):
		signal_.connect(_baker.on_node_added)
	elif not on and signal_.is_connected(_baker.on_node_added):
		signal_.disconnect(_baker.on_node_added)


func _configure() -> bool:
	if _baker == null or navigation_mesh == null:
		return false
	if _baker.template == null:
		_setup(_baker)
		_baker.follow = follow_props and not Engine.is_editor_hint()
		_baker.manual_apply = apply_mode == Apply.MANUAL and not Engine.is_editor_hint()
	return true


func _setup(baker: PropZoneBaker) -> void:
	var under := source_root if source_root != null else get_parent()
	baker.configure(navigation_mesh, under, area, zone_size, zone_border)
	baker.height_range = height_range
	baker.group = obstruction_group
	baker.sides = obstruction_sides
	baker.merge_gap = merge_gap
	baker.carve = carve
	baker.with_index = build_index
	baker.extra_fingerprint = extra_fingerprint


## A baker with the settings as they are now, for the editor's warnings.
func _fresh_baker() -> PropZoneBaker:
	var baker := PropZoneBaker.new()
	baker.is_3d = true
	if is_inside_tree() and navigation_mesh != null:
		_setup(baker)
	return baker


func _on_piece_changed(zone: int, piece: Resource) -> void:
	var region: NavigationRegion3D = _regions.get(zone)
	if region == null:
		region = NavigationRegion3D.new()
		region.name = "Zone%d" % zone
		region.navigation_layers = navigation_layers
		region.use_edge_connections = use_edge_connections
		add_child(region, false, Node.INTERNAL_MODE_BACK)
		_regions[zone] = region
	if Engine.is_editor_hint():
		region.navigation_mesh = piece as NavigationMesh
		return
	var rid := region.get_rid()
	if _unsynced.has(rid) and NavigationServer3D.region_get_iteration_id(rid) == _unsynced[rid]:
		_held[zone] = piece
	else:
		_set_piece(region, piece)
	_map_iteration = -1
	set_process(true)


func _set_piece(region: NavigationRegion3D, piece: Resource) -> void:
	region.navigation_mesh = piece as NavigationMesh
	if piece == null:
		_unsynced.erase(region.get_rid())
		return
	_unsynced[region.get_rid()] = NavigationServer3D.region_get_iteration_id(region.get_rid())


func _on_applied(_zones: PackedInt32Array) -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
		_redraw_in_editor()
		return
	_waiting_map = true
	set_process(true)


func _redraw_in_editor() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_gizmos()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _baker != null:
		_baker.wait()


func _process(_delta: float) -> void:
	for zone in _held.keys():
		var region: NavigationRegion3D = _regions[zone]
		var rid := region.get_rid()
		if NavigationServer3D.region_get_iteration_id(rid) != _unsynced[rid]:
			_set_piece(region, _held[zone])
			_held.erase(zone)
	if not _held.is_empty():
		return
	if not _unsynced.is_empty():
		var map := get_world_3d().navigation_map
		if _map_iteration < 0:
			for rid in _unsynced:
				if NavigationServer3D.region_get_iteration_id(rid) == _unsynced[rid]:
					return
			# Every region rebuilt its piece. A synchronous map rebuilt with them in the same
			# step; an asynchronous one has to iterate once more to use them.
			if NavigationServer3D.map_get_use_async_iterations(map):
				_map_iteration = NavigationServer3D.map_get_iteration_id(map)
				return
		elif NavigationServer3D.map_get_iteration_id(map) <= _map_iteration:
			return
		_unsynced.clear()
		_map_iteration = -1
	set_process(false)
	if _waiting_map:
		_waiting_map = false
		_ready_once = true
		updated.emit()
