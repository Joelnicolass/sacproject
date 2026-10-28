class_name HandFx
extends Node

## The casting particle of a wizard, played at its hands while it casts. The hand points come from
## the BodyRig: the sockets of the model (HandL, HandR: BoneAttachment3D nodes placed in the editor)
## that the clip shows. A body with none gets the burst at its Center. The Caster says which
## particle shows (`cast_changed`, from its replicated `cast_fx_shown`); this node only draws it, on
## every peer. It is presentation: nothing here reads or writes the simulation, and a dedicated
## server (no meshes) plays nothing.

## Seconds the pose may take to arrive before the burst goes to the fallback point.
const POSE_WAIT_S := 0.3

## Emits `cast_changed(casting, fx)`; `cast_fx()` is the particle showing now.
@export var caster: Caster
## The wizard's skeleton: where the hands are.
@export var rig: BodyRig
## Seconds between two bursts while the cast lasts (the first one is at once).
@export_range(0.05, 2.0, 0.05) var interval_s := 0.5

var _type: ParticleType
var _left := 0.0
var _waited := 0.0


func _ready() -> void:
	if not BodyLook.loads_meshes() or caster == null:
		set_process(false)
		return
	caster.cast_changed.connect(_on_cast_changed)
	_on_cast_changed(caster.is_casting(), caster.cast_fx())


func _process(delta: float) -> void:
	if _type == null:
		return
	_left -= delta
	if _left > 0.0:
		return
	_waited += delta
	if _burst():
		_left = interval_s
		_waited = 0.0


func _on_cast_changed(_casting: bool, fx: ParticleType) -> void:
	_type = fx
	_left = 0.0
	_waited = 0.0
	set_process(fx != null)


## true when something played. A skeletal wizard whose spellcast pose has not arrived yet (the body
## is still blending in from the rest pose, which has no hands) waits for it instead of playing at
## the center.
func _burst() -> bool:
	var points := rig.hand_points() if rig != null else PackedVector3Array()
	if points.is_empty():
		if rig != null and rig.is_loaded() and _waited < POSE_WAIT_S:
			return false
		var body := get_parent() as Node3D
		if body == null:
			return false
		points.append(BodyFacts.point(body, BodyFacts.Socket.CENTER))
	for point in points:
		FxBus.puff(_type, point)
	return true
