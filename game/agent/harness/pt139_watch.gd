extends Node

## Read-only observer for the F139 playtest (RFC-031 031a, friendly fire). It never moves, orders, damages, heals or
## spawns anything. It listens to Health.hurt of every unit and wizard, to death clouds, poison doses, creature shots
## and Fireballs entering/leaving the tree, re-frames the screen camera (like a player scrolling the view) and puts the
## world camera's debug pointer (what `select` / `order_units` read, like the mouse) on a body. Tolerates scene == null.
##
##   arm()                       connects to the bodies present (groups unit, wizard) and to SceneTree.node_added.
##   aim(tag, slot)              the pointer goes on the first live unit with that tag and slot; says what is under it.
##   frame(x, z, ox, oy, oz)     screen camera looks at (x, ground, z) from that offset.
##   frame_on(tag, slot, ox, oy, oz)  the same, on a unit.
##   report()                    per body: hp at arm, now, hurt totals by kind/slot (and hurts of 0); per cloud and per
##                               Fireball the box distance of each body and the side ratio; per shot its line.
## Props for wait_until: units, clouds, doses, doses_done, fireballs, shots, shots_gone, ally_hits.

const _SHOT := preload("res://scenes/units/attacks/ranged_shot.gd")
const _FIREBALL := preload("res://scenes/spells/fireball_projectile.gd")
const _POISONED := preload("res://scenes/units/status/poisoned.gd")
const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

var units := 0
var clouds := 0
var doses := 0
var doses_done := 0
var fireballs := 0
var fireballs_gone := 0
var shots := 0
var shots_gone := 0
var ally_hits := 0

var _info: Dictionary = {}     # body -> {name, tag, slot, hp0, max, hurt:{key:sum}, zeros:{key:n}, hits:[]}
var _clouds: Array = []        # [{tag, slot, at, pf, dist:{name:d}, range, amount}]
var _fbs: Array = []           # [{node, slot, damage, range, at, pf, dist:{}}]
var _shot_recs: Array = []     # [{node, slot, shooter, target, spawn, target_at, pf, line:{}, min_box:{}, exit_pf, end}]
var _doses: Array = []         # [{node, body, per_s, frames, taken}]
var _armed := false


func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000


func _pf() -> int:
	return Engine.get_physics_frames()


func _terrain() -> TerrainShape:
	if get_tree().current_scene == null:
		return null
	return TerrainShape.of(self)


func _ground_y(x: float, z: float) -> float:
	var t := _terrain()
	if t == null:
		return 0.0
	var y := t.height_at(x, z)
	return 0.0 if is_nan(y) else y


func _name(node: Variant) -> String:
	if node == null or not is_instance_valid(node):
		return "null"
	var n := node as Node
	var label := str(n.name)
	if n.has_method("display_name"):
		var dyn: Variant = n
		label = str(dyn.display_name())
	return "%s#s%d" % [label, int(n.get("owner_slot")) if "owner_slot" in n else 0]


func _tag(node: Node) -> String:
	if "creature_tag" in node:
		return str(node.get("creature_tag"))
	var type: Variant = node.get("type")
	return str(type.get("tag")) if type != null else "?"


func _at(node: Node3D) -> Vector3:
	return node.global_transform.origin


func _v(p: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]


func arm() -> String:
	if get_tree().current_scene == null:
		return "armed 0 (no scene)"
	for group in ["unit", "wizard"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or _info.has(body):
				continue
			var health := body.get_node_or_null("Health")
			if health == null:
				continue
			var hp := float(health.get("current"))
			var label := _name(body)
			var taken_names := _info.values().map(func(v: Dictionary) -> String: return str(v["name"]))
			var nth := 2
			var base := label
			while taken_names.has(label):
				label = "%s_%d" % [base, nth]
				nth += 1
			_info[body] = {"name": label, "tag": _tag(body), "slot": int(body.get("owner_slot")), "hp0": hp,
				"max": float(health.get("maximum")), "hurt": {}, "zeros": {}, "hits": [], "group": group,
				"grudge": body.has_meta(GrudgeMemory.META)}
			health.connect("hurt", _on_hurt.bind(body))
			units += 1
			print("PT139 UNIT %s tag=%s group=%s hp=%.1f/%.1f at=%s" % [_info[body]["name"], _info[body]["tag"], group, hp,
				float(health.get("maximum")), _v(_at(body))])
	if not _armed:
		_armed = true
		get_tree().node_added.connect(_on_node_added)
	return "armed %d" % units


func _on_hurt(amount: float, kind: StringName, from_slot: int, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	var key := "%s/s%d" % [kind, from_slot]
	i["hurt"][key] = float(i["hurt"].get(key, 0.0)) + amount
	if amount <= 0.0:
		i["zeros"][key] = int(i["zeros"].get(key, 0)) + 1
	var own := from_slot == int(i["slot"])
	if own and amount > 0.0:
		ally_hits += 1
	if amount >= 1.0 or (own and int(i["zeros"].get(key, 0)) <= 2 and amount <= 0.0):
		var line := "%.2f %s s%d pf%d" % [amount, kind, from_slot, _pf()]
		i["hits"].append(line)
		print("PT139 HURT %s %s%s" % [i["name"], line, " OWN-SIDE" if own else ""])


func _on_node_added(node: Node) -> void:
	if node is DeathCloud:
		var cloud := node as DeathCloud
		var rec := {"node": cloud, "tag": "", "slot": 0, "at": Vector3.ZERO, "pf": -1, "dist": {}, "range": 0.0, "amount": 0.0}
		_clouds.append(rec)
		cloud.tree_exiting.connect(_on_cloud_exit.bind(rec))
		return
	var script: Variant = node.get_script()
	if script == _POISONED:
		var body := node.get_parent() as Node3D
		var rec2 := {"node": node, "body": _name(body), "per_s": 0.0, "frames": 0, "taken": 0.0, "pf": _pf()}
		_doses.append(rec2)
		doses += 1
		node.tree_exiting.connect(_on_dose_exit.bind(rec2))
		_read_dose.call_deferred(rec2)
		return
	if script == _FIREBALL:
		var rec3 := {"node": node, "slot": 0, "damage": 0.0, "range": 0.0, "at": Vector3.ZERO, "pf": -1, "dist": {},
			"spawn_pf": _pf()}
		_fbs.append(rec3)
		fireballs += 1
		node.tree_exiting.connect(_on_fireball_exit.bind(rec3))
		print("PT139 FIREBALL_SPAWN pf%d" % _pf())
		return
	if script == _SHOT:
		var rec4 := {"node": node, "slot": 0, "shooter": "", "target": "", "spawn": _at(node as Node3D), "target_at": Vector3.ZERO,
			"pf": _pf(), "line": {}, "min_box": {}, "exit_pf": -1, "end": Vector3.ZERO, "read": false}
		_shot_recs.append(rec4)
		shots += 1
		node.tree_exiting.connect(_on_shot_exit.bind(rec4))


func _read_dose(rec: Dictionary) -> void:
	var node: Variant = rec["node"]
	if node == null or not is_instance_valid(node):
		return
	rec["per_s"] = float((node as Node).get("damage_per_s"))
	rec["frames"] = int((node as Node).get("frames_left"))
	print("PT139 DOSE on %s per_s=%.3f frames=%d from=s%d pf%d" % [rec["body"], rec["per_s"], rec["frames"],
		int((node as Node).get("from_slot")), int(rec["pf"])])


func _on_dose_exit(rec: Dictionary) -> void:
	var node: Node = rec["node"]
	rec["taken"] = float(node.get("taken"))
	rec["node"] = null
	doses_done += 1
	print("PT139 DOSE_END on %s taken=%.2f pf%d" % [rec["body"], rec["taken"], _pf()])


func _on_cloud_exit(rec: Dictionary) -> void:
	var cloud: DeathCloud = rec["node"]
	rec["node"] = null
	rec["at"] = _at(cloud)
	rec["pf"] = _pf()
	rec["slot"] = cloud.from_slot
	if cloud.ability:
		rec["tag"] = str(cloud.ability.tag)
		rec["range"] = float(cloud.ability.damage_range_m)
		rec["amount"] = float(cloud.ability.damage)
	for body in _info:
		if is_instance_valid(body) and body != cloud.dead:
			var d := _SPLASH.box_distance(body, rec["at"])
			if d <= 20.0:
				rec["dist"][_info[body]["name"]] = d
	clouds += 1
	print("PT139 CLOUD %s slot=%d at=%s range=%.1f amount=%.1f pf%d dist=%s" % [rec["tag"], rec["slot"], _v(rec["at"]),
		rec["range"], rec["amount"], rec["pf"], str(rec["dist"])])


func _on_fireball_exit(rec: Dictionary) -> void:
	var fb: Node3D = rec["node"]
	rec["node"] = null
	rec["at"] = _at(fb)
	rec["pf"] = _pf()
	rec["slot"] = int(fb.get("from_slot"))
	rec["damage"] = float(fb.get("damage"))
	rec["range"] = float(fb.get("damage_range"))
	for body in _info:
		if is_instance_valid(body):
			var d := _SPLASH.box_distance(body, rec["at"])
			if d <= 30.0:
				rec["dist"][_info[body]["name"]] = d
	fireballs_gone += 1
	print("PT139 FIREBALL_GONE slot=%d at=%s damage=%.1f range=%.2f pf%d dist=%s" % [rec["slot"], _v(rec["at"]),
		rec["damage"], rec["range"], rec["pf"], str(rec["dist"])])


func _read_shot(rec: Dictionary) -> void:
	var shot: Node3D = rec["node"]
	rec["read"] = true
	rec["slot"] = int(shot.get("from_slot"))
	var tp: NodePath = shot.get("target_path")
	var sp: NodePath = shot.get("shooter_path")
	var target := shot.get_node_or_null(tp) as Node3D if not tp.is_empty() else null
	var shooter := shot.get_node_or_null(sp) as Node3D if not sp.is_empty() else null
	rec["target"] = _name(target)
	rec["shooter"] = _name(shooter)
	if target == null:
		return
	rec["target_at"] = _at(target)
	var a: Vector3 = rec["spawn"]
	var b: Vector3 = rec["target_at"]
	var ab := Vector2(b.x - a.x, b.z - a.z)
	for body in _info:
		if not is_instance_valid(body) or body == target or body == shooter:
			continue
		if int(_info[body]["slot"]) != int(rec["slot"]):
			continue
		var p := _at(body)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var t := ap.dot(ab) / maxf(ab.length_squared(), 0.0001)
		var perp := absf(ap.x * ab.y - ap.y * ab.x) / maxf(ab.length(), 0.0001)
		rec["line"][_info[body]["name"]] = "t=%.2f perp=%.2fm" % [t, perp]
	print("PT139 SHOT_SPAWN %s -> %s slot=%d spawn=%s target_at=%s pf%d line(own side)=%s" % [rec["shooter"],
		rec["target"], rec["slot"], _v(a), _v(b), int(rec["pf"]), str(rec["line"])])


func _on_shot_exit(rec: Dictionary) -> void:
	var shot: Node3D = rec["node"]
	rec["end"] = _at(shot)
	rec["exit_pf"] = _pf()
	rec["node"] = null
	shots_gone += 1
	print("PT139 SHOT_GONE %s -> %s at=%s pf%d min_box(own side)=%s" % [rec["shooter"], rec["target"], _v(rec["end"]),
		_pf(), str(rec["min_box"])])


func _physics_process(_delta: float) -> void:
	for rec in _shot_recs:
		var n: Variant = rec["node"]
		if n == null or not is_instance_valid(n):
			continue
		var shot := n as Node3D
		if not rec["read"]:
			_read_shot(rec)
		var p := _at(shot)
		for body in _info:
			if not is_instance_valid(body) or int(_info[body]["slot"]) != int(rec["slot"]):
				continue
			var key: String = _info[body]["name"]
			if key == rec["shooter"] or key == rec["target"]:
				continue
			var d := _SPLASH.box_distance(body, p)
			rec["min_box"][key] = minf(float(rec["min_box"].get(key, INF)), d)


func _world_camera() -> Camera3D:
	if get_tree().current_scene == null:
		return null
	for node in get_tree().current_scene.find_children("*", "Camera3D", true, false):
		if "debug_pointer" in node:
			return node as Camera3D
	return null


func _find(tag: String, slot: int) -> Node3D:
	for body in _info:
		if is_instance_valid(body) and _info[body]["tag"] == tag and int(_info[body]["slot"]) == slot:
			var h: Variant = (body as Node).get_node_or_null("Health")
			if h != null and not bool(h.is_dead()):
				return body
	return null


func aim(tag: String, slot: int, lift: float = 1.0) -> String:
	var view := get_viewport().get_camera_3d()
	var world := _world_camera()
	var body := _find(tag, slot)
	if view == null or world == null or body == null:
		return "aim missing (view=%s world=%s body=%s)" % [view != null, world != null, body != null]
	var screen := view.unproject_position(_at(body) + Vector3.UP * lift)
	world.set("debug_pointer", screen)
	var origin := view.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + view.project_ray_normal(screen) * 10000.0)
	query.collision_mask = 3
	var hit := view.get_world_3d().direct_space_state.intersect_ray(query)
	var under := "none"
	if not hit.is_empty():
		var col: Object = hit["collider"]
		under = _name(col) if col is Node and "owner_slot" in col else "ground/%s" % str((col as Node).name)
	var r := "aim %s at %d,%d under=%s" % [_name(body), int(screen.x), int(screen.y), under]
	print("PT139 " + r)
	return r


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var look := Vector3(x, _ground_y(x, z), z)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed (%.0f, %.0f)" % [x, z]


func frame_on(tag: String, slot: int, ox: float, oy: float, oz: float) -> String:
	var body := _find(tag, slot)
	if body == null:
		return "frame_on missing %s s%d" % [tag, slot]
	var p := _at(body)
	return frame(p.x, p.z, ox, oy, oz)


func _hp(body: Variant) -> float:
	if body == null or not is_instance_valid(body):
		return NAN
	var h: Node = (body as Node).get_node_or_null("Health")
	return float(h.get("current")) if h != null else NAN


func report() -> String:
	for body in _info:
		var i: Dictionary = _info[body]
		var p := _at(body) if is_instance_valid(body) else Vector3.ZERO
		var grudge := "none"
		if is_instance_valid(body) and body.has_meta(GrudgeMemory.META):
			var memory: Variant = body.get_meta(GrudgeMemory.META)
			grudge = "mask=%d" % int(memory.get("mask")) if memory != null else "meta-null"
		print("PT139 STATE %s tag=%s hp0=%.1f now=%.1f/%.1f at=%s hurt=%s zeros=%s grudge=%s" % [i["name"], i["tag"],
			float(i["hp0"]), _hp(body), float(i["max"]), _v(p), str(i["hurt"]), str(i["zeros"]), grudge])
	for c in _clouds:
		print("PT139 CLOUDSUM %s slot=%d at=%s pf%d dist=%s" % [c["tag"], c["slot"], _v(c["at"]), int(c["pf"]), str(c["dist"])])
	for f in _fbs:
		print("PT139 FBSUM slot=%d at=%s damage=%.1f range=%.2f pf%d dist=%s" % [f["slot"], _v(f["at"]), f["damage"],
			f["range"], int(f["pf"]), str(f["dist"])])
	for s in _shot_recs:
		print("PT139 SHOTSUM %s -> %s spawn=%s end=%s pf%d..%d line=%s min_box=%s" % [s["shooter"], s["target"],
			_v(s["spawn"]), _v(s["end"]), int(s["pf"]), int(s["exit_pf"]), str(s["line"]), str(s["min_box"])])
	for d in _doses:
		print("PT139 DOSESUM on %s per_s=%.3f frames=%d taken=%.2f" % [d["body"], d["per_s"], d["frames"], d["taken"]])
	var r := "PT139 REPORT units=%d clouds=%d doses=%d fireballs=%d/%d shots=%d/%d ally_hits=%d pf%d" % [units, clouds,
		doses, fireballs_gone, fireballs, shots_gone, shots, ally_hits, _pf()]
	print(r)
	return r
