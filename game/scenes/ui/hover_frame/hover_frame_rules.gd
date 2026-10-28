class_name HoverFrameRules
extends RefCounted

## What the hover frame decides without drawing: whether a probed target gets a frame, where it lands on the screen and which
## side color it takes. Static and tree-free, so a check can call it on a body without a HUD. It does not own the pointer
## (TargetProbe does) and it draws nothing (HoverFrame does).

## Half of the frame mesh in the unit square (0..1 = the rect): 10 vertices (x, y), their alphas and 8 triangles.
## `SIZE` is how far a wedge reaches in/out of the side; the frame sticks out `SIZE / 2` past the rect.
const SIZE := 0.1
const _B := SIZE * 0.5
const _VERTS: Array[Vector2] = [
	Vector2(-_B, -_B),
	Vector2(-_B + SIZE, -_B),
	Vector2(-_B + SIZE, -_B - SIZE),
	Vector2(1.0 + _B, -_B),
	Vector2(-_B + SIZE, -_B + SIZE),
	Vector2(-_B, -_B),
	Vector2(-_B + SIZE, -_B + SIZE),
	Vector2(-_B, -_B + SIZE),
	Vector2(-_B - SIZE, -_B + SIZE),
	Vector2(-_B, 1.0 + _B),
]
const _ALPHA: Array[float] = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0]
const _TRIS: Array[int] = [0, 1, 2, 1, 3, 2, 0, 4, 1, 4, 3, 1, 5, 6, 7, 8, 5, 7, 7, 9, 6, 8, 9, 7]


## Whether `node`, classified as `kind` by TargetProbe, gets a frame. Corpses, sky, ground and the HUD never do; a drag hides it;
## buildings show while an icon waits for a target, and while idle only when `buildings_idle`.
static func should_show(
	node: Node, kind: StringName, armed: bool, dragging: bool, buildings_idle: bool
) -> bool:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree() or dragging:
		return false
	if kind == TargetProbe.GROUND and node is ManafountBody:
		return armed or buildings_idle
	if (
		kind == TargetProbe.NONE
		or kind == TargetProbe.GROUND
		or kind == TargetProbe.HUD
		or kind == &"corpse"
	):
		return false
	if kind.ends_with("_building"):
		return armed or buildings_idle
	return true


## Color of the frame: the soul colors for a soul, else the side color of the body's `owner_slot` (neutral: slot 0).
static func color_of(node: Node, kind: StringName, soul_own: Color, soul_other: Color) -> Color:
	if node is Soul:
		return soul_own if kind == &"own_soul" else soul_other
	return SideColors.side_color(int(node.get("owner_slot")) if "owner_slot" in node else 0)


## The 8 corners of the body's box in world space: the model box of a walking body, else every CollisionShape3D under it that is on (a GroundFootprint never counts).
static func world_corners(node: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	if node is CharacterBody3D:
		var body := node as CharacterBody3D
		var box := BodyBox.box_of(body)
		var local := AABB(Vector3(-box.x, 0.0, -box.x), Vector3(box.x * 2.0, box.y, box.x * 2.0))
		_add_corners(out, body.get_global_transform_interpolated(), local)
		return out
	for found in node.find_children("*", "CollisionShape3D", true, false):
		var shape := found as CollisionShape3D
		if shape.shape != null and not shape.disabled:
			_add_corners(
				out,
				shape.get_global_transform_interpolated(),
				shape.shape.get_debug_mesh().get_aabb()
			)
	return out


static func _add_corners(out: PackedVector3Array, xform: Transform3D, box: AABB) -> void:
	for i in 8:
		out.append(xform * box.get_endpoint(i))


## The screen rectangle that holds `corners`. Empty (size zero, position -1) when any of them is behind the camera.
static func screen_rect(camera: Camera3D, corners: PackedVector3Array) -> Rect2:
	if corners.is_empty():
		return Rect2(-1.0, -1.0, 0.0, 0.0)
	var rect := Rect2()
	for i in corners.size():
		if camera.is_position_behind(corners[i]):
			return Rect2(-1.0, -1.0, 0.0, 0.0)
		var point := camera.unproject_position(corners[i])
		rect = Rect2(point, Vector2.ZERO) if i == 0 else rect.expand(point)
	return rect


## `rect` grown by `pad` on every side, then widened around its center to at least `min_size`.
static func fit(rect: Rect2, min_size: Vector2, pad: float) -> Rect2:
	var grown := rect.grow(pad)
	var size := Vector2(maxf(grown.size.x, min_size.x), maxf(grown.size.y, min_size.y))
	return Rect2(grown.get_center() - size * 0.5, size)


## The whole frame as 16 triangles: 48 points in the unit square and their alphas. The second half of the mesh is the
## first one mirrored through the center, so the four sides are wedges that peak near a corner and fade along the side.
static func frame_mesh() -> Dictionary:
	var points := PackedVector2Array()
	var alphas := PackedFloat32Array()
	for mirrored in [false, true]:
		for index in _TRIS:
			var v := _VERTS[index]
			points.append(Vector2.ONE - v if mirrored else v)
			alphas.append(_ALPHA[index])
	return {"points": points, "alphas": alphas}
