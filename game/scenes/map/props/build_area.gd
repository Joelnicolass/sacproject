@tool
class_name BuildArea
extends CollisionShape3D

## The ground a tower cast on this manafount clears: a cylinder you size with the gizmo (only its
## radius counts). While the cast lasts, every live creature, wizard and doctor inside is pushed out
## along the ground, `push_mps` at `core_m` from the middle and less and less out to the edge; a
## building inside it refuses the cast (TowerRules.has_room). The shape is always off: it never
## collides, never feeds the navmesh and never blocks a path. It also tells its Ring what the armed
## preview says.
## Not: who may cast (StructureAction), how hard the push is at a distance (BodyNudge.push_speed),
## drawing the ring (BuildRing).

## Who a cast pushes, in this order (the result does not depend on the scene tree).
const PUSHED: Array[StringName] = [&"wizard", &"unit", &"doctor"]

## Metres from the middle where the push is `push_mps`; nearer it is stronger, farther weaker, 0 at
## the radius.
@export_range(0.0, 30.0, 0.5, "suffix:m") var core_m := 5.0
## Push at `core_m` (m/s).
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var push_mps := 5.0
## The wizard who casts is pushed too, like every other body (off: he stays where he stands).
@export var push_caster := true
## The ring on the ground that shows the area while a structure is armed.
@export var ring: BuildRing


func _enter_tree() -> void:
	disabled = true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not shape is CylinderShape3D:
		warnings.append(
			"BuildArea needs a CylinderShape3D: its radius is the area the tower clears."
		)
	if core_m >= radius_m():
		warnings.append("`core_m` has to be smaller than the cylinder's radius.")
	return warnings


## Metres from the middle the area reaches (the cylinder's radius, scaled as the node stands).
func radius_m() -> float:
	var cylinder := shape as CylinderShape3D
	if cylinder == null:
		return 0.0
	var scale_xz := global_transform.basis.get_scale() if is_inside_tree() else scale
	return cylinder.radius * maxf(scale_xz.x, scale_xz.z)


## The middle of the area on the ground.
func center() -> Vector3:
	return global_position if is_inside_tree() else position


## Server or solo, one physics tick: pushes every live body inside the radius out from the middle
## (BodyNudge.push: on the land, a petrified or frozen one stays). `caster` is skipped when
## push_caster is off. Returns how many moved.
func push_bodies(caster: Node3D = null) -> int:
	var radius := radius_m()
	var middle := center()
	var reach := AABB(middle - Vector3(radius, radius, radius), Vector3.ONE * radius * 2.0)
	var moved := 0
	for body in BodyNudge.bodies_in(get_tree(), reach, PUSHED):
		if body == caster and not push_caster:
			continue
		var away := BodyNudge.center(body) - middle
		var distance := away.length()
		if distance <= 0.001:
			continue
		var speed := BodyNudge.push_speed(distance, core_m, radius, push_mps)
		if speed > 0.0 and BodyNudge.push(body, away / distance * speed):
			moved += 1
	return moved


## The armed preview's answer for this fount: hidden, the cast would start, or refused. Calls go
## down to the ring.
func show_preview(state: BuildRing.State) -> void:
	if ring != null:
		ring.set_radius(radius_m())
		ring.show_state(state)
