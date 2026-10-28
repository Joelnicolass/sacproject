class_name ZonePulse
extends Node

## The moments in which a zone does something to the bodies near it: `count` times, `every_s` apart, starting `first_s` into one phase of
## the zone. This base counts the moments and finds the bodies; what happens at each one is the work of its classes (ZoneBlast, ZoneFreeze,
## ZoneShatter). Server (or solo) only; a pulse draws nothing (the zone's look does, from the phase). A zone that was cancelled never pulses.

const BODY_GROUPS: Array[StringName] = [WizardBody.GROUP, UnitBody.GROUP]
## The original looks for bodies this far past the radius, because the ground under a zone can be uneven.
const CANDIDATE_MARGIN_M := 15.0

@export var zone: GroundZone
## The phase of the zone this pulse belongs to.
@export var phase := GroundZone.Phase.ACTIVE
## Seconds into the phase of the first moment.
@export_range(0.0, 60.0, 0.01, "suffix:s") var first_s := 0.0
## Seconds between two moments (0 = one tick apart).
@export_range(0.0, 60.0, 0.01, "suffix:s") var every_s := 0.0
@export_range(1, 64) var count := 1

var _done := 0


func _ready() -> void:
	set_physics_process(zone != null and zone.is_authority() and not Engine.is_editor_hint())


func _physics_process(_delta: float) -> void:
	if zone.cancelled or zone.phase != phase:
		return
	var first := MatchClock.ticks_for(first_s)
	var gap := maxi(1, MatchClock.ticks_for(every_s))
	while _done < count and zone.phase_ticks >= first + _done * gap:
		_fire(_done)
		_done += 1


## One moment. `step` counts from 0.
func _fire(_step: int) -> void:
	pass


## The creatures and wizards whose box is within `radius` of `center`.
func bodies_near(center: Vector3, radius: float) -> Array[Node3D]:
	return SplashDamage.bodies_within(get_tree(), center, radius, null, BODY_GROUPS)


func is_ally(body: Node3D) -> bool:
	return (
		SideRelations.stance(zone.from_slot, int(body.get("owner_slot")))
		== SideRelations.Stance.ALLY
	)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if zone != null
		else PackedStringArray(["The zone (GroundZone) it belongs to is missing."])
	)
