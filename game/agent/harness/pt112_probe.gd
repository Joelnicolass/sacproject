extends Node

## Observation only (F112 playtest): measures each gallery body as it is drawn now.
## For every Unit_* under the current scene: clip role/tag/frame, the bottom and top of the
## shown mesh (world AABB of the current frame) and the capsule the game gave it.
## feet = mesh bottom - ground (0). Moves nothing, sets nothing.


func _root() -> Node:
	return get_tree().current_scene


func _world_aabb(mi: MeshInstance3D) -> AABB:
	var local := mi.get_aabb()
	var xf := mi.global_transform
	var out := AABB(xf * local.position, Vector3.ZERO)
	for i in 8:
		out = out.expand(xf * local.get_endpoint(i))
	return out


func _capsule(body: Node3D) -> Vector2:
	var col := body.get_node_or_null("Collision") as CollisionShape3D
	if col == null or col.shape == null:
		return Vector2(NAN, NAN)
	var y := col.global_transform.origin.y
	var half := 0.0
	if col.shape is CapsuleShape3D:
		half = (col.shape as CapsuleShape3D).height * 0.5
	elif col.shape is CylinderShape3D:
		half = (col.shape as CylinderShape3D).height * 0.5
	elif col.shape is BoxShape3D:
		half = (col.shape as BoxShape3D).size.y * 0.5
	elif col.shape is SphereShape3D:
		half = (col.shape as SphereShape3D).radius
	return Vector2(y - half, y + half)


func _line(body: Node3D) -> String:
	var b = body
	var info: Dictionary = b.debug_clip_info() if body.has_method("debug_clip_info") else {}
	var mi := body.get_node_or_null("Tilt/Mesh") as MeshInstance3D
	var bottom := NAN
	var top := NAN
	if mi and mi.mesh:
		var box := _world_aabb(mi)
		bottom = box.position.y
		top = box.end.y
	var cap := _capsule(body)
	var o := body.global_transform.origin
	return "%s model=%s role=%s tag=%s frame=%d at=(%.1f,%.2f,%.1f) feet=%.2f top=%.2f cap=[%.2f,%.2f]" % [
		body.name, str(body.get("model")), info.get("role", ""), info.get("tag", ""), int(info.get("frame", 0)),
		o.x, o.y, o.z, bottom, top, cap.x, cap.y]


## One line per unit (prints and returns the count).
func units() -> String:
	var actors := _root().find_child("Actors", true, false)
	if actors == null:
		return "sin Actors"
	var n := 0
	for child in actors.get_children():
		if child is Node3D and str(child.name).begins_with("Unit_"):
			print("PT112 ", _line(child as Node3D))
			n += 1
	return "PT112 units=%d" % n


## Same lines for a named body anywhere in the scene (for the village Taurock).
func body(node_name: String) -> String:
	var node := _root().find_child(node_name, true, false) as Node3D
	if node == null:
		return "PT112 sin %s" % node_name
	return "PT112 " + _line(node)
