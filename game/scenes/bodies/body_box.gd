class_name BodyBox
extends RefCounted

## The size of a body as the others see it: half the width of its box (the avoidance radius, the
## formation spacing and the trample radius) and its height. Both come from the body scene it wears
## (BodyFacts), the same for the avoidance agent, Orders and the melee gap. The bodies do not push
## each other by physics: BodyAvoidance steers them apart.


## Half the box width: the larger of the footprint radius and the reach of the body.
static func half_size(body: Node3D) -> float:
	return BodyFacts.of_body(body).half_size_m()


static func body_height(body: Node3D) -> float:
	return BodyFacts.of_body(body).height_m


## (half width, height) of `body`.
static func box_of(body: Node3D) -> Vector2:
	return Vector2(half_size(body), body_height(body))


## Centre-to-centre distance at which two bodies rest apart: their radii. A walker asked to stop
## closer is steered away.
static func rest_distance(a: Node3D, b: Node3D) -> float:
	return half_size(a) + half_size(b)


## Whether the others steer around `body`: not dead, not summoning, not carried (UnitBody,
## WizardBody and DoctorBody say).
static func is_obstacle(body: Node) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	if body is GameBody:
		return (body as GameBody).is_obstacle()
	return true
