class_name Vortex
extends Node3D

## The Vortick's vortex that throws bodies up.
## VortexImpact puts it in the shots' container where the shot burst; server (or solo) only, it lives
## `duration_s`·60 + 1 ticks. While frame < influence_share·duration·60 it touches every live creature and wizard whose
## box meets its own (±√2·radius on the ground plane, −¼·height to +height), with no side filter:
## - frame < catapult_s·60 and not thrown: catapult with `tangent_speed` along the circle and `lift_speed` up
##   (direction = (center − body).normalized·1.5 turned −90°);
## - thrown: the force field adds field·(−y−x, x−y) and `field` up per second, relative to the center,
##   only below `height`; vz ≥ `min_rise`; no gravity that tick.
## Effects run before creatures: physics priority −1.
## The swirl itself (particles) is not drawn yet: its FxBus puff is the shot's impact_fx.

@export var duration_s := 2.0
## The radius of the vortex; the impact writes it from the spell (the Vortick's shot: 2 m).
@export var radius := 2.0
## The height of the vortex.
@export var height := 4.0
@export_range(0.0, 1.0) var influence_share := 0.75
@export var catapult_s := 0.75
@export var tangent_speed := 1.5
@export var lift_speed := 2.5
## The force field factor (m/s² per m, and m/s² up).
@export var field := 5.5
@export var min_rise := 1.0

## The shooter's slot.
var side := -1
var _frame := 0


func _physics_process(_delta: float) -> void:
	var ticks := float(MatchClock.TICKS_PER_SECOND)
	if _frame < influence_share * duration_s * ticks:
		var diag := sqrt(2.0) * radius
		var area := AABB(
			global_position - Vector3(diag, 0.25 * height, diag),
			Vector3(2.0 * diag, 1.25 * height, 2.0 * diag)
		)
		for body in BodyNudge.bodies_in(get_tree(), area):
			_influence(body, ticks)
	_frame += 1
	if _frame > duration_s * ticks:
		set_physics_process(false)
		queue_free()


func _influence(body: Node3D, ticks: float) -> void:
	var tumbling := BodyNudge.tumbling_of(body)
	if tumbling == null:
		return
	var center := BodyNudge.center(body)
	if _frame < catapult_s * ticks and not tumbling.is_on():
		var toward := (
			Vector2(global_position.x - center.x, global_position.z - center.z).normalized()
			* tangent_speed
		)
		tumbling.catapult(Vector3(toward.y, lift_speed, -toward.x), side)
	if tumbling.is_on():
		var rel := center - global_position
		if rel.y <= height:
			tumbling.add_velocity(
				Vector3(field * (-rel.z - rel.x), field, field * (rel.x - rel.z)) / ticks
			)
		tumbling.velocity.y = maxf(tumbling.velocity.y, min_rise)
		tumbling.lift()
