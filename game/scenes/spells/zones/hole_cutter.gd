class_name HoleCutter
extends Node

## The part of a Bore that opens the ground. From the moment its zone acts it walks the spiral and asks the map's Terrain to
## take away the ground under it (`cut_hole`: the Terrain says when it may), throws what is left over the hole so it falls, and
## lets a piece of ground drop. When it reaches the end of the spiral it waits, then gives the holes back one at a time, the last
## one first (`fill_hole`); when none is left the zone is done. Server (or solo) only; the clients get the holes from the
## Terrain and the effects from FxBus. It draws nothing itself (the zone's look does) and knows no lattice.

signal hole_cut(at: Vector3)
signal hole_filled(at: Vector3)

enum Stage { CUTTING, RESTORING }

@export var zone: GroundZone
## How fast it walks, against the spell's `speed` (the drill that bores ahead of it goes a little slower).
@export_range(0.1, 3.0, 0.01) var scribe_speed := 1.0
## After the last hole, the wait before the first one closes (3 s and 2 ticks).
@export_range(0.0, 20.0, 0.01, "suffix:s") var restore_delay_s := 3.0333
## Between two holes that close.
@export_range(0.0, 20.0, 0.01, "suffix:s") var restore_every_s := 0.5
## What is on the ground within this of a new hole and is not over land any more is thrown (it has to fall).
@export_range(1.0, 100.0, 0.5, "suffix:m") var fling_reach_m := 30.0
## The piece of ground that drops with each hole (FxBus.broadcast_scene; its root answers play(params): `at`).
@export var chunk: PackedScene
## The earth that bursts where a hole opens and where it closes (FxBus; the ones with a light light the ground).
@export var dig_burst: ParticleType
@export var restore_burst: ParticleType

var _stage := Stage.CUTTING
var _spiral: BoreSpiral
## Where it took the ground away, in order.
var _taken := PackedVector3Array()
var _ticks := 0
var _next_at := 0
var _terrain: Terrain


func _ready() -> void:
	process_physics_priority = -1
	set_physics_process(zone != null and zone.is_authority() and not Engine.is_editor_hint())
	_terrain = Terrain.of(self)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if zone != null
		else PackedStringArray(["The zone (GroundZone) it belongs to is missing."])
	)


func _physics_process(_delta: float) -> void:
	if zone.cancelled or zone.phase != GroundZone.Phase.ACTIVE or _terrain == null:
		return
	if _spiral == null:
		_spiral = BoreSpiral.new(
			Vector2(zone.points[0].x, zone.points[0].z),
			zone.spell.effect_range_m,
			scribe_speed * zone.spell.speed_m_s / MatchClock.TICKS_PER_SECOND_F
		)
	_ticks += 1
	if _stage == Stage.CUTTING:
		_cut()
	elif _ticks >= _next_at:
		_give_back()


func _exit_tree() -> void:
	# A zone that goes while the map stays leaves the ground whole (when the map goes too there is nothing to mend).
	if (
		_terrain != null
		and is_instance_valid(_terrain)
		and _terrain.is_inside_tree()
		and zone != null
		and zone.is_authority()
	):
		for at in _taken:
			_terrain.fill_hole(Vector2(at.x, at.z))
		_taken.clear()


func _cut() -> void:
	for at in _terrain.cut_hole(_spiral.advance()):
		_taken.append(at)
		_fling(at)
		if chunk != null:
			FxBus.broadcast_scene(chunk, at, {"at": at})
		if dig_burst != null:
			FxBus.broadcast(dig_burst, at)
		hole_cut.emit(at)
	if _spiral.arrived:
		_stage = Stage.RESTORING
		_next_at = _ticks + MatchClock.ticks_for(restore_delay_s)


func _give_back() -> void:
	if _taken.is_empty():
		zone.finish()
		return
	var last := _taken[_taken.size() - 1]
	_taken.remove_at(_taken.size() - 1)
	for at in _terrain.fill_hole(Vector2(last.x, last.z)):
		if restore_burst != null:
			FxBus.broadcast(restore_burst, at)
		hole_filled.emit(at)
	_next_at = _ticks + maxi(1, MatchClock.ticks_for(restore_every_s))


## What stood over the new hole and is not on land any more falls: a body on the ground is thrown with no speed.
func _fling(at: Vector3) -> void:
	for body in SplashDamage.bodies_within(
		get_tree(), at, fling_reach_m, null, ZonePulse.BODY_GROUPS
	):
		var tumbling := BodyNudge.tumbling_of(body)
		if (
			tumbling != null
			and not tumbling.is_on()
			and not BodyNudge.airborne(body)
			and not _terrain.is_on_ground(body.global_position.x, body.global_position.z)
		):
			tumbling.catapult(Vector3.ZERO, zone.from_slot)
