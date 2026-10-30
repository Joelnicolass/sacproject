@tool
class_name BuildingFit
extends RefCounted

## Measures the parts of a building: the box its body is fitted to (MapBuilding's «Fit to parts»
## button) and where a part bursts when the building falls (StructureBreak). Does not change
## anything: it only answers boxes and points.


## The box that holds every MeshInstance3D part under the holders (Node3D children) of `visuals`, in
## the frame of `visuals`. A zero-size AABB when no part has a mesh.
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


## The size of the collision box for a parts box: narrower by the inset on x and z, never thinner
## than half a meter.
static func body_size(parts: AABB, inset_m: float) -> Vector3:
	return Vector3(
		maxf(parts.size.x - 2.0 * inset_m, 0.5),
		maxf(parts.size.y, 0.5),
		maxf(parts.size.z - 2.0 * inset_m, 0.5)
	)


## World centre where a part (a holder under `Visuals`) bursts: its Marker3D child when it has one,
## else the middle of its meshes. A part with no MeshInstance3D with a mesh is no part: a NAN
## vector. Needs the part in the tree.
static func part_center(part: Node3D) -> Vector3:
	var merged := AABB()
	var any := false
	var marker: Marker3D = null
	for child in part.get_children():
		if child is Marker3D and marker == null:
			marker = child as Marker3D
		var mesh_part := child as MeshInstance3D
		if mesh_part == null or mesh_part.mesh == null:
			continue
		var box: AABB = mesh_part.global_transform * mesh_part.mesh.get_aabb()
		merged = box if not any else merged.merge(box)
		any = true
	if not any:
		return Vector3(NAN, NAN, NAN)
	return marker.global_position if marker != null else merged.get_center()
