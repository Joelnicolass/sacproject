@tool
class_name Terrain
extends Node3D

## The ground of a map: the one place that says how high the land is, where it has holes and how it moved in the match.
## Everyone asks it; whatever moves the ground asks it to (stamp, keep_stamp, cut_hole, fill_hole) and it tells `changed` after.
## The only writer: the server decides what stays, `net` carries the same bytes to the clients; the state shows in `Status`.
## Not: the look (TerrainMesh), the body to stand on (TerrainCollision), the network transport (TerrainNet), what a spell is.

signal changed(rect: Rect2)  ## x, z in metres; every peer
signal holes_changed(rect: Rect2)  ## a vertex came or went (the collision flushes now, NavService bakes again)
signal derived  ## the triangles were derived again from `heights` (on load; editor: after a reimport or a brush stroke)
signal settled(rect: Rect2)  ## what stays moved (commit, unstamp, holes): flora, nav and scars follow this, never a live stamp
const GROUP := &"terrain"

## The shape of the map's ground: its heights.png and void.png, imported as TerrainHeights. Everything else is derived.
@export var heights: TerrainHeights:
	set(value):
		heights = value
		_shape.follow(heights, self)
## The map's tile index: its tiles.png imported as Image (256x256, the original tile id in R). Empty = tile 0 everywhere.
@export var tiles: Image
## Which kind of ground lies where (the map's ground_roles.png, 1 px per 10 m cell: R open, G earth, B rock, A path).
@export var ground_roles: Texture2D
## The map's own baked light on the ground (the map's light.png). Empty = the ground reads evenly lit.
@export var light_map: Texture2D
## The node that draws this ground (the child `Mesh`): the look layer dresses it, the minimap bakes it.
@export var mesh: MeshInstance3D
## The network transport of what stays (the child `Net`). Empty = alone.
@export var net: TerrainNet

## The triangles derived from `heights` (land first, then the cliff walls), in memory only: Mesh and Collision read them.
var data := MapTerrainData.new()
## The land triangles per cell (read only: the walls of the holes, the falling piece and HoleRules read them).
var index := TerrainRules.Index.new()
var _shape := TerrainShape.new()
var _field := GroundField.new()
var _tiles := GroundTiles.new()


## The ground of the map `node` is in; null when it is not in the tree or no ground is loaded.
static func of(node: Node) -> Terrain:
	var found := node.get_tree().get_first_node_in_group(GROUP) as Terrain if node != null and node.is_inside_tree() else null
	return found if found != null and found.is_loaded() else null


func _init() -> void:
	_shape.derived.connect(_on_derived)


func _ready() -> void:
	add_to_group(GROUP)
	if net != null and not Engine.is_editor_hint():
		net.kept_received.connect(_on_kept_received)
		net.hole_received.connect(_on_hole_received)
		net.snapshot_received.connect(_on_snapshot_received)
		net.snapshot_wanted.connect(func(peer_id: int) -> void: net.push_snapshot(peer_id, _field.to_snapshot()))


func _get_configuration_warnings() -> PackedStringArray:
	var wired := heights != null and ground_roles != null and mesh != null and net != null
	return PackedStringArray() if wired else PackedStringArray(["Faltan `heights` (heights.png), `ground_roles` (ground_roles.png), `mesh` (el hijo Mesh) o `net` (el hijo Net)."])


func is_loaded() -> bool:
	return not index.ground.is_empty()


## Land height under (x, z) in metres, NAN over a hole or off the map.
func height_at(x: float, z: float) -> float:
	return TerrainRules.height_in(x, z, index.ground, index.cells, _field.texels, index.corners)


## Unit normal (pointing up) of the land under (x, z); straight up over a hole or off the land.
func normal_at(x: float, z: float) -> Vector3:
	return TerrainRules.normal_in(x, z, index.ground, index.cells, _field.texels, index.corners)


## True when a land triangle lies under (x, z). Holes and the map rim have none.
func is_on_ground(x: float, z: float) -> bool:
	return TerrainRules.triangle_in(x, z, index.ground, index.cells, _field.texels, index.corners) >= 0


## The map's footprint on the ground (x, z in metres; the map lives at x, z >= 0).
func bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_field.size) * _field.cell_m)


## The lowest land vertex (0 without land).
func lowest() -> float:
	return index.lowest


## A Callable(x, z) -> float like height_at, on copies taken now (a later change does not touch it): WorkerThreadPool-safe.
func sampler() -> Callable:
	return TerrainRules.height_in.bind(index.ground, index.cells, _field.snapshot(), index.corners)


## True on the server (and alone): the only peer that decides what stays.
func is_authority() -> bool:
	return not is_inside_tree() or multiplayer.is_server()


## How far the ground has moved from the file. Read only: only Terrain writes it.
func field() -> GroundField:
	return _field


## The original tile id of each 10 m cell, 256x256 row-major (empty without `tiles`).
func tile_ids() -> PackedByteArray:
	return _tiles.ids(tiles)


## Every peer, from its own clock: stamp `key` shows its shift at `at_s` s (in place of its last one; `pattern`: stamp_pattern).
func stamp(key: StringName, profile: StampProfile, center: Vector2, reach_m: float, peak_m: float, at_s: float, pattern := PackedFloat32Array()) -> void:
	var rect := TerrainGrid.vertex_rect(center, reach_m)
	var values := StampRules.shift(profile, center, reach_m, peak_m, at_s, rect, pattern)
	if values.size() == rect.get_area():
		var standing := StampCarry.standing(self, rect)
		_tell(_field.set_live(String(key), rect, values))
		StampCarry.lift(standing, self)


## The playing stamp `key` is over: the ground goes back to what stays.
func unstamp(key: StringName) -> void:
	_tell(_field.drop_live(String(key)))


## Server (or alone): what the stamp reaches at its end stays, its live shift `key` goes in the same step; the clients get it.
func keep_stamp(key: StringName, profile: StampProfile, center: Vector2, reach_m: float, peak_m: float, pattern := PackedFloat32Array()) -> void:
	var rect := TerrainGrid.vertex_rect(center, reach_m)
	var delta := StampRules.shift(profile, center, reach_m, peak_m, profile.duration_s() - 1e-4, rect, pattern)
	if _may_edit("keep_stamp") and delta.size() == rect.get_area():
		var standing := StampCarry.standing(self, rect)
		_tell(_field.commit(rect, delta, String(key) if key != &"" else null))
		StampCarry.lift(standing, self)
		if net != null:
			net.send_kept(_field.rev, String(key), rect, delta)


## Server (or alone): a picture stamp's shift at full size over the land under it now, worked out once.
func stamp_pattern(profile: StampProfile, center: Vector2, reach_m: float, peak_m: float) -> PackedFloat32Array:
	return StampRules.pattern_under(self, profile, center, reach_m, peak_m)


## Server (or alone): takes away the vertex nearest to `center` (or all within `radius_m`) HoleRules lets go; returns where (never NAN).
func cut_hole(center: Vector2, radius_m := 0.0) -> PackedVector3Array:
	var taken := PackedVector3Array()
	if _may_edit("cut_hole"):
		for vertex in HoleRules.removable(self, center, radius_m):
			taken.append(HoleRules.point_on(self, vertex))
			_set_hole(vertex, true)
	return taken


## Server (or alone): gives back the vertex nearest to `center` (or all within `radius_m`) taken in this match, never a void of the map.
func fill_hole(center: Vector2, radius_m := 0.0) -> PackedVector3Array:
	var filled := PackedVector3Array()
	if _may_edit("fill_hole"):
		for vertex in HoleRules.around(center, radius_m):
			if _set_hole(vertex, false):
				filled.append(HoleRules.point_on(self, vertex))
	return filled


func _may_edit(what: String) -> bool:
	if not is_authority():
		push_warning("Terrain.%s: only the server changes the ground for good." % what)
	return is_authority()


## Takes the vertex away or gives it back, and sends it to the clients. True when that changed something.
func _set_hole(vertex: Vector2i, removed: bool) -> bool:
	var id := TerrainGrid.id_of(vertex)
	if not _field.set_removed(id, removed):
		return false
	_field.rev += 1
	_tell_holes(id)
	if net != null:
		net.send_hole(_field.rev, id, removed)
	return true


func _tell(rect: Rect2i) -> void:
	changed.emit(TerrainGrid.area_of(rect))


func _tell_holes(id: int) -> void:
	var around := Rect2i(TerrainGrid.vertex_of(id) - Vector2i.ONE, Vector2i(3, 3))
	_tell(around)
	holes_changed.emit(TerrainGrid.area_of(around))


func _on_kept_received(rev: int, key: String, rect: Rect2i, delta: PackedFloat32Array) -> void:
	if rev > _field.rev:
		_tell(_field.commit(rect, delta, key if not key.is_empty() else null))
		_field.rev = rev


func _on_hole_received(rev: int, id: int, removed: bool) -> void:
	if rev > _field.rev:
		_field.set_removed(id, removed)
		_field.rev = rev
		_tell_holes(id)


func _on_snapshot_received(snapshot: Dictionary) -> void:
	if int(snapshot["rev"]) >= _field.rev:
		_field.apply_snapshot(snapshot)
		_tell(Rect2i(Vector2i.ZERO, _field.size))


## New triangles from the heights: the match state starts over (nothing has moved yet).
func _on_derived() -> void:
	data = _shape.faces
	index = _shape.index
	_field = GroundField.new()
	derived.emit()
