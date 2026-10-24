class_name SpellCarrier
extends SpellProjectile

## Something a spell sends on a trip (one piece for all of them; `motion` says which trip). SOUL_TRIP (the Soul Mole's rock, the Soul Wind's
## funnel): it walks the ground from the wizard to a soul in half the trip, turns there, and comes back in the other half. GUIDED
## (Dragonfire's dragon): it climbs a spiral around the wizard while he casts, then flies to its target (GuidedFlight) and asks its
## `on_arrive` (a CarrierArrive) what to do on arriving. The children say what it does on the way: SoulFetch takes the soul at the turn,
## a CarrierPulse hurts or stuns what it passes near, a DragonArrive burns and picks the next target, the look is whatever else hangs from it.
## The server (or solo) moves it and replicates it; a client only draws. It ends when the trip is over, when the soul is gone or when the
## spell is cancelled. It does not know what it carries nor who is near.
## Ref: sacengine SoulMole, SoulWind (state.d:3109, 17938, 18916).

## The turn: it stands on the soul and the soul is about to follow it. Server only.
signal reached(soul: Soul)
## The trip is over, whatever the reason. Server only; the node frees itself right after.
signal ended

enum Motion { SOUL_TRIP, GUIDED }
enum Phase { WAITING, CASTING, FLYING, SHRINKING }

@export var motion := Motion.SOUL_TRIP
## Ticks of the whole trip: the same going and coming.
@export_range(4, 3600, 4) var roundtrip_ticks := 540
## How far the trip bends to the side, as a part of the distance to the soul.
@export_range(0.0, 2.0, 0.05) var bend := 0.75
@export_flags_3d_physics var ground_mask := 1
@export_group("Guided")
## What it does on its way and on arriving (see CarrierArrive).
@export var on_arrive: CarrierArrive
@export_range(0.1, 12.0, 0.1, "suffix:rad/s") var turn_rate := PI
## Never lower than this over the land; arrived when its center is `arrive_distance_m` from the target's.
@export_range(0.0, 5.0, 0.1, "suffix:m") var flying_height_m := 1.0
@export_range(0.1, 3.0, 0.05, "suffix:m") var arrive_distance_m := 0.75
@export_range(0.1, 5.0, 0.1, "suffix:s") var shrink_s := 1.0
## It climbs this far over the top of the wizard's box while he casts.
@export_range(0.0, 10.0, 0.1, "suffix:m") var cast_height_m := 4.0

## True once the casting time is over: from then on the children may hurt (a pulse waits for it).
var armed := false
## Ticks walked so far.
var frame := 0
var wizard_path := NodePath()
var soul_path := NodePath()
var from_slot := 0
## The spell's damage, for a pulse that hurts.
var damage := 0.0
var speed := 0.0
var damage_range := 0.0
var phase := Phase.WAITING

var _start := Vector3.ZERO
var _turn := Vector3.ZERO
var _side := Vector3.ZERO
var _ended := false
var flight: GuidedFlight


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	wizard_path = NodePath(str(data.get("caster", "")))
	soul_path = NodePath(str(data.get("target", "")))
	from_slot = int(data.get("slot", 0))
	damage = float(data.get("damage", 0.0))
	speed = float(data.get("speed", 0.0))
	damage_range = float(data.get("damage_range", 0.0))
	_start = position
	if motion == Motion.GUIDED:
		flight = GuidedFlight.new(self)
		scale = Vector3.ONE * 0.01
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = PackedStringArray([".:position", ".:rotation", ".:scale"] if motion == Motion.GUIDED else [".:position"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


func _ready() -> void:
	set_physics_process(multiplayer.is_server() and motion == Motion.SOUL_TRIP)


func wizard() -> Node3D:
	return get_node_or_null(wizard_path) as Node3D if not wizard_path.is_empty() else null


func soul() -> Soul:
	return get_node_or_null(soul_path) as Soul if not soul_path.is_empty() else null


## Guided, server or solo: the cast started; the carrier follows `caster` for `cast_ticks` ticks and tells its `on_arrive`.
func begin(caster: Node3D, spell: SpellType, target: Node3D, point: Vector3, cast_ticks: int) -> void:
	flight.begin(caster, target, point, cast_ticks)
	if on_arrive != null:
		on_arrive.begin(self, caster, spell, target)


## Server or solo. The casting time is over: the children may act (a guided carrier is let go toward `target`).
func arm(target: Node3D = null) -> void:
	armed = true
	if flight != null:
		flight.release(target)
		if on_arrive != null:
			on_arrive.released(self, flight.target)


## Server or solo. The spell was cancelled (the wizard died while casting): nothing walks, the soul is left alone.
func stop() -> void:
	_finish()


func _physics_process(_delta: float) -> void:
	if _ended:
		return
	if flight != null:
		flight.step()
		return
	var leg := roundtrip_ticks / 2
	var target := soul()
	var owner_body := wizard()
	if target == null or owner_body == null or not (target.state == Soul.State.NORMAL or target.state == Soul.State.EMERGING):
		_finish()
		return
	frame += 1
	if frame == leg + 1:
		_turn = global_position
		reached.emit(target)
	var soul_at := target.global_position
	if frame == 1:
		_side = CarrierPath.side_velocity(_start, soul_at, bend)
	if frame <= leg:
		global_position = _grounded(CarrierPath.out_at(_start, soul_at, _side, frame, leg))
	else:
		global_position = _grounded(CarrierPath.back_at(_turn, owner_body.global_position, _side, frame - leg, leg))
	if frame >= roundtrip_ticks:
		_finish()


func _finish() -> void:
	if _ended:
		return
	_ended = true
	set_physics_process(false)
	ended.emit()
	queue_free()


## The same place, on the ground (a carrier walks it).
func _grounded(at: Vector3) -> Vector3:
	var y := GroundRay.surface_y(self, at, ground_mask, GroundRay.wizard_rids(get_tree()), NAN)
	return at if is_nan(y) else Vector3(at.x, y, at.z)
