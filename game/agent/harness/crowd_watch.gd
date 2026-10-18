extends Node

## Read-only observer of a crowd of creatures (F87 playtest: the avoidance on the march and at
## arrival). Never moves, orders or selects anything; it only reads where the bodies are.
##
##   sample(slot = -1)  one line about the creatures of `slot` (-1 = every slot):
##     n          creatures in the tree
##     moving     those that moved more than `moving_m_s` since the previous sample
##     still      those that did not (on the march: stuck; at arrival: parked)
##     deep       pairs closer than `deep_ratio` x (radius a + radius b): one inside the other
##     touch      pairs closer than (radius a + radius b) x 0.9
##     min_ratio  the smallest distance / (radius a + radius b) of any pair
##     spread     mean distance to the centroid; centroid (x, z)
##     jitter     creatures whose step reversed (dot < 0) between the last two samples while moving less than `jitter_m`
##     hotspot    creatures within `hotspot_r` of `hotspot` that did not move (the known F113 jam)
##   Distances are flat (x, z). Pairs only within `pair_cut_m` (a grid would not change the count).

@export var moving_m_s := 0.3
@export var deep_ratio := 0.5
@export var jitter_m := 0.6
@export var hotspot := Vector2(1488.0, 1511.0)
@export var hotspot_r := 25.0
@export var pair_cut_m := 6.0

var _last: Dictionary = {}
var _last_step: Dictionary = {}
var _last_ms := 0


func _units(slot: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("unit"):
		if not (node is Node3D) or not (node as Node3D).is_inside_tree():
			continue
		if slot >= 0 and int(node.get("owner_slot")) != slot:
			continue
		out.append(node)
	return out


func _radius(unit: Node3D) -> float:
	var shape_node := unit.get_node_or_null("Collision") as CollisionShape3D
	if shape_node and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).radius
	if shape_node and shape_node.shape is SphereShape3D:
		return (shape_node.shape as SphereShape3D).radius
	return 0.4


func sample(slot: int = -1) -> String:
	var units := _units(slot)
	var now := Time.get_ticks_msec()
	var dt := maxf(0.001, (now - _last_ms) / 1000.0) if _last_ms > 0 else 0.0
	var flat: Array[Vector2] = []
	var radii := PackedFloat32Array()
	var center := Vector2.ZERO
	var moving := 0
	var still := 0
	var jitter := 0
	var hot := 0
	var hot_still := 0
	var seen: Dictionary = {}
	for unit in units:
		var at := unit.global_transform.origin
		var p := Vector2(at.x, at.z)
		flat.append(p)
		radii.append(_radius(unit))
		center += p
		var id := unit.get_instance_id()
		seen[id] = p
		var moved_now := false
		if dt > 0.0 and _last.has(id):
			var step: Vector2 = p - (_last[id] as Vector2)
			moved_now = step.length() / dt > moving_m_s
			if moved_now:
				moving += 1
			else:
				still += 1
			if _last_step.has(id):
				var prev: Vector2 = _last_step[id]
				if step.length() < jitter_m and prev.length() > 0.02 and step.length() > 0.02 and step.dot(prev) < 0.0:
					jitter += 1
			_last_step[id] = step
		if p.distance_to(hotspot) < hotspot_r:
			hot += 1
			if dt > 0.0 and not moved_now:
				hot_still += 1
	var n := flat.size()
	if n > 0:
		center /= n
	var spread := 0.0
	for p in flat:
		spread += p.distance_to(center)
	spread = spread / n if n > 0 else 0.0
	var deep := 0
	var touch := 0
	var min_ratio := 99.0
	var deep_names: PackedStringArray = []
	for i in n:
		for j in range(i + 1, n):
			var d := flat[i].distance_to(flat[j])
			if d > pair_cut_m:
				continue
			var reach := radii[i] + radii[j]
			var ratio := d / maxf(0.001, reach)
			min_ratio = minf(min_ratio, ratio)
			if ratio < deep_ratio:
				deep += 1
				if deep_names.size() < 4:
					deep_names.append("%s~%s" % [units[i].name, units[j].name])
			elif ratio < 0.9:
				touch += 1
	_last = seen
	_last_ms = now
	return "n=%d moving=%d still=%d deep=%d touch=%d min_ratio=%.2f spread=%.1f centroid=(%.0f, %.0f) jitter=%d hotspot=%d/%d %s" % [
		n, moving, still, deep, touch, min_ratio, spread, center.x, center.y, jitter, hot_still, hot, ",".join(deep_names)]
