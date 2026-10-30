@tool
extends EditorNode3DGizmoPlugin

## Editor only: a GrassClear3D's two circles (no grass inside the inner one, full grass outside the
## outer one) with a handle on each to drag its `radius` and `soft`, and a GrassField3D's ground
## area following the ground, with a handle on each side to drag it (what is painted stays where it
## is, and the new parts are baked). Every drag is one step of the editor's history.

const SEGMENTS := 48
## Field handles: the area's west, east, north and south sides.
enum Side { WEST, EAST, NORTH, SOUTH }

## The paint tool, which resizes the area as one step of the history.
var tool: Node
## The area being dragged (the ground keeps its own until the drag ends), by field.
var _dragging: Dictionary[GrassField3D, Rect2] = {}


func _init() -> void:
	# On top: the circles lie on the ground, which would hide them.
	create_material("clear", Color(1.0, 0.85, 0.3), false, true)
	create_material("area", Color(0.95, 0.95, 0.95), false, true)
	create_handle_material("handles")


func _get_gizmo_name() -> String:
	return "GrassKit"


func _has_gizmo(node: Node3D) -> bool:
	return node is GrassClear3D or node is GrassField3D


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	var clear := node as GrassClear3D
	if clear != null:
		var lines := PackedVector3Array()
		for r in [clear.radius, clear.radius + clear.soft]:
			for k in SEGMENTS:
				var a := TAU * k / SEGMENTS
				var b := TAU * (k + 1) / SEGMENTS
				lines.append(Vector3(cos(a), 0.0, sin(a)) * r)
				lines.append(Vector3(cos(b), 0.0, sin(b)) * r)
		gizmo.add_lines(lines, get_material("clear", gizmo))
		var handles := PackedVector3Array([
			Vector3(clear.radius, 0.0, 0.0), Vector3(clear.radius + clear.soft, 0.0, 0.0)
		])
		gizmo.add_handles(handles, get_material("handles", gizmo), PackedInt32Array([0, 1]))
		return
	var field := node as GrassField3D
	if field.ground == null:
		return
	var rect: Rect2 = _dragging.get(field, field.ground.area)
	var to_local := field.global_transform.affine_inverse()
	var corners := [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var lines := PackedVector3Array()
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		# Along the ground, a point every couple of metres.
		var steps := clampi(ceili(a.distance_to(b) / 2.0), 1, 256)
		for s in steps:
			var p := a.lerp(b, float(s) / steps)
			var q := a.lerp(b, float(s + 1) / steps)
			lines.append(to_local * _on_ground(field, p))
			lines.append(to_local * _on_ground(field, q))
	gizmo.add_lines(lines, get_material("area", gizmo))
	var handles := PackedVector3Array()
	for side in 4:
		handles.append(to_local * _on_ground(field, _side_point(rect, side)))
	gizmo.add_handles(handles, get_material("handles", gizmo), PackedInt32Array([0, 1, 2, 3]))


func _get_handle_name(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	if gizmo.get_node_3d() is GrassClear3D:
		return "Radius" if id == 0 else "Soft"
	return ["West side", "East side", "North side", "South side"][id]


func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> Variant:
	var clear := gizmo.get_node_3d() as GrassClear3D
	if clear != null:
		return clear.radius if id == 0 else clear.soft
	var field := gizmo.get_node_3d() as GrassField3D
	return field.ground.area if field.ground != null else Rect2()


func _set_handle(
	gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, at: Vector2
) -> void:
	var node := gizmo.get_node_3d()
	var from := camera.project_ray_origin(at)
	var dir := camera.project_ray_normal(at)
	var clear := node as GrassClear3D
	if clear != null:
		var hit: Variant = Plane(Vector3.UP, clear.global_position.y).intersects_ray(from, dir)
		if hit == null:
			return
		var flat := Vector2(hit.x - clear.global_position.x, hit.z - clear.global_position.z)
		var distance := snappedf(flat.length(), 0.1)
		if id == 0:
			clear.radius = maxf(distance, 0.0)
		else:
			clear.soft = maxf(distance - clear.radius, 0.0)
		return
	var field := node as GrassField3D
	if field.ground == null:
		return
	var rect: Rect2 = _dragging.get(field, field.ground.area)
	var height := _on_ground(field, _side_point(rect, id)).y
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(from, dir)
	if hit == null:
		return
	var low := rect.position
	var high := rect.end
	match id:
		Side.WEST:
			low.x = minf(roundf(hit.x), high.x - 1.0)
		Side.EAST:
			high.x = maxf(roundf(hit.x), low.x + 1.0)
		Side.NORTH:
			low.y = minf(roundf(hit.z), high.y - 1.0)
		Side.SOUTH:
			high.y = maxf(roundf(hit.z), low.y + 1.0)
	_dragging[field] = Rect2(low, high - low)
	field.update_gizmos()


func _commit_handle(
	gizmo: EditorNode3DGizmo, id: int, _secondary: bool, restore: Variant, cancel: bool
) -> void:
	var node := gizmo.get_node_3d()
	var clear := node as GrassClear3D
	if clear != null:
		var property := &"radius" if id == 0 else &"soft"
		if cancel:
			clear.set(property, restore)
			return
		var history := EditorInterface.get_editor_undo_redo()
		history.create_action("Drag %s's %s" % [clear.name, property], UndoRedo.MERGE_DISABLE, clear)
		history.add_do_property(clear, property, clear.get(property))
		history.add_undo_property(clear, property, restore)
		history.commit_action()
		return
	var field := node as GrassField3D
	var rect: Rect2 = _dragging.get(field, restore)
	_dragging.erase(field)
	if not cancel and tool != null and field.ground != null:
		tool.call(&"edit_area", field, rect)
	field.update_gizmos()


## A point of the ground plane at the ground's height (flat where nothing is baked).
static func _on_ground(field: GrassField3D, at: Vector2) -> Vector3:
	return Vector3(at.x, field.ground.height_at(at) + 0.05, at.y)


static func _side_point(rect: Rect2, side: int) -> Vector2:
	match side:
		Side.WEST:
			return Vector2(rect.position.x, rect.get_center().y)
		Side.EAST:
			return Vector2(rect.end.x, rect.get_center().y)
		Side.NORTH:
			return Vector2(rect.get_center().x, rect.position.y)
	return Vector2(rect.get_center().x, rect.end.y)
