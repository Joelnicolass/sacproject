@tool
class_name BuildingFit
extends RefCounted

## Measures the parts of a building so its body box can be fitted to them (MapBuilding's «Ajustar a las partes» button).
## Does not change anything: it only answers boxes.


## The box that holds every MeshInstance3D part under the holders (Node3D children) of `visuals`, in the frame of `visuals`.
## A zero-size AABB when no part has a mesh.
static func parts_box(visuals: Node3D) -> AABB:
	var merged := AABB()
	var any := false
	for holder in visuals.get_children():
		var placed := holder as Node3D
		if placed == null:
			continue
		for child in placed.get_children():
			var part := child as MeshInstance3D
			if part == null or part.mesh == null:
				continue
			var box: AABB = placed.transform * part.transform * part.mesh.get_aabb()
			merged = box if not any else merged.merge(box)
			any = true
	return merged


## The size of the collision box for a parts box: narrower by the inset on x and z, never thinner than half a meter.
static func body_size(parts: AABB, inset_m: float) -> Vector3:
	return Vector3(maxf(parts.size.x - 2.0 * inset_m, 0.5), maxf(parts.size.y, 0.5), maxf(parts.size.z - 2.0 * inset_m, 0.5))
