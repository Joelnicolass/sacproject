class_name HoleCutter
extends Node

## The part of a Bore that opens the ground. From the moment its zone acts it walks the spiral and takes away the vertex of the
## ground under it (HoleRules says when it may; it asks the only writer, TerrainDeformer), throws what is left over the hole so
## it falls, and lets a piece of ground drop. When it reaches the end of the spiral it waits, then gives the vertices back one at a
## time, the last one taken first; when none is left the zone is done. Server (or solo) only; the clients get the holes from the
## deformer and the effects from FxBus. It draws nothing itself (the zone's look does) and never touches a building.
## Ref: sacengine updateBoreHole (state.d:18653-18696), removeLandVertex (state.d:29027-29059).

signal vertex_taken(id: int)
signal vertex_given_back(id: int)

enum Stage { CUTTING, RESTORING }

@export var zone: GroundZone
## How fast it walks, against the spell's `speed` (the drill that bores ahead of it goes a little slower).
@export_range(0.1, 3.0, 0.01) var scribe_speed := 1.0
## After the last vertex, the wait before the first one comes back (3 s and 2 ticks).
@export_range(0.0, 20.0, 0.01, "suffix:s") var restore_delay_s := 3.0333
## Between two vertices that come back.
@export_range(0.0, 20.0, 0.01, "suffix:s") var restore_every_s := 0.5
## What is on the ground within this of a new hole and is not over land any more is thrown (it has to fall).
@export_range(1.0, 100.0, 0.5, "suffix:m") var fling_reach_m := 30.0
## The piece of ground that drops with each hole (FxBus.broadcast_scene; its root answers play(params): `vertex`).
@export var chunk: PackedScene
## The earth that bursts where a vertex goes and where it comes back (FxBus; the ones with a light light the ground).
@export var dig_burst: ParticleType
@export var restore_burst: ParticleType

var _stage := Stage.CUTTING
var _spiral: BoreSpiral
var _taken := PackedInt32Array()
var _ticks := 0
var _next_at := 0
var _last := Vector2i(-1, -1)
var _deformer: TerrainDeformer
var _land: TerrainShape


func _ready() -> void:
	process_physics_priority = -1
	set_physics_process(zone != null and zone.is_authority() and not Engine.is_editor_hint())
	_deformer = TerrainDeformer.of(self)
	_land = TerrainShape.of(self)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if zone != null else PackedStringArray(["Falta la zona (GroundZone) a la que pertenece."])


## The lattice ids of the vertices it holds away now, in the order they were taken.
func taken() -> PackedInt32Array:
	return _taken


func _physics_process(_delta: float) -> void:
	if zone.cancelled or zone.phase != GroundZone.Phase.ACTIVE or _deformer == null or _land == null:
		return
	if _spiral == null:
		_spiral = BoreSpiral.new(Vector2(zone.points[0].x, zone.points[0].z), zone.spell.effect_range_m, scribe_speed * zone.spell.speed_m_s / MatchClock.TICKS_PER_SECOND_F)
	_ticks += 1
	if _stage == Stage.CUTTING:
		_cut()
	elif _ticks >= _next_at:
		_give_back()


func _exit_tree() -> void:
	# A zone that goes while the map stays leaves the ground whole (when the map goes too there is nothing to mend).
	if _deformer != null and is_instance_valid(_deformer) and _deformer.is_inside_tree() and not _taken.is_empty() and zone != null and zone.is_authority():
		for id in _taken:
			_deformer.set_removed(id, false)
		_taken.clear()


func _cut() -> void:
	var vertex := HoleRules.vertex_near(_spiral.advance())
	if vertex != _last:
		_last = vertex
		_take(vertex)
	if _spiral.arrived:
		_stage = Stage.RESTORING
		_next_at = _ticks + MatchClock.ticks_for(restore_delay_s)


func _take(vertex: Vector2i) -> void:
	if not HoleRules.can_remove(_land, vertex, _building_parts()):
		return
	var id := vertex.y * TerrainRules.GRID + vertex.x
	var at := _vertex_point(vertex)
	_deformer.set_removed(id, true)
	_taken.append(id)
	_fling(at)
	if chunk != null:
		FxBus.broadcast_scene(chunk.resource_path, at, {"vertex": id})
	if dig_burst != null:
		FxBus.broadcast(FxBus.name_of(dig_burst), at)
	vertex_taken.emit(id)


func _give_back() -> void:
	if _taken.is_empty():
		zone.finish()
		return
	var id := _taken[_taken.size() - 1]
	_taken.remove_at(_taken.size() - 1)
	if _deformer.shape.displacement().is_removed(id):
		_deformer.set_removed(id, false)
		if restore_burst != null:
			FxBus.broadcast(FxBus.name_of(restore_burst), _vertex_point(Vector2i(id % TerrainRules.GRID, id / TerrainRules.GRID)))
		vertex_given_back.emit(id)
	_next_at = _ticks + maxi(1, MatchClock.ticks_for(restore_every_s))


## The grid vertex on the ground. Once its neighbours are taken no land triangle touches it and height_at is NAN, so it tries
## a little inside each of the four cells around it and, with all of them gone, the zone's own height. Never NAN: a NAN
## point would reach the chunk, the burst and the bodies flung.
func _vertex_point(vertex: Vector2i) -> Vector3:
	var spot := Vector2(vertex) * TerrainRules.CELL
	var height := _land.height_at(spot.x, spot.y)
	for side: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		if not is_nan(height):
			break
		var inside := spot + side * TerrainRules.CELL * 0.25
		height = _land.height_at(inside.x, inside.y)
	return Vector3(spot.x, zone.global_position.y if is_nan(height) else height, spot.y)


## What stood over the new hole and is not on land any more falls: a body on the ground is thrown with no speed.
func _fling(at: Vector3) -> void:
	for body in SplashDamage.bodies_within(get_tree(), at, fling_reach_m, null, ZonePulse.BODY_GROUPS):
		var tumbling := BodyNudge.tumbling_of(body)
		if tumbling != null and not tumbling.is_on() and not BodyNudge.airborne(body) and not _land.is_on_ground(body.global_position.x, body.global_position.z):
			tumbling.catapult(Vector3.ZERO, zone.from_slot)


## The places of the parts of every building, manafount and altar of the map.
func _building_parts() -> PackedVector3Array:
	var parts := PackedVector3Array()
	for group in [MapBuilding.GROUP, ManafountBody.GROUP, Altar.ANY_GROUP]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null:
				continue
			parts.append(body.global_position)
			var building := body as MapBuilding
			if building != null and building.visuals != null:
				for part in building.visuals.get_children():
					if part is Node3D:
						parts.append((part as Node3D).global_position)
	return parts
