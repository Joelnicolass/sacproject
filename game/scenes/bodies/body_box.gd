class_name BodyBox
extends RefCounted

## The size of a body as the others see it: half the width of its box (the avoidance radius, the formation spacing and the
## trample radius) and its height. Both come from the baked model (BodyCatalog), the same for the avoidance agent, Orders
## (getFormationOffsets) and the melee gap. The bodies do not push each other by physics: BodyAvoidance steers them apart.


## Half the box width: max(radius, reach) of the model.
static func half_size(body: Node3D) -> float:
	var info := BodyCatalog.info(_model_of(body))
	return maxf(float(info.get("radius", 0.35)), float(info.get("reach", 0.35)))


static func body_height(body: Node3D) -> float:
	return float(BodyCatalog.info(_model_of(body)).get("height", 1.8))


## (half width, height) of `body`.
static func box_of(body: Node3D) -> Vector2:
	return Vector2(half_size(body), body_height(body))


## Centre-to-centre distance at which two bodies rest apart: their radii. A walker asked to stop closer is steered away.
static func rest_distance(a: Node3D, b: Node3D) -> float:
	return half_size(a) + half_size(b)


## Whether the others steer around `body`: not dead, not summoning, not carried (UnitBody, WizardBody and DoctorBody say).
static func is_obstacle(body: Node) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	if body.has_method("is_obstacle"):
		return bool(body.call("is_obstacle"))
	return true


static func _model_of(body: Node3D) -> String:
	return str(body.get("model")) if "model" in body else ""
