@tool
class_name Terrain
extends Node3D

## The ground of a map: the one place that says how high the land is, where it has holes and how it moved in the match.
## Everyone asks it; whatever moves the ground asks it to (stamp, keep_stamp, cut_hole, fill_hole) and it tells `changed` after.
## The only writer: the server decides what stays and tells `kept`/`hole_set`, the child `Net` carries them to the clients and
## hands them back here; the state shows in `Status`.
## Not: the look (TerrainMesh), the body to stand on (TerrainCollision), the network transport (TerrainNet), what a spell is.

signal changed(rect: Rect2)  ## x, z in metres; every peer. The stamps that play: once per physics tick, all of them together
signal settled(rect: Rect2)  ## what stays moved (commit, unstamp, holes): flora, nav and scars follow this, never a live stamp
signal holes_changed(rect: Rect2)  ## a vertex came or went (the collision flushes now, NavService bakes again)
signal derived  ## the triangles were derived again from `heights` (on load; editor: after a reimport or a brush stroke)
signal settled(rect: Rect2)  ## what stays moved (commit, unstamp, holes): flora, nav and scars follow this, never a live stamp
signal kept(rev: int, key: String, rect: Rect2i, delta: PackedFloat32Array)  ## `delta` over `rect` stays as change `rev` (Net sends it)
signal hole_set(rev: int, id: int, removed: bool)  ## the lattice vertex `id` went or came back as change `rev` (Net sends it)
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
## The stamps that play, gathered per tick (the child `Live`). Empty = a stamp shows nothing.
@export var live: TerrainLive

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
	if Engine.is_editor_hint():
		return
	if live != null:
		live.ticked.connect(_on_live_ticked)


func _get_configuration_warnings() -> PackedStringArray:
	var wired := heights != null and ground_roles != null and mesh != null and live != null
	return PackedStringArray() if wired else PackedStringArray(["Faltan `heights` (heights.png), `ground_roles` (ground_roles.png), `mesh` (el hijo Mesh) o `live` (el hijo Live)."])


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


## A Callable(x, z) -> float like height_at, on a copy of the ground as it was at its last `settled`: WorkerThreadPool-safe.
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


## Every peer, from its own clock: stamp `key` shows its shift at `at_s` s at the next physics tick, in place of its last one.
func stamp(key: StringName, profile: StampProfile, center: Vector2, reach_m: float, peak_m: float, at_s: float, pattern := PackedFloat32Array()) -> void:
	if live != null:
		live.put(String(key), profile, center, reach_m, peak_m, at_s, pattern)


## The playing stamp `key` is over: at the next physics tick the ground goes back to what stays.
func unstamp(key: StringName) -> void:
	if live != null:
		live.drop(String(key))


## Server (or alone): what the stamp reaches at its end stays, its live shift `key` goes in the same step; the clients get it.
func keep_stamp(key: StringName, profile: StampProfile, center: Vector2, reach_m: float, peak_m: float, pattern := PackedFloat32Array()) -> void:
	var rect := TerrainGrid.vertex_rect(center, reach_m)
	var delta := StampRules.shift(profile, center, reach_m, peak_m, profile.duration_s() - 1e-4, rect, pattern)
	if _may_edit("keep_stamp") and delta.size() == rect.get_area():
		keep(_field.rev + 1, String(key), rect, delta)


## Server (or alone): takes away the vertex nearest to `center` (or all within `radius_m`) HoleRules lets go; returns where (never NAN).
func cut_hole(center: Vector2, radius_m := 0.0) -> PackedVector3Array:
	var taken := PackedVector3Array()
	if _may_edit("cut_hole"):
		for vertex in HoleRules.removable(self, center, radius_m):
			taken.append(HoleRules.point_on(self, vertex))
			set_hole(_field.rev + 1, TerrainGrid.id_of(vertex), true)
	return taken


## Server (or alone): gives back the vertex nearest to `center` (or all within `radius_m`) taken in this match, never a void of the map.
func fill_hole(center: Vector2, radius_m := 0.0) -> PackedVector3Array:
	var filled := PackedVector3Array()
	if _may_edit("fill_hole"):
		for vertex in HoleRules.around(center, radius_m):
			if set_hole(_field.rev + 1, TerrainGrid.id_of(vertex), false):
				filled.append(HoleRules.point_on(self, vertex))
	return filled


func _may_edit(what: String) -> bool:
	if not is_authority():
		push_warning("Terrain.%s: only the server changes the ground for good." % what)
	return is_authority()


## Keeps `delta` over `rect` as change number `rev` and takes the live stamp `key` away in the same step (keep_stamp, and
## Net on a client). A change this peer already has is ignored.
func keep(rev: int, key: String, rect: Rect2i, delta: PackedFloat32Array) -> void:
	if rev <= _field.rev:
		return
	if live != null:
		live.forget(key)
	var standing := StampCarry.standing(self, rect)
	var moved := _field.commit(rect, delta, key if not key.is_empty() else null)
	_field.rev = rev
	StampCarry.lift(standing, self)
	_tell(moved, true)
	kept.emit(rev, key, rect, delta)


## Takes the vertex `id` away or gives it back as change number `rev` (cut_hole, fill_hole, and Net on a client). True when
## that changed something; a change this peer already has is ignored.
func set_hole(rev: int, id: int, removed: bool) -> bool:
	if rev <= _field.rev or not _field.set_removed(id, removed):
		return false
	_field.rev = rev
	var around := Rect2i(TerrainGrid.vertex_of(id) - Vector2i.ONE, Vector2i(3, 3))
	_tell(around, true)
	holes_changed.emit(TerrainGrid.area_of(around))
	hole_set.emit(rev, id, removed)
	return true


## Tells that the ground moved over `rect` and, when `settles`, that what stays moved there too.
func _tell(rect: Rect2i, settles: bool) -> void:
	if rect.has_area():
		changed.emit(TerrainGrid.area_of(rect))
		if settles:
			settled.emit(TerrainGrid.area_of(rect))


## One physics tick of the stamps that play: the bodies their rects cover are found once, the shifts written, `changed` told once.
func _on_live_ticked(shifts: Array, ended: PackedStringArray) -> void:
	var gone := Rect2i()
	for key in ended:
		gone = TerrainGrid.union(gone, _field.drop_live(key))
	var risen := Rect2i()
	for shift: TerrainLive.Shift in shifts:
		risen = TerrainGrid.union(risen, shift.rect)
	var standing := StampCarry.standing(self, risen)
	var moved := gone
	for shift: TerrainLive.Shift in shifts:
		moved = TerrainGrid.union(moved, _field.set_live(shift.key, shift.rect, shift.values))
	StampCarry.lift(standing, self)
	_tell(moved, false)
	if gone.has_area():
		settled.emit(TerrainGrid.area_of(gone))


## Net on a client that joined late: the whole ground the server had; an older one than this peer has is ignored.
func load_snapshot(snapshot: Dictionary) -> void:
	if int(snapshot["rev"]) >= _field.rev:
		_field.apply_snapshot(snapshot)
		_tell(Rect2i(Vector2i.ZERO, _field.size), true)


## New triangles from the heights: the match starts over; the vertices `moved` since the last derive (a brush stroke) settle.
func _on_derived(moved: Rect2i) -> void:
	data = _shape.faces
	index = _shape.index
	_field = GroundField.new()
	derived.emit()
	if moved.has_area():
		settled.emit(TerrainGrid.area_of(moved))
