class_name HandFx
extends Node

## The casting particle of a wizard, played at its hands while it casts. The hand points come from the BodyRig: the sockets of the
## model (HandL, HandR: BoneAttachment3D nodes placed in the editor) that the clip shows. A body with none gets the burst at its Center.
## The Caster (server) says which particle shows (`cast_fx_shown`, replicated); this node only draws it, on every peer. It is
## presentation: nothing here reads or writes the simulation, and a dedicated server (no meshes) plays nothing.
## Ref: RFC-023 (023d), sacengine animateCasting (state.d:16165-16195).

## Emits `cast_fx_changed(type_name)` and holds `cast_fx_shown` (Caster).
@export var caster: Caster
## The wizard's skeleton: where the hands are.
@export var rig: BodyRig
## Seconds between two bursts while the cast lasts (the first one is at once).
@export_range(0.05, 2.0, 0.05) var interval_s := 0.5
## Seconds the pose may take to arrive before the burst goes to the fallback point.
const POSE_WAIT_S := 0.3

var _type := ""
var _left := 0.0
var _waited := 0.0


func _ready() -> void:
	if not BodyCatalog.loads_meshes() or caster == null:
		set_process(false)
		return
	caster.cast_fx_changed.connect(_on_cast_fx_changed)
	_on_cast_fx_changed(caster.cast_fx_shown)


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
## the rest pose, which has no hands) waits for it instead of playing at the center.
func _burst() -> bool:
	var points := rig.hand_points() if rig != null else PackedVector3Array()
	if points.is_empty():
		if rig != null and rig.is_loaded() and _waited < POSE_WAIT_S:
			return false
		var body := get_parent() as Node3D
		if body == null:
			return false
		points.append(body.global_position + BodyFacts.of_body(body).center)
	for point in points:
		FxBus.play_puff(_type, point)
	return true
