class_name RagdollCell
extends Node3D

## RFC-055 055a-5, debug only: one body of the ragdoll gallery. The look hangs from a Hook (a plain Node3D the gallery moves, like a doctor
## moves a captive) and the real RagdollDriver rules its physical skeleton. It measures the bones; it never edits a model.
## What it does not do: decide the scenario (the gallery) or judge the numbers (ragdoll_metrics.gd).

const METRICS := preload("res://debug/bodies/ragdoll_metrics.gd")

@onready var hook: Node3D = %Hook
@onready var driver: RagdollDriver = %Driver

var model: BodyModel
## Size of the standing body: the longest side of its rest pose (m).
var ref_m := 1.0
var rest := PackedVector3Array()
var parents := PackedInt32Array()
var _anchor := -1
var _anchor_local := Vector3.ZERO


## Instances `look` under the Hook in its idle pose and binds the driver. False when the model has no ragdoll.
func load_look(look: PackedScene) -> bool:
	var node := look.instantiate() as BodyLook
	hook.add_child(node)
	model = node.model
	if model == null or model.ragdoll == null:
		return false
	model.preview("idle")
	model.tree().advance(0.3)
	model.tree().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton := model.skeleton()
	skeleton.force_update_all_bone_transforms()
	driver.bind_model(model)
	for bone in skeleton.get_bone_count():
		parents.append(skeleton.get_bone_parent(bone))
	rest = points()
	ref_m = maxf(METRICS.longest_side(rest), 0.3)
	_anchor = model.hang_bone.get_bone_id() if model.hang_bone != null else -1
	_anchor_local = hook.to_local(rest[_anchor]) if _anchor >= 0 else Vector3.ZERO
	return true


## The look scene of every creature and wizard body, once each (a tool or a gallery asks; the game never does).
static func all_looks() -> Array[PackedScene]:
	var bodies: Array[PackedScene] = []
	for type: CreatureType in GameData.all_creatures():
		bodies.append(type.body)
	for wizard: WizardType in GameData.wizards():
		bodies.append(wizard.body)
	var out: Array[PackedScene] = []
	for body in bodies:
		var look := BodyLook.of_body(body)
		if look != null and not out.has(look):
			out.append(look)
	return out


## World position of every bone of the skeleton.
func points() -> PackedVector3Array:
	var skeleton := model.skeleton()
	var out := PackedVector3Array()
	for bone in skeleton.get_bone_count():
		out.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)
	return out


## Adds to `m` the worst anchor error and stretch seen so far (one call per tick while the Hook moves).
func track_hang(m: Dictionary) -> void:
	var now := points()
	var error := METRICS.anchor_error_m(now[_anchor], hook.to_global(_anchor_local))
	m["anchor_error_m"] = maxf(m.get("anchor_error_m", 0.0), error)
	m["stretch_ratio"] = maxf(m.get("stretch_ratio", 1.0), METRICS.stretch_ratio(rest, now, parents))
	m["nan"] = m.get("nan", false) or METRICS.has_nan(now)


## The rest of a hang: speed since `before` (the points `dt` seconds ago), extent and how far it hangs under the anchor.
func end_hang(m: Dictionary, before: PackedVector3Array, dt: float) -> void:
	var now := points()
	m["max_speed"] = METRICS.max_speed(before, now, dt)
	m["extent_ratio"] = METRICS.extent_ratio(now, ref_m)
	m["drop_ratio"] = METRICS.drop_ratio(now, now[_anchor].y, ref_m)
	m["nan"] = m.get("nan", false) or METRICS.has_nan(now)


## The numbers of a fall that started with the hips at `start`.
func end_fall(m: Dictionary, start: Vector3) -> void:
	var now := points()
	m["top_ratio"] = METRICS.top_ratio(now, global_position.y, ref_m)
	m["drift_m"] = METRICS.drift_m(start, now[0])
	m["frozen"] = not driver.is_running()
	m["nan"] = METRICS.has_nan(now)
