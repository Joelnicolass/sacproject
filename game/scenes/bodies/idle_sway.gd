@tool
class_name IdleSway
extends Node

## A body that stands still breathes: while its clip player is on the idle role, `pivot` bobs up and down and leans a few
## degrees side to side; on any other role the motion eases out. Add it to a body whose idle clip is missing or a held pose
## (the Sac Doctor) and point `pivot` at the node that carries only the drawing (the BodyRig under the visual).
## It moves the pivot's local transform and nothing else: never the body, its collision or the simulation.
## Presentation only: the dedicated server draws nothing, so the node switches itself off there.

## The clip player of the body (BodyAnimator): its active role says when the body is idle.
@export var clip_player: ClipPlayback
## The drawing node that bobs and leans; its own local transform is the rest the motion adds to.
@export var pivot: Node3D
## The role that sways.
@export var idle_role := &"idle"
@export_group("Motion")
## Height of the bob from the rest (m).
@export_range(0.0, 0.2, 0.001, "or_greater") var bob_height_m := 0.02
## Seconds for one up-and-down breath.
@export_range(0.2, 10.0, 0.05, "or_greater") var bob_period_s := 2.4
## Lean to each side of upright (degrees).
@export_range(0.0, 10.0, 0.1) var sway_deg := 1.2
## Seconds for one full left-to-right-to-left lean.
@export_range(0.2, 20.0, 0.05, "or_greater") var sway_period_s := 4.8
## Seconds to ease the motion in or out when the role changes.
@export_range(0.0, 2.0, 0.01, "or_greater") var ease_s := 0.3

var _rest := Transform3D.IDENTITY
var _time := 0.0
var _weight := 0.0


func _ready() -> void:
	if Engine.is_editor_hint() or not BodyLook.loads_meshes() or pivot == null:
		set_process(false)
		return
	_rest = pivot.transform
	# Bodies made on the same frame do not breathe in step.
	_time = float(get_instance_id() % 1000) / 1000.0 * bob_period_s


func _process(delta: float) -> void:
	var idle := (
		clip_player != null
		and not clip_player.frozen
		and clip_player.active_role() == String(idle_role)
	)
	_weight = move_toward(_weight, 1.0 if idle else 0.0, delta / maxf(ease_s, 0.001))
	_time += delta
	var lift := bob_height_m * _weight * 0.5 * (1.0 - cos(_time * TAU / bob_period_s))
	var lean := deg_to_rad(sway_deg) * _weight * sin(_time * TAU / sway_period_s)
	pivot.transform = Transform3D(
		_rest.basis * Basis(Vector3.BACK, lean), _rest.origin + Vector3(0.0, lift, 0.0)
	)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if clip_player == null:
		out.append("Assign `clip_player` (the body's BodyAnimator).")
	if pivot == null:
		out.append("Assign `pivot` (the node that draws, e.g. the BodyRig).")
	return out
