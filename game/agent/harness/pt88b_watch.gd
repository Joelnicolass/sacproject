extends Node

## Read-only observer for the F88 replay (round 2). Never moves, orders or selects anything.
##
##   arm()          starts per-tick tracking of every own creature: the longest still streak (< 5 mm per
##                  tick) while its order is pending (`ordered`), and the formation slot of its MOVE order
##                  (Orders.point + offset turned by facing, as unit_orders.anchor() for MOVE).
##   report(names)  longest pending-order still streak, how many > 1 s / > 2 s, how many still ordered,
##                  distance of each creature to its slot (> 2 m, > 5 m, max), and the named ones in detail.
##   runner()       the runner pt88_watch remembers: spot, ordered, mode, distance to its order point,
##                  distance to the nearest other own creature and to the others' centroid.

var _on := false
var _prev: Dictionary = {}
var _streak: Dictionary = {}
var _worst: Dictionary = {}
var _slot: Dictionary = {}


func _own() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("unit"):
		if int(node.get("owner_slot")) == MpKit.local_slot() and node is Node3D:
			out.append(node)
	return out


func _flat(n: Node3D) -> Vector2:
	var o := n.global_transform.origin
	return Vector2(o.x, o.z)


func _slot_of(u: Node3D) -> Variant:
	var orders := u.get_node_or_null("Orders")
	if orders == null:
		return null
	var p: Vector3 = orders.get("point")
	var off: Vector2 = orders.get("offset")
	var yaw: float = orders.get("facing")
	var ahead := Vector3(sin(yaw), 0.0, cos(yaw))
	var right := ahead.cross(Vector3.UP)
	var a := p + right * off.x + ahead * off.y
	return Vector2(a.x, a.z)


func arm() -> String:
	_on = true
	_prev.clear()
	_streak.clear()
	_worst.clear()
	_slot.clear()
	var n := 0
	for u in _own():
		if bool(u.get("ordered")):
			_slot[u.get_instance_id()] = _slot_of(u)
			n += 1
	return "armed ordered=%d" % n


func _physics_process(delta: float) -> void:
	if not _on:
		return
	for u in _own():
		var id := u.get_instance_id()
		var p := _flat(u)
		var ordered := bool(u.get("ordered"))
		if ordered and not _slot.has(id):
			_slot[id] = _slot_of(u)
		if _prev.has(id) and ordered and p.distance_to(_prev[id]) < 0.005:
			_streak[id] = float(_streak.get(id, 0.0)) + delta
			if _streak[id] > float(_worst.get(id, 0.0)):
				_worst[id] = _streak[id]
		else:
			_streak[id] = 0.0
		_prev[id] = p


func report(names: Array = []) -> String:
	var worst := 0.0
	var worst_name := ""
	var over1 := 0
	var over2 := 0
	var still_names: PackedStringArray = []
	var ordered_now := 0
	var off2 := 0
	var off5 := 0
	var off_max := 0.0
	var off_name := ""
	var detail: PackedStringArray = []
	for u in _own():
		var id := u.get_instance_id()
		var s := float(_worst.get(id, 0.0))
		if s > worst:
			worst = s
			worst_name = u.name
		if s > 1.0:
			over1 += 1
		if s > 2.0:
			over2 += 1
			if still_names.size() < 8:
				still_names.append("%s %.1fs" % [u.name, s])
		if bool(u.get("ordered")):
			ordered_now += 1
		var d := -1.0
		if _slot.has(id) and _slot[id] != null:
			d = _flat(u).distance_to(_slot[id])
			if d > 2.0:
				off2 += 1
			if d > 5.0:
				off5 += 1
			if d > off_max:
				off_max = d
				off_name = u.name
		if names.has(String(u.name)):
			var p := _flat(u)
			detail.append("%s(%.1f,%.1f) to_slot=%.1f ordered=%s mode=%d still_max=%.2fs" % [u.name, p.x, p.y, d, str(bool(u.get("ordered"))), int(u.get("mode")), s])
	return "pending_still_max=%.2fs (%s) >1s=%d >2s=%d [%s] ordered_now=%d slots=%d to_slot>2m=%d >5m=%d max=%.1f (%s) | %s" % [
		worst, worst_name, over1, over2, ", ".join(still_names), ordered_now, _slot.size(), off2, off5, off_max, off_name, "; ".join(detail)]


func runner() -> String:
	var pw := get_parent().get_node_or_null("pt88_watch")
	if pw == null:
		return "no pt88_watch"
	var rid := int(pw.get("_runner_id"))
	var r: Node3D = instance_from_id(rid) as Node3D if rid != 0 else null
	if r == null:
		return "no runner"
	var rp := _flat(r)
	var nearest := INF
	var c := Vector2.ZERO
	var n := 0
	for u in _own():
		if u == r:
			continue
		nearest = minf(nearest, _flat(u).distance_to(rp))
		c += _flat(u)
		n += 1
	c /= maxf(1.0, n)
	var orders := r.get_node_or_null("Orders")
	var pt: Vector3 = orders.get("point") if orders else Vector3.ZERO
	return "runner %s (%.1f,%.1f) ordered=%s mode=%d to_point=%.1f nearest_other=%.1f to_centroid=%.1f" % [
		r.name, rp.x, rp.y, str(bool(r.get("ordered"))), int(r.get("mode")), rp.distance_to(Vector2(pt.x, pt.z)), nearest, rp.distance_to(c)]
