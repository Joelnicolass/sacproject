class_name SpellCarrier
extends SpellProjectile

## Something a spell sends to a soul and back (the Soul Mole's rock, the Soul Wind's funnel). It walks the ground from the wizard to the
## soul in half the trip, turns there, and comes back to the wizard in the other half. The children say what it does on the way:
## SoulFetch takes the soul at the turn, a CarrierPulse hurts or stuns what it passes near, the look is whatever else hangs from it.
## The server (or solo) moves it and replicates its position; a client only draws. It ends when the trip is over, when the soul is
## gone (taken by another wizard, revived, burst) or when the spell is cancelled. It does not know what it carries nor who is near.
## Ref: sacengine SoulMole, SoulWind (state.d:3109, 17938, 18916).

## The turn: it stands on the soul and the soul is about to follow it. Server only.
signal reached(soul: Soul)
## The trip is over, whatever the reason. Server only; the node frees itself right after.
signal ended

## Ticks of the whole trip: the same going and coming.
@export_range(4, 3600, 4) var roundtrip_ticks := 540
## How far the trip bends to the side, as a part of the distance to the soul.
@export_range(0.0, 2.0, 0.05) var bend := 0.75
@export_flags_3d_physics var ground_mask := 1

## True once the casting time is over: from then on the children may hurt (a pulse waits for it).
var armed := false
## Ticks walked so far.
var frame := 0
var wizard_path := NodePath()
var soul_path := NodePath()
var from_slot := 0
## The spell's damage, for a pulse that hurts.
var damage := 0.0

var _start := Vector3.ZERO
var _turn := Vector3.ZERO
var _side := Vector3.ZERO
var _ended := false


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	wizard_path = NodePath(str(data.get("caster", "")))
	soul_path = NodePath(str(data.get("target", "")))
	from_slot = int(data.get("slot", 0))
	damage = float(data.get("damage", 0.0))
	_start = position
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = PackedStringArray([".:position"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


func _ready() -> void:
	if not multiplayer.is_server():
		set_physics_process(false)


func wizard() -> Node3D:
	return get_node_or_null(wizard_path) as Node3D if not wizard_path.is_empty() else null


func soul() -> Soul:
	return get_node_or_null(soul_path) as Soul if not soul_path.is_empty() else null


## Server or solo. The casting time is over: the children may act.
func arm() -> void:
	armed = true


## Server or solo. The spell was cancelled (the wizard died while casting): nothing walks, the soul is left alone.
func stop() -> void:
	_finish()


func _physics_process(_delta: float) -> void:
	if _ended:
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
