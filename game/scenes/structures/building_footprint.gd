@tool
class_name BuildingFootprint
extends Node3D

## The box of a building's parts, in the building's own frame. MapBuilding shapes its body and its melee reach from it.
## The collision is the box smaller by `inset` on every side. Does not place the parts or the body: it only says how big they are.
## Put it next to the parts (BodyVisual holders) in the building's scene; «Ajustar a las partes» measures them.

@export var hit_box := AABB(Vector3(-2.0, 0.0, -2.0), Vector3(4.0, 4.0, 4.0))
## Units pass the eaves: the body is the box minus this much (m) on every side.
@export_range(0.0, 5.0, 0.05, "suffix:m") var inset := 0.5
@export_tool_button("Ajustar a las partes", "Reload") var fit := fit_to_parts


## The size of the collision box: the hit box minus the inset, never thinner than half a meter.
func body_size() -> Vector3:
	return Vector3(maxf(hit_box.size.x - 2.0 * inset, 0.5), maxf(hit_box.size.y, 0.5), maxf(hit_box.size.z - 2.0 * inset, 0.5))


## Measures the BodyVisual parts that sit beside this node and takes the box that holds them all.
func fit_to_parts() -> void:
	var merged := AABB()
	var any := false
	for holder in get_parent().get_children():
		for child in holder.get_children():
			var visual := child as BodyVisual
			var raw: Array = BodyCatalog.info(visual.model).get("box", []) if visual != null and BodyCatalog.has_model(visual.model) else []
			if raw.size() != 6:
				continue
			var local := AABB(Vector3(raw[0], raw[1], raw[2]), Vector3(raw[3], raw[4], raw[5]))
			var placed: AABB = (holder as Node3D).transform * BodyCatalog.pose(visual.model, false) * local
			merged = placed if not any else merged.merge(placed)
			any = true
	if any:
		hit_box = merged
