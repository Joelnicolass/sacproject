@tool
class_name CarrierFall
extends Node

## The fall of Bovine Intervention's cow for its SpellCarrier: it is born buried at the cast point, and in `travel_s` it goes from there to the
## center of its target along an arc that peaks `peak_m` up (it says `arrived` when it is there), then it keeps falling and, going through the
## land, says `landed` and ends. The horizontal pace is the distance left over the ticks left (twice that until the last two ticks), so it always
## arrives on time, however the target runs. It does not hurt (TargetEffect on `arrived`, CarrierLanding on `landed`) and it does not draw.
## Server (or solo) only.
## Ref: sacengine updateBovineIntervention (state.d:21788-21819), BovineIntervention.travelTime / maxHeight (state.d:4162-4174).

## Below this under the void it is gone.
## Ref: sacengine gibDepth
const _VOID_DEPTH_M := 25.0

@export var carrier: SpellCarrier
@export_range(0.5, 60.0, 0.1, "suffix:s") var travel_s := 12.0
@export_range(0.0, 400.0, 1.0, "suffix:m") var peak_m := 200.0

var _target: Node3D
var _goal := Vector3.ZERO
var _start_y := 0.0
var _total := 1
var _tick := 0


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if carrier != null else PackedStringArray(["Falta el SpellCarrier."])


## Server or solo. The fall starts on the carrier's place (buried), aimed at `target`; the cow looks at it.
func begin(target: Node3D) -> void:
	_target = target
	_goal = _center()
	_start_y = carrier.global_position.y
	_total = maxi(1, MatchClock.ticks_for(travel_s))
	_tick = 0
	carrier.phase = SpellCarrier.Phase.FLYING
	var to := _goal - carrier.global_position
	carrier.rotation.y = atan2(to.x, to.z)


## One tick of the fall.
func step() -> void:
	_tick += 1
	var goal := _center()
	var left := _total - _tick
	var rel := 1.0 - float(left) / float(_total)
	var at := carrier.global_position
	at.y = goal.y * rel + _start_y * (1.0 - rel) + 4.0 * peak_m * rel * (1.0 - rel)
	if left > 0:
		var diff := Vector2(goal.x - at.x, goal.z - at.z) / float(left) * (2.0 if left >= 2 else 1.0)
		at.x += diff.x
		at.z += diff.y
	elif left == 0:
		at.x = goal.x
		at.z = goal.z
	carrier.global_position = at
	if left == 0:
		carrier.arrived.emit(_target if is_instance_valid(_target) else null)
	elif left < 0:
		_land(at)


## The center of the target while it lives; where it was after.
func _center() -> Vector3:
	if is_instance_valid(_target) and _target.is_inside_tree():
		_goal = BodyNudge.center(_target)
	return _goal


func _land(at: Vector3) -> void:
	var ground := GroundRay.surface_y(carrier, at, carrier.ground_mask, GroundRay.wizard_rids(get_tree()), NAN)
	if not is_nan(ground) and at.y < ground:
		carrier.landed.emit(Vector3(at.x, ground, at.z))
		carrier.stop()
	elif is_nan(ground) and at.y < -_VOID_DEPTH_M:
		carrier.stop()

