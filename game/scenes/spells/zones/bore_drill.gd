class_name BoreDrill
extends Node3D

## The rock that bores: from the moment the zone is born it walks the spiral over the ground, a little behind the cutter's pace,
## throwing earth and leaving a mark on the ground at each step; when the spiral ends it is gone. Every peer walks it from its own
## count of ticks, and the server's count is sent so one that joins late is where the others are. Presentation only: a headless
## process keeps its count and draws nothing. It does not open the ground (HoleCutter) and hurts nobody.
## Ref: sacengine updateBore, animateBore (state.d:18636-18651, 18593-18616).

@export var zone: GroundZone
## How fast it goes, against the spell's `speed`.
@export_range(0.1, 3.0, 0.01) var scribe_speed := 0.9
## The mark it leaves at each step (a small burn: the Bore's `bscr`).
@export var scar: ScarMark
## What shows only while it bores: the rock, the dirt, the light.
@export var look: Node3D
@export var emitters: Array[SpriteEmitter] = []
@export var sound: SoundEmitter3D
## Ticks a peer may be off the server's count before it takes the server's.
@export_range(1, 60) var resync_ticks := 8

## Ticks since the zone was born, on this peer.
var ticks := 0
## The server's count of ticks (the zone sends it).
var synced_ticks := 0
## Where it is on the ground plane (x, z), also in a process that draws nothing.
var place := Vector2.ZERO

var _spiral: BoreSpiral
var _land: TerrainShape
var _draws := false


func _ready() -> void:
	process_physics_priority = 1
	if Engine.is_editor_hint() or zone == null:
		set_physics_process(false)
		return
	_draws = DisplayServer.get_name() != "headless"
	_land = TerrainShape.of(self)
	for emitter in emitters:
		emitter.set_active(true)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if zone != null else PackedStringArray(["Falta la zona (GroundZone) a la que acompaña."])


func _physics_process(_delta: float) -> void:
	ticks += 1
	if zone.is_authority():
		synced_ticks = ticks
	elif absi(synced_ticks - ticks) > resync_ticks:
		ticks = synced_ticks
		_spiral = null
	if _spiral == null:
		_spiral = BoreSpiral.new(Vector2(zone.points[0].x, zone.points[0].z), zone.spell.effect_range_m, scribe_speed * zone.spell.speed_m_s / MatchClock.TICKS_PER_SECOND_F)
		_spiral.skip(ticks - 1)
	place = _spiral.advance()
	if _spiral.arrived or zone.cancelled:
		_stop()
		return
	if not _draws:
		return
	var ground := _land.height_at(place.x, place.y) if _land != null else NAN
	global_position = Vector3(place.x, global_position.y if is_nan(ground) else ground, place.y)
	if scar != null:
		scar.mark()


func _stop() -> void:
	set_physics_process(false)
	for emitter in emitters:
		emitter.set_active(false)
	if sound != null:
		sound.set_active(false)
	if look != null:
		look.visible = false
