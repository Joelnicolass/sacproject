@tool
class_name CarrierHunt
extends Node

## The hunt of Death for its SpellCarrier. While the wizard casts it only stands there (the look rises out of the land); when the casting ends it
## looks for the closest creature of any side that is not a wizard, turns to it, walks to it, strikes (`arrived` at the blow, TargetEffect does the
## killing) and goes on to the next, until it has struck `SpellType.count` of them or the spell's duration is over; then it leaves. Each tick it
## looks again, so it changes its mind if something comes closer. It does not kill (TargetEffect) and it does not draw (the look follows `phase`:
## CASTING, FLYING = walking, STRIKING, LEAVING). Server (or solo) only.
## Ref: sacengine updateDeath, Death (state.d:4262-4298, 22153-22274).

@export var carrier: SpellCarrier
@export var groups: Array[StringName] = [&"unit"]
@export_group("Body")
@export_range(1.0, 30.0, 0.5, "suffix:m") var height_m := 12.0
@export_range(0.1, 12.0, 0.1, "suffix:rad/s") var turn_rate := PI
@export_group("Reach")
## It stops walking nearer than the prey's size plus `move_radius_m`, strikes within `attack_radius_m`, and the blow lands within `hit_radius_m`.
@export_range(0.0, 10.0, 0.1, "suffix:m") var move_radius_m := 2.0
@export_range(0.0, 10.0, 0.1, "suffix:m") var attack_radius_m := 4.0
@export_range(0.0, 20.0, 0.1, "suffix:m") var hit_radius_m := 6.0
@export_group("Times")
@export_range(0.1, 5.0, 0.01, "suffix:s") var walk_s := 1.0
@export_range(0.1, 10.0, 0.01, "suffix:s") var attack_s := 1.7
@export_range(0.1, 10.0, 0.01, "suffix:s") var hit_s := 1.1833
@export_range(0.1, 5.0, 0.01, "suffix:s") var leave_s := 1.0
@export var swing_fx: ParticleType

var _released := false
var _pausing := false
var _age := 0
var _frame := 0
var _kills := 0
var _lifetime := 0


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if carrier != null else PackedStringArray(["Falta el SpellCarrier."])

## Server or solo. The cast started: it appears where it is and looks where the wizard looks, for `cast_ticks`.
func begin(wizard: Node3D, cast_ticks: int) -> void:
	_lifetime = MatchClock.ticks_for(carrier.spell.duration_s) + cast_ticks if carrier.spell != null else cast_ticks
	carrier.phase = SpellCarrier.Phase.CASTING
	carrier.rotation.y = wizard.rotation.y


## Server or solo. The casting ended: it starts to hunt.
func release() -> void:
	_released = true
	carrier.phase = SpellCarrier.Phase.FLYING


func step() -> void:
	_age += 1
	match carrier.phase:
		SpellCarrier.Phase.FLYING, SpellCarrier.Phase.STRIKING:
			_hunt()
		SpellCarrier.Phase.LEAVING:
			_frame += 1
			if _frame >= MatchClock.ticks_for(leave_s):
				carrier.stop()


func _hunt() -> void:
	var prey := _closest()
	var ready := false
	var able := false
	var striking := carrier.phase == SpellCarrier.Phase.STRIKING
	var still := striking and _frame >= MatchClock.ticks_for(hit_s)
	if prey != null:
		var to := BodyNudge.center(prey) - carrier.global_position
		var size := prey.global_transform.basis.get_scale().length()
		var angle := wrapf(atan2(to.x, to.z) - carrier.rotation.y, -PI, PI)
		if not still:
			carrier.rotation.y += signf(angle) * minf(absf(angle), turn_rate / MatchClock.TICKS_PER_SECOND_F)
			_pausing = _pausing and absf(angle) >= TAU / 16.0
		ready = to.length() < size + attack_radius_m
		able = to.length() < size + hit_radius_m
		_pausing = _pausing and not ready
		if to.length() >= size + move_radius_m and not still and not _pausing:
			_walk(to.normalized() * carrier.speed / MatchClock.TICKS_PER_SECOND_F)
	_frame += 1
	if striking:
		_blow(prey, able, ready)
	elif _frame >= MatchClock.ticks_for(walk_s):
		_frame = 0
		if _over():
			_leave()
	if not striking and ready and carrier.phase == SpellCarrier.Phase.FLYING:
		_strike()


func _blow(prey: Node3D, able: bool, ready: bool) -> void:
	if _frame == MatchClock.ticks_for(hit_s) and prey != null and able:
		carrier.arrived.emit(prey)
		if not is_instance_valid(prey) or not prey.is_inside_tree() or Health.of(prey).is_dead():
			_kills += 1
			_pausing = true
	if _frame >= MatchClock.ticks_for(attack_s):
		_frame = 0
		if _over():
			_leave()
		elif ready:
			_strike()
		else:
			carrier.phase = SpellCarrier.Phase.FLYING


func _strike() -> void:
	_frame = 0
	carrier.phase = SpellCarrier.Phase.STRIKING
	if swing_fx != null:
		FxBus.broadcast(swing_fx.bus_name(), _chest())


func _leave() -> void:
	_frame = 0
	carrier.phase = SpellCarrier.Phase.LEAVING


func _chest() -> Vector3:
	return carrier.global_position + Vector3(0.0, height_m * 0.5, 0.0)


func _over() -> bool:
	var most := carrier.spell.count if carrier.spell != null else 0
	return _age >= _lifetime or (most > 0 and _kills >= most)


## It walks over the land, never under it.
func _walk(step: Vector3) -> void:
	var at := carrier.global_position + step
	var ground := GroundRay.surface_y(carrier, at, carrier.ground_mask, GroundRay.wizard_rids(get_tree()), NAN)
	carrier.global_position = at if is_nan(ground) else Vector3(at.x, maxf(at.y, ground), at.z)


## The closest creature of any side that is not a wizard, from half its height over its feet.
func _closest() -> Node3D:
	var from := _chest()
	var best: Node3D = null
	var best_d := INF
	for group in groups:
		for node in get_tree().get_nodes_in_group(group):
			if not TargetRules.is_valid_foe_of(-1, node, null, false) or node.is_in_group(&"wizard"):
				continue
			var d := from.distance_squared_to(BodyNudge.center(node as Node3D))
			if d < best_d:
				best_d = d
				best = node as Node3D
	return best
