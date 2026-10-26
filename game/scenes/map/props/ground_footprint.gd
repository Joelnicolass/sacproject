@tool
class_name GroundFootprint
extends CollisionShape3D

## The base of a structure that must lie level: its box, seen from above, is the land under the structure that has to be flat
## (size it with the box gizmo; only x and z count). The shape is always off, so it never collides, never feeds the navmesh
## and never blocks a path. Not: flattening the ground (the editor's «Aplanar bases» through FootprintRules), checking it
## (tools/audit/check_map), where the structure stands.

## Every footprint of the open scene, in the editor and in a match.
const GROUP := &"ground_footprint"


func _enter_tree() -> void:
	disabled = true
	add_to_group(GROUP)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not shape is BoxShape3D:
		warnings.append("GroundFootprint necesita un BoxShape3D: su caja vista desde arriba es la base que queda a nivel.")
	return warnings


## The ground area (x, z in metres) the box covers seen from above, turned and scaled as it stands. Empty without a box.
func area() -> Rect2:
	var box := shape as BoxShape3D
	if box == null:
		return Rect2()
	var half := box.size * 0.5
	var xform := global_transform
	var first := xform * Vector3(-half.x, 0.0, -half.z)
	var out := Rect2(Vector2(first.x, first.z), Vector2.ZERO)
	for corner: Vector3 in [Vector3(half.x, 0.0, -half.z), Vector3(-half.x, 0.0, half.z), Vector3(half.x, 0.0, half.z)]:
		var at := xform * corner
		out = out.expand(Vector2(at.x, at.z))
	return out
