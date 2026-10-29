@tool
class_name FrogHop
extends Node

## How a frog of Rain of Frogs moves once it is down: it sits half a second, jumps toward the
## closest creature in range (or anywhere, if none), and sits again, up to seven jumps; in the
## middle of the seventh it bursts. It asks its ZoneDrop to fly (launch) and to end (finish); it
## never moves it. It does not stick to anybody (FrogCling) nor draw (FrogLook). Server (or solo)
## only.

@export var drop: ZoneDrop
@export_range(0.0, 5.0, 0.05, "suffix:s") var sit_s := 0.5
@export_range(1, 20) var max_jumps := 7
## After its last jump starts, the frog bursts this long into it.
@export_range(0.0, 3.0, 0.0001, "suffix:s") var burst_after_s := 0.3333
@export_group("Jump")
## Toward a creature: speed along the line (plus a wobble), and the cap of the upward speed.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var toward_speed := 4.5
@export_range(0.0, 5.0, 0.1, "suffix:m/s") var wobble := 0.5
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var up_cap := 10.0
## With nobody in range: this fast sideways and this fast up.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var aimless_speed := 5.0
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var aimless_up := 10.0
@export var groups: Array[StringName] = [&"wizard", &"unit"]

var _sat := 0
var _jumps := 0
var _air := 0
var _rng: RandomNumberGenerator


func _ready() -> void:
	set_physics_process(false)
	if Engine.is_editor_hint() or drop == null or not multiplayer.is_server():
		return
	_rng = MatchSeed.rng(["frog", String(drop.name)])
	drop.landed.connect(_on_landed)


func _on_landed(_at: Vector3) -> void:
	_sat = 0
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if drop.status == ZoneDrop.Status.RESTING:
		_sat += 1
		if _sat > MatchClock.ticks_for(sit_s):
			_jump()
	elif drop.status == ZoneDrop.Status.FLYING and _jumps > 0:
		_air += 1
		if _jumps >= max_jumps and _air >= MatchClock.ticks_for(burst_after_s):
			drop.finish(null)


func _jump() -> void:
	_jumps += 1
	_air = 0
	var foe := _closest()
	var speed := Vector3.ZERO
	if foe != null:
		var line := BodyNudge.center(foe) - drop.global_position
		speed = toward_speed * line.normalized() + wobble * _direction()
		speed.y = minf(
			speed.y + 0.5 * drop.gravity_m_s2 * line.length() / maxf(speed.length(), 0.001), up_cap
		)
	else:
		speed = aimless_speed * _direction()
		speed.y = aimless_up
	drop.launch(speed)


func _closest() -> Node3D:
	var best: Node3D
	var best_d := INF
	for body in SplashDamage.bodies_within(
		get_tree(), drop.global_position, drop.effect_range, null, groups
	):
		var d := drop.global_position.distance_squared_to(BodyNudge.center(body))
		if d < best_d:
			best = body
			best_d = d
	return best


func _direction() -> Vector3:
	return Vector3(_rng.randfn(), _rng.randfn(), _rng.randfn()).normalized()


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if drop != null
		else PackedStringArray(["The frog (ZoneDrop) that hops is missing."])
	)
