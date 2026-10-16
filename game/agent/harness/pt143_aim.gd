extends Node

## Read-only pointer helper for the F143 Fireball check. It only does what the mouse does: it puts the world camera's
## debug pointer (what `select` / `order_units` read as the cursor) on a body that is on screen. It never moves, orders,
## damages or spawns anything; the flow presses the InputMap actions. Tolerates scene == null.
##   aim_nearest(tag, slot, ref_tag, ref_slot, lift, ground_offset)  pointer on the live unit tag/slot nearest to the
##       first live body ref_tag/ref_slot ("wizard" = that slot's wizard) that a click would hit (not hidden by another
##       body); with ground_offset > 0, on the open ground that far from it toward the camera. Remembers both.
##   status()                                         distances ref→target and own wizard→target, hp of both.
## Props for wait_until: gap (ref→target distance, updated every frame; 9999 when unknown).

var gap := 9999.0

var _target: Node3D
var _ref: Node3D


func _process(_delta: float) -> void:
	if _valid(_target) and _valid(_ref):
		gap = _at(_target).distance_to(_at(_ref))
	else:
		gap = 9999.0


func _valid(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and (node as Node).is_inside_tree()


func _at(node: Node3D) -> Vector3:
	return node.global_transform.origin


func _tag(node: Node) -> String:
	if "creature_tag" in node:
		return str(node.get("creature_tag"))
	var type: Variant = node.get("type")
	return str(type.get("tag")) if type != null else "?"


func _alive(node: Node) -> bool:
	var health := node.get_node_or_null("Health")
	return health != null and float(health.get("current")) > 0.0


func _first(tag: String, slot: int) -> Node3D:
	if get_tree().current_scene == null:
		return null
	var group := "wizard" if tag == "wizard" else "unit"
	for node in get_tree().get_nodes_in_group(group):
		if int(node.get("owner_slot")) == slot and (tag == "wizard" or _tag(node) == tag) and _alive(node):
			return node as Node3D
	return null


func _world_camera() -> Camera3D:
	if get_tree().current_scene == null:
		return null
	for node in get_tree().current_scene.find_children("*", "Camera3D", true, false):
		if "debug_pointer" in node:
			return node as Camera3D
	return null


func aim_nearest(tag: String, slot: int, ref_tag: String, ref_slot: int, lift: float = 1.0, ground_offset: float = 0.0) -> String:
	var ref := _first(ref_tag, ref_slot)
	var view := get_viewport().get_camera_3d()
	var world := _world_camera()
	if ref == null or view == null or world == null:
		return "aim missing (ref=%s view=%s world=%s)" % [ref != null, view != null, world != null]
	var found: Array = []
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) != slot or _tag(node) != tag or not _alive(node):
			continue
		found.append([_at(node as Node3D).distance_to(_at(ref)), node])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var tried := PackedStringArray()
	for pair in found:
		var body := pair[1] as Node3D
		var point := _at(body) + Vector3.UP * lift
		if ground_offset > 0.0:
			var to_cam := view.global_transform.origin - _at(body)
			to_cam.y = 0.0
			point = _at(body) + to_cam.normalized() * ground_offset
		if view.is_position_behind(point):
			tried.append("%s:behind" % body.name)
			continue
		var screen := view.unproject_position(point)
		if not view.get_viewport().get_visible_rect().has_point(screen):
			tried.append("%s:offscreen" % body.name)
			continue
		var under := _under(view, screen)
		var wanted := under == body if ground_offset <= 0.0 else under == null
		if not wanted:
			tried.append("%s:%s" % [body.name, _label(under)])
			continue
		world.set("debug_pointer", screen)
		_target = body
		_ref = ref
		var r := "pt143aim %s#s%d at %d,%d under=%s ref_d=%.1f offset=%.1f skipped=%s" % [body.name, slot, int(screen.x),
			int(screen.y), _label(under), float(pair[0]), ground_offset, ",".join(tried)]
		print(r)
		return r
	var miss := "pt143aim none of %d %s#s%d usable: %s" % [found.size(), tag, slot, ",".join(tried)]
	print(miss)
	return miss


## The body under a screen point (layers 1+2 like a click), or null for the ground / nothing.
func _under(view: Camera3D, screen: Vector2) -> Node:
	var origin := view.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + view.project_ray_normal(screen) * 10000.0)
	query.collision_mask = 3
	var hit := view.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var col := hit["collider"] as Node
	return col if col != null and "owner_slot" in col else null


func _label(node: Node) -> String:
	return "ground" if node == null else "%s#s%s" % [node.name, str(node.get("owner_slot"))]


func status() -> String:
	if get_tree().current_scene == null:
		return "pt143aim status scene=null"
	var r := "pt143aim status"
	if _valid(_target):
		r += " target=%s hp=%.1f" % [_target.name, float(_target.get_node("Health").get("current"))]
	if _valid(_ref):
		r += " ref=%s hp=%.1f gap=%.1f" % [_ref.name, float(_ref.get_node("Health").get("current")), gap]
	var own := _first("wizard", 1)
	if own != null and _valid(_target):
		r += " wizard_d=%.1f" % _at(own).distance_to(_at(_target))
	print(r)
	return r
