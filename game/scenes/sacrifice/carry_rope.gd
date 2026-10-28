@tool
class_name CarryRope
extends Node3D

## What joins a Sac Doctor to the creature it carries: a rope (`tether`) from the tip of the needle
## to the center of the creature's ring, and sparks at the tip. The needle is a node of the doctor's
## model (BodyModel.tool_socket, `Needle/Tip` in sac_doctor_model.tscn): move it there with the
## gizmo. Without one the rope starts at this node's own origin and a warning says so once. Local
## presentation on every peer, drawn from replicated state only: `doctor.carried` (the creature's
## path) and the creature's own ring (CaptiveRing.ring(), which exists while it is held). It changes
## no simulation. The dedicated server draws nothing. Remove the node from doctor.tscn to switch it
## off.

@export var doctor: DoctorBody
## The rig that wears the doctor's model: it hands out the needle tip (BodyRig.tool_socket).
@export var rig: BodyRig
@export var tether: Tether
@export_group("Needle sparks")
## Sparks at the needle tip (scenes/fx/effects/needle.tres), drawn by FxBus from its pool (the
## type's `pool_max`). Empty = none.
@export var spark_type: ParticleType
## Seconds between bursts of `spark_count`. Bursts of 4 every 1/30 s give about 120 sparks per
## second.
@export_range(0.01, 1.0, 0.0001, "suffix:s") var spark_period_s := 0.0333

var _spark_left := 0.0
var _warned := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not BodyLook.loads_meshes():
		set_process(false)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if doctor == null:
		warnings.append("Assign to `doctor` the DoctorBody that carries the creature.")
	if rig == null:
		warnings.append(
			"Assign to `rig` the doctor's BodyRig: the needle tip comes from its model."
		)
	if tether == null:
		warnings.append("Assign to `tether` the rope (scenes/fx/tether.tscn).")
	return warnings


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or doctor == null or tether == null:
		return
	var portal := _portal()
	if portal == null:
		tether.end = null
		return
	var needle := _needle()
	tether.start = needle
	tether.end = portal
	_spark(delta, needle)


## The ring of the creature this doctor carries, or null.
func _portal() -> Node3D:
	if doctor.carried.is_empty():
		return null
	var creature := doctor.get_node_or_null(doctor.carried) as UnitBody
	if creature == null:
		return null
	var captive := Captive.of(creature)
	var ring := CaptiveRing.of(creature)
	if captive == null or ring == null or not captive.is_held():
		return null
	return ring.ring()


## The tip of the needle in the model; this node itself when the model has none (it warns once).
func _needle() -> Node3D:
	var socket: Node3D = rig.tool_socket() if rig != null else null
	if socket == null and not _warned:
		_warned = true
		push_warning(
			(
				# gdlint: ignore=max-line-length
				"CarryRope: the model of %s has no tool_socket (BodyModel.tool_socket): the rope starts at the doctor's origin."
				% doctor.name
			)
		)
	return socket if socket != null else self


func _spark(delta: float, needle: Node3D) -> void:
	if spark_type == null:
		return
	_spark_left -= delta
	if _spark_left > 0.0:
		return
	_spark_left = spark_period_s
	# A pooled burst on this peer only (every peer draws its own from `doctor.carried`); the sparks
	# stay where they were born.
	FxBus.play(
		spark_type, needle.global_position, (needle.global_basis * tether.start_axis).normalized()
	)
