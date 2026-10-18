extends Node

## Read-only observer for the F88 playtest (crowding in the avoidance). It never moves, orders or selects
## anything: it only reads where bodies are and aims the world camera's debug pointer (what `select` and
## `order_units` use), like selection_probe.
##
##   aim_ahead(m)      pointer on the ground m ahead of the own cluster, along the wizard's facing.
##   aim_world(x, z)   pointer on the ground at (x, z).
##   aim_back()        pointer on the own creature nearest the wizard (back row); remembers it as the runner.
##   snap_rest()       remembers where every own creature but the runner stands now.
##   rest_report()     how far the others are from the snapshot (max, > 0.15 m, > 0.5 m) and the runner's spot.
##   track(on)         per tick, the longest still streak (s) of each own creature that moved again later.
##   track_report(x,z) longest freed-after streak, creatures still now and far (> far_m) from (x, z).
##   wiz_begin()       remembers the local wizard's spot and facing and the nearest foe creature.
##   wiz_report()      forward and lateral travel of the wizard, gap to the foe, sum of radii.

@export var far_m := 25.0

var _runner_id := 0
var _rest: Dictionary = {}
var _tracking := false
var _prev: Dictionary = {}
var _streak: Dictionary = {}
var _worst: Dictionary = {}
var _wiz_at := Vector3.ZERO
var _wiz_dir := Vector3.FORWARD
var _foe: Node3D
var _last_spot := Vector3.ZERO


func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()


func _wizard() -> Node3D:
	return get_tree().get_first_node_in_group("local_wizard") as Node3D


func _own() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) == MpKit.local_slot() and node is Node3D:
			out.append(node)
	return out


func _flat(n: Node3D) -> Vector2:
	var o := n.global_transform.origin
	return Vector2(o.x, o.z)


func _ground(x: float, z: float) -> Variant:
	var cam := _camera()
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 400.0, z), Vector3(x, -400.0, z))
	q.collision_mask = 1
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	return hit["position"]


func _aim(spot: Vector3) -> String:
	var cam := _camera()
	if cam.is_position_behind(spot):
		return "behind"
	var screen := cam.unproject_position(spot)
	var view := get_viewport().get_visible_rect().size
	cam.set("debug_pointer", screen)
	var inside := screen.x > 0 and screen.y > 0 and screen.x < view.x and screen.y < view.y
	return "%d,%d at=(%.0f, %.0f) %s" % [screen.x, screen.y, spot.x, spot.z, "on" if inside else "OFFSCREEN"]


func aim_ahead(meters: float) -> String:
	var wiz := _wizard()
	var own := _own()
	if wiz == null or own.is_empty():
		return "missing"
	var c := Vector2.ZERO
	for u in own:
		c += _flat(u)
	c /= own.size()
	var dir: Vector3 = wiz.facing_flat()
	var spot: Variant = _ground(c.x + dir.x * meters, c.y + dir.z * meters)
	if spot == null:
		return "no ground"
	_last_spot = spot
	return _aim(spot)


func aim_world(x: float, z: float) -> String:
	var spot: Variant = _ground(x, z)
	if spot == null:
		return "no ground"
	return _aim(spot)


func aim_back() -> String:
	var wiz := _wizard()
	var best: Node3D = null
	var best_d := INF
	for u in _own():
		var d := _flat(u).distance_to(_flat(wiz))
		if d < best_d:
			best_d = d
			best = u
	if best == null:
		return "none"
	_runner_id = best.get_instance_id()
	return "%s d=%.1f %s" % [best.name, best_d, _aim(best.global_transform.origin + Vector3.UP * 0.6)]


func snap_rest() -> int:
	_rest.clear()
	for u in _own():
		if u.get_instance_id() != _runner_id:
			_rest[u.get_instance_id()] = _flat(u)
	return _rest.size()


func rest_report() -> String:
	var worst := 0.0
	var worst_name := ""
	var over15 := 0
	var over50 := 0
	var runner := "-"
	for u in _own():
		var id := u.get_instance_id()
		if id == _runner_id:
			var p := _flat(u)
			runner = "%s (%.1f, %.1f)" % [u.name, p.x, p.y]
			continue
		if not _rest.has(id):
			continue
		var d := _flat(u).distance_to(_rest[id])
		if d > worst:
			worst = d
			worst_name = u.name
		if d > 0.15:
			over15 += 1
		if d > 0.5:
			over50 += 1
	return "rest n=%d max_off=%.2f (%s) off>0.15=%d off>0.5=%d runner=%s" % [_rest.size(), worst, worst_name, over15, over50, runner]


func track(on: bool) -> void:
	_tracking = on
	if on:
		_prev.clear()
		_streak.clear()
		_worst.clear()


func _physics_process(delta: float) -> void:
	if not _tracking:
		return
	for u in _own():
		var id := u.get_instance_id()
		var p := _flat(u)
		if _prev.has(id):
			if p.distance_to(_prev[id]) < 0.005:
				_streak[id] = float(_streak.get(id, 0.0)) + delta
			else:
				var s := float(_streak.get(id, 0.0))
				if s > float(_worst.get(id, 0.0)):
					_worst[id] = s
				_streak[id] = 0.0
		_prev[id] = p


func track_report(x: float, z: float) -> String:
	var worst := 0.0
	var over2 := 0
	var over1 := 0
	for id in _worst:
		var s := float(_worst[id])
		worst = maxf(worst, s)
		if s > 2.0:
			over2 += 1
		if s > 1.0:
			over1 += 1
	var goal := Vector2(x, z)
	var far := 0
	var max_d := 0.0
	var still_now := 0
	for u in _own():
		var d := _flat(u).distance_to(goal)
		max_d = maxf(max_d, d)
		if d > far_m:
			far += 1
		if float(_streak.get(u.get_instance_id(), 0.0)) > 0.5:
			still_now += 1
	return "freed_streak_max=%.2fs >1s=%d >2s=%d still_now=%d far>%.0fm=%d max_goal_d=%.1f" % [worst, over1, over2, still_now, far_m, far, max_d]


func wiz_begin() -> String:
	var wiz := _wizard()
	_wiz_at = wiz.global_transform.origin
	_wiz_dir = wiz.facing_flat()
	_foe = null
	var best := INF
	for node in get_tree().get_nodes_in_group("unit"):
		var slot := int(node.get("owner_slot"))
		if slot == MpKit.local_slot() or slot <= 0:
			continue
		var d := _flat(node).distance_to(_flat(wiz))
		if d < best:
			best = d
			_foe = node
	return "wiz (%.1f, %.1f) dir (%.2f, %.2f) foe=%s d=%.1f" % [_wiz_at.x, _wiz_at.z, _wiz_dir.x, _wiz_dir.z, _foe.name if _foe else "-", best]


func _radius(n: Node3D) -> float:
	var shape_node := n.get_node_or_null("Collision") as CollisionShape3D
	if shape_node and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).radius
	if shape_node and shape_node.shape is SphereShape3D:
		return (shape_node.shape as SphereShape3D).radius
	if shape_node and shape_node.shape is CylinderShape3D:
		return (shape_node.shape as CylinderShape3D).radius
	return -1.0


func wiz_report() -> String:
	var wiz := _wizard()
	var o := wiz.global_transform.origin - _wiz_at
	var fwd := o.x * _wiz_dir.x + o.z * _wiz_dir.z
	var side := Vector2(-_wiz_dir.z, _wiz_dir.x).dot(Vector2(o.x, o.z))
	var gap := -1.0
	if is_instance_valid(_foe):
		gap = _flat(wiz).distance_to(_flat(_foe))
	return "wiz fwd=%.2f side=%.2f gap_to_foe=%.2f r_wiz=%.2f r_foe=%.2f" % [fwd, side, gap, _radius(wiz), _radius(_foe) if is_instance_valid(_foe) else -1.0]


func _centroid(skip_runner: bool) -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for u in _own():
		if skip_runner and u.get_instance_id() == _runner_id:
			continue
		c += _flat(u)
		n += 1
	return c / maxf(1.0, n)


## Pointer on the ground `beyond` m past the centroid of the others, on the line from the runner through it.
func aim_through(beyond: float) -> String:
	var runner: Node3D = instance_from_id(_runner_id) as Node3D if _runner_id != 0 else null
	if runner == null:
		return "no runner"
	var c := _centroid(true)
	var dir := (c - _flat(runner)).normalized()
	var spot: Variant = _ground(c.x + dir.x * beyond, c.y + dir.y * beyond)
	if spot == null:
		return "no ground"
	_last_spot = spot
	return _aim(spot)


## Pointer `beyond` m past (x, z) on the line from the own cluster's centroid through (x, z).
func aim_past(x: float, z: float, beyond: float) -> String:
	var c := _centroid(false)
	var p := Vector2(x, z)
	var dir := (p - c).normalized()
	var spot: Variant = _ground(p.x + dir.x * beyond, p.y + dir.y * beyond)
	if spot == null:
		return "no ground"
	_last_spot = spot
	return "from (%.0f, %.0f) %s" % [c.x, c.y, _aim(spot)]


## Remembers where the pointer is on the ground now (after selection_probe.aim_empty), for track_goal().
func mark_pointer() -> String:
	var cam := _camera()
	var screen: Vector2 = cam.get("debug_pointer")
	var origin := cam.project_ray_origin(screen)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
	q.collision_mask = 1
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "no ground"
	_last_spot = hit["position"]
	return "goal (%.1f, %.1f)" % [_last_spot.x, _last_spot.z]


func track_goal() -> String:
	return track_report(_last_spot.x, _last_spot.z)


## The own creatures farther than far_m from the last goal: name, spot, distance, still streak (s).
func far_list() -> String:
	var goal := Vector2(_last_spot.x, _last_spot.z)
	var out: PackedStringArray = []
	for u in _own():
		var d := _flat(u).distance_to(goal)
		if d > far_m:
			var p := _flat(u)
			out.append("%s(%.0f,%.0f) d=%.0f still=%.1fs" % [u.name, p.x, p.y, d, float(_streak.get(u.get_instance_id(), 0.0))])
	return "far %d: %s" % [out.size(), "; ".join(out.slice(0, 12))]


## The resting creatures more than 0.5 m off their snapshot: name, offset, gap to the runner.
func rest_list() -> String:
	var runner: Node3D = instance_from_id(_runner_id) as Node3D if _runner_id != 0 else null
	var out: PackedStringArray = []
	for u in _own():
		var id := u.get_instance_id()
		if not _rest.has(id):
			continue
		var d := _flat(u).distance_to(_rest[id])
		if d > 0.5:
			var gap := (_rest[id] as Vector2).distance_to(_flat(runner)) if runner else -1.0
			out.append("%s off=%.2f home_to_runner=%.1f" % [u.name, d, gap])
	return "; ".join(out)
