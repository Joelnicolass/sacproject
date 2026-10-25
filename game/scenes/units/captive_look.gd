@tool
class_name CaptiveLook
extends Node

## How a creature that a doctor holds looks. If its model has a physical skeleton it dangles as a rag doll (RagdollDriver); if
## not it plays the clips rise, held and thrash. A pumped corpse stays where it fell until the doctor takes it. It only listens
## to the body's mode and never writes to the simulation: the only thing it writes is `captive_role`, which nothing in the sim reads.
## What to show for each change of mode is CaptiveRules.

## The clips of a held creature, in order (sacengine state.d:8200-8223, 14329-14342): it rises, floats into the thrash and
## thrashes until it is let go. A revived corpse only rises.
const SEQUENCE: PackedStringArray = ["rise", "held", "thrash"]

## The unit that is held.
@export var body: UnitBody
## How a body with a physical skeleton hangs and is let go.
@export var ragdoll: RagdollDriver
## How a body with no rag doll stands up where it lay.
@export var tipping: TippingFall
## The model that is drawn and faded.
@export var visual: BodyVisual
## The body's clip player: it tells which clips the model has and when a loop ends.
@export var clip_pose: ClipPlayback
## The unit's light: comes back when the creature stands up.
@export var light: ActorLight
## true (the default): a model with a physical skeleton and a hang bone hangs as a rag doll. Off: every model uses its clips.
@export var hangs := true
## Seconds a creature that stands up or hangs out of a corpse takes to appear.
@export_range(0.0, 3.0, 0.05, "suffix:s") var appear_s := 0.6


func _ready() -> void:
	if Engine.is_editor_hint() or body == null:
		return
	body.mode_changed.connect(_apply)
	if ragdoll != null:
		ragdoll.bound.connect(func(_available: bool) -> void: _apply(body.mode, body.mode))
	if clip_pose != null:
		clip_pose.clip_looped.connect(_on_clip_looped)
	_apply(body.mode, body.mode)


func _apply(was: UnitBody.Mode, now: UnitBody.Mode) -> void:
	var look := CaptiveRules.on_change(was, now, _can_hang(), _lies_as_ragdoll())
	match look:
		CaptiveRules.Look.HANG, CaptiveRules.Look.HANG_APPEAR:
			body.captive_role = ""
			ragdoll.set_pose(RagdollDriver.Pose.HANG)
			if look == CaptiveRules.Look.HANG_APPEAR:
				_appear()
		CaptiveRules.Look.CLIPS:
			_drop_ragdoll()
			body.captive_role = _first_clip(0)
		CaptiveRules.Look.STAND_APPEAR:
			_stand_up(now)
		CaptiveRules.Look.LET_GO:
			_drop_ragdoll()
			body.captive_role = ""
		CaptiveRules.Look.KEEP_LYING:
			body.captive_role = ""
		CaptiveRules.Look.NONE:
			if now != UnitBody.Mode.HELD and now != UnitBody.Mode.REVIVING:
				body.captive_role = ""


func _can_hang() -> bool:
	return hangs and ragdoll != null and ragdoll.can_hang()


func _lies_as_ragdoll() -> bool:
	return hangs and ragdoll != null and ragdoll.pose() == RagdollDriver.Pose.FALL


## Hands the model back to its clips (a rag doll that hangs or lies; nothing when it does not).
func _drop_ragdoll() -> bool:
	if ragdoll == null or ragdoll.pose() == RagdollDriver.Pose.OFF:
		return false
	ragdoll.set_pose(RagdollDriver.Pose.OFF)
	return true


## A pumped corpse stands up where it lies (or, let go alive, in its place) and appears out of thin air.
func _stand_up(now: UnitBody.Mode) -> void:
	if _drop_ragdoll() and clip_pose != null:
		clip_pose.play("idle", true)
	if tipping != null:
		tipping.stand_up(false)
	_appear()
	if light != null:
		light.set_lit(true, appear_s)
	body.captive_role = _first_clip(0) if now == UnitBody.Mode.REVIVING else ""


func _appear() -> void:
	visual.set_fade(1.0)
	visual.fade_to(0.0, appear_s)


## A clip of the sequence ended: the next one that the model has (rise -> held -> thrash). The last loops; a revived corpse
## stands after its rise.
func _on_clip_looped(role: String) -> void:
	if role != body.captive_role or role == SEQUENCE[SEQUENCE.size() - 1]:
		return
	if body.is_held():
		body.captive_role = _first_clip(SEQUENCE.find(role) + 1)
	else:
		body.captive_role = ""


## The first role of the sequence from `from` on that the model has a clip for ("" when none). A revived corpse only rises.
func _first_clip(from: int) -> String:
	var last := SEQUENCE.size() if body.is_held() else 1
	for i in range(from, last):
		if clip_pose != null and clip_pose.has_role(SEQUENCE[i]):
			return SEQUENCE[i]
	return ""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for socket: String in ["body", "ragdoll", "tipping", "visual", "clip_pose", "light"]:
		if get(socket) == null:
			warnings.append("Assign `%s`." % socket)
	return warnings
