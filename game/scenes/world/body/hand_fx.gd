class_name HandFx
extends Node

## RFC-023 (023d): the casting particle of a wizard, played at its hands while it casts. sacengine animateCasting puts the
## particle at both hands of the spellcast pose (state.d:16165-16195, a hand on the root bone is NaN and gets none); here the
## hand points come from the BodyRig, whose BoneAttachment3D sockets follow the skeleton clip by clip.
## The Caster (server) says which particle shows (`cast_fx_shown`, replicated); this node only draws it, on every peer. It is
## presentation: nothing here reads or writes the simulation, and a dedicated server (no meshes) plays nothing.

## Emits `cast_fx_changed(type_name)` and holds `cast_fx_shown` (Caster).
@export var caster: Node
## The wizard's skeleton: where the hands are.
@export var rig: BodyRig
## Seconds between two bursts while the cast lasts (the first one is at once).
@export_range(0.05, 2.0, 0.05) var interval_s := 0.5
## Metres over the wizard's feet where the burst goes when the pose has no hands (a model without skeleton).
@export var fallback_height := 1.0

## Seconds the pose may take to arrive before the burst goes to the fallback point.
const POSE_WAIT_S := 0.3

var _type := ""
var _left := 0.0
var _waited := 0.0


func _ready() -> void:
	if not BodyCatalog.loads_meshes() or caster == null:
		set_process(false)
		return
	caster.connect("cast_fx_changed", _on_cast_fx_changed)
	_on_cast_fx_changed(str(caster.get("cast_fx_shown")))


func _process(delta: float) -> void:
	if _type.is_empty():
		return
	_left -= delta
	if _left > 0.0:
		return
	_waited += delta
	if _burst():
		_left = interval_s
		_waited = 0.0


func _on_cast_fx_changed(type_name: String) -> void:
	_type = type_name
	_left = 0.0
	_waited = 0.0
	set_process(not type_name.is_empty())


## true when something played. A skeletal wizard whose spellcast pose has not arrived yet (the body is still blending in from
## the rest pose, which has no hands) waits for it instead of playing at the feet.
func _burst() -> bool:
	var points := rig.hand_points() if rig != null else PackedVector3Array()
	if points.is_empty():
		if rig != null and rig.is_loaded() and not _casting_pose() and _waited < POSE_WAIT_S:
			return false
		var body := get_parent() as Node3D
		if body == null:
			return false
		points.append(body.global_position + Vector3.UP * fallback_height)
	for point in points:
		FxBus.play(_type, point)
	return true


func _casting_pose() -> bool:
	var role := rig.active_role()
	return role == "cast" or role == "cast_run"
