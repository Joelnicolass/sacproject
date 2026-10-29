@tool
class_name PropNavZones3D
extends Node3D

## The navmesh of a 3D world, baked in square zones so a change re-bakes only the zones it touches,
## on worker threads, with props cutting it as cheap projected obstructions (PropObstructions).
## One NavigationRegion3D per zone (internal children, not saved): the pieces meet exactly on the
## zone lines and the navigation map joins them with no edge connections. «Bake» in the inspector
## bakes every zone and saves them in `saved` (a .res next to the scene); a game loads that at
## once, and bakes again only when its props differ from the saved ones (`stale`, for example a
## match played without its forest). In play: `rebake(areas)` after something that blocks changed
## there; `reparse = false` when only props changed (the parsed geometry is reused). With apply
## MANUAL a result waits for `apply()`, so a lockstep game swaps it in at a tick it chooses.
## `index` answers what the server does not (connected components, closest point, the stitched
## navmesh). Keep this node and `source_root` at the origin: the pieces are in world space.

## A result of `zones` is baked; with apply MANUAL it waits for `apply()`.
signal bake_ready(zones: PackedInt32Array)
## The new pieces of `zones` are in the regions.
signal applied(zones: PackedInt32Array)
## The saved bake does not match the props in the scene.
signal stale
## The navigation map uses every piece in force now: paths and queries of the server see them.
## Godot takes a region's new navmesh over a few physics frames after `applied`.
signal synced

enum Apply { AUTO, MANUAL }

## The settings of every zone: agent, cells, parsed geometry and collision mask. Leave the props'
## collision layer out of its collision mask.
@export var navigation_mesh: NavigationMesh
## What is parsed, with its children (as the navmesh's source geometry mode says), and where the
## obstruction nodes are looked for. Empty = the parent.
@export var source_root: Node
## Side of a zone. A multiple of the navmesh's cell size.
@export_range(1.0, 10000.0, 0.25, "or_greater", "suffix:m") var zone_size := 64.0
## The margin baked around each zone so pieces meet exactly. 0 = from the agent radius.
@export_range(0.0, 1000.0, 0.05, "or_greater", "suffix:m") var zone_border := 0.0
## The area the zones cover (x, z). Empty = the parsed geometry's bounds.
@export var area := Rect2()
@export var apply_mode := Apply.AUTO
## Keep `index` (PropNavIndex) up to date with every bake.
@export var build_index := true
@export_flags_3d_navigation var navigation_layers := 1
## Off: the zones already meet, and edge connections make every swap slower.
@export var use_edge_connections := false

@export_group("Obstructions")
## The group of the props whose shapes cut the navmesh.
@export var obstruction_group: StringName = PropObstructions.GROUP
## Sides of a round shape's outline: fewer = fewer navmesh polygons.
@export_range(3, 32) var obstruction_sides := 6
## Props closer than this (edge to edge) are one obstruction: fewer polygons, faster paths. Keep
## it under the agent's diameter, so it closes no passage an agent could walk through. 0 = off.
@export_range(0.0, 100.0, 0.05, "or_greater", "suffix:m") var merge_gap := 0.0
## Cut exactly the outlines, with no agent radius around them.
@export var carve := false

@export_group("Saved")
## The baked zones the game loads («Bake» writes it next to the scene).
@export var saved: PropNavBake
## When the saved bake does not match the props: bake every zone again on start.
@export var rebake_when_stale := true
@export_tool_button("Bake", "Bake") var bake_button := bake_and_save

## What the last bake cost and made.
var stats: PropNavStats:
	get:
		return _baker.stats if _baker != null else PropNavStats.new()
## Optional: `func() -> int`, a number from the game that changes when what the navmesh is baked
## from changes besides the props (the terrain's heights, where the buildings stand). It joins the
## props' fingerprint, so `saved` goes stale when either changes. Set it before this node starts
## (in the game's `_ready`): the saved bake is checked one frame after the scene is ready.
var extra_fingerprint := Callable()
## The PropNavIndex of the pieces in force (null before the first bake, or without build_index).
var index: PropNavIndex:
	get:
		return _baker.index if _baker != null else null

var _baker: PropZoneBaker
var _regions: Dictionary[int, NavigationRegion3D] = {}
var _save_when_applied := false
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
	if not global_transform.is_equal_approx(Transform3D.IDENTITY):
		out.append("Keep this node at the origin with no rotation or scale.")
	if navigation_mesh != null:
		var type := navigation_mesh.geometry_parsed_geometry_type
		if type != NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS:
			out.append(
				"The navmesh parses meshes: the props' meshes are baked as geometry too. Parse "
				+ "static colliders, with the props' layer out of the collision mask."
			)
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


## Re-bakes the zones that `areas` (x, z, world units) touch: something that blocks changed there.
## `reparse` = parse the geometry again; false = only props changed (much cheaper).
func rebake(areas: Array[Rect2], reparse := true) -> void:
	if _configure():
		_baker.request(areas, reparse)


## Re-bakes every zone.
func rebake_all(reparse := true) -> void:
	if _configure():
		_baker.request_all(reparse)


## Swaps a waiting result in (apply MANUAL), in zone order.
func apply() -> void:
	if _baker != null:
		_baker.apply()


## True when nothing is baking: a waiting result can be applied without waiting.
func is_done() -> bool:
	return _baker == null or _baker.is_done()


## True when the navigation map uses every piece in force (`synced` was emitted since the last
## change).
func is_synced() -> bool:
	return _unsynced.is_empty() and _held.is_empty()


## True when a result waits for `apply()`.
func has_result() -> bool:
	return _baker != null and _baker.has_result()


## The region of `zone` (null before its first piece).
func region_of(zone: int) -> NavigationRegion3D:
	return _regions.get(zone)


## The zone grid in force.
func grid() -> PropZoneGrid:
	return _baker.grid if _baker != null else PropZoneGrid.new()


## The zones in force as a PropNavBake (what «Bake» saves), with the props' fingerprint.
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


## In the editor: bakes every zone and saves them in `saved` (a .res next to the scene).
func bake_and_save() -> void:
	if not Engine.is_editor_hint():
		push_error("%s: bake_and_save() is for the editor; use rebake_all() in a game" % name)
		return
	if not _configure():
		return
	_save_when_applied = true
	_baker.request_all(true)


func _start() -> void:
	if not _configure():
		return
	var rebake := rebake_when_stale and not Engine.is_editor_hint()
	if saved != null and _baker.load_saved(saved, rebake):
		return
	if not Engine.is_editor_hint():
		_baker.request_all(true)


func _configure() -> bool:
	if _baker == null or navigation_mesh == null:
		return false
	if _baker.template == null:
		var under := source_root if source_root != null else get_parent()
		_baker.configure(navigation_mesh, under, area, zone_size, zone_border)
		_baker.group = obstruction_group
		_baker.sides = obstruction_sides
		_baker.merge_gap = merge_gap
		_baker.carve = carve
		_baker.manual_apply = apply_mode == Apply.MANUAL and not Engine.is_editor_hint()
		_baker.with_index = build_index
		_baker.extra_fingerprint = extra_fingerprint
	return true


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
	if _unsynced.is_empty() and _held.is_empty():
		set_process(false)
		return
	if not _held.is_empty():
		return
	var map := get_world_3d().navigation_map
	if _map_iteration < 0:
		for rid in _unsynced:
			if NavigationServer3D.region_get_iteration_id(rid) == _unsynced[rid]:
				return
		# Every region rebuilt its piece; the map has to iterate once more to use them.
		_map_iteration = NavigationServer3D.map_get_iteration_id(map)
		return
	if NavigationServer3D.map_get_iteration_id(map) > _map_iteration:
		_unsynced.clear()
		_map_iteration = -1
		set_process(false)
		synced.emit()


func _on_applied(zones: PackedInt32Array) -> void:
	applied.emit(zones)
	if _save_when_applied:
		_save_when_applied = false
		_save()


func _save() -> void:
	var path := saved.resource_path if saved != null else ""
	if path.is_empty() or path.contains("::"):
		var scene := get_tree().edited_scene_root
		if scene == null or scene.scene_file_path.is_empty():
			push_error("%s: save the scene first; the bake goes next to it" % name)
			return
		path = scene.scene_file_path.get_basename() + "_nav.res"
	if save_bake(path) == OK:
		PropPlanner.mark_edited(self)
		print("%s: %s saved (%s)" % [name, path, stats])
