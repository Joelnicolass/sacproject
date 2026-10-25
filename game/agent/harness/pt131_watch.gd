extends Node

## Read-only observer for the F131 window run (RFC-030 030t-a: the Netherfiend's and the Hellmouth's Devour on lane D of
## f131_devour_rend). It never moves, orders or damages anything: it reads the bodies and the souls and re-frames the screen camera
## (like a player scrolling the view; the bench camera is fixed).
##
##   frame_on(name, ox, oy, oz)         screen camera at the body + offset, looking at the body (+1 m).
##   frame_between(a, b, ox, oy, oz)    the camera looks at the middle of two bodies.
##   report(name)                       the body: souls eaten (DevourGrowth.shown), bulk, mesh scale, health, resistance factor.
##   souls(name)                        every soul: state, scaling and distance to the body's shot origin (the devoured shrink toward it).
##   height_px(name)                    the body's mesh as the screen sees it: pixel height of its box.
## Props: tick, rel (ticks since the bench started: Enter).

var tick := 0
var rel := -1
var _start := -1
var _bodies: Dictionary = {}


func _ready() -> void:
	process_physics_priority = 1000


func _find(n: String) -> Node3D:
	if _bodies.has(n) and is_instance_valid(_bodies[n]):
		return _bodies[n] as Node3D
	var found := get_tree().root.find_child(n, true, false) as Node3D
	if found:
		_bodies[n] = found
	return found


func _physics_process(_delta: float) -> void:
	tick = MatchClock.now()
	if _start < 0:
		var runner := get_tree().root.find_child("Runner", true, false)
		if runner and bool(runner.get("_running")):
			_start = tick
	rel = tick - _start if _start >= 0 else -1


func report(n: String) -> String:
	var nb := _find(n)
	var line := "PT131 tick %d rel %d · " % [tick, rel]
	if nb == null:
		line += "no %s" % n
	else:
		var growth := DevourGrowth.of(nb)
		var health := nb.get_node("Health") as Health
		var mesh := nb.get_node_or_null("Tilt/Mesh") as Node3D
		line += "%s comidas %s escala %s vida %d/%d resistencia ×%.4f regeneración extra +%.3f/s" % [
			n, str(growth.shown) if growth else "-",
			str(mesh.scale) if mesh else "-", roundi(health.current), roundi(health.maximum),
			DevourGrowth.resistance_factor_of(nb), DevourGrowth.extra_regeneration_of(nb)]
	print(line)
	return line


func souls(n: String) -> String:
	var nb := _find(n)
	var parts: Array[String] = []
	for node in get_tree().get_nodes_in_group(&"soul"):
		var soul := node as Soul
		if soul == null:
			continue
		var to := ""
		if nb != null:
			to = " a %.2f m de %s" % [soul.global_transform.origin.distance_to(ShotAim.shot_position(nb)), n]
		parts.append("%s %s escala %.2f%s" % [soul.label(), Soul.State.keys()[soul.state], soul.scaling, to])
	var line := "PT131 tick %d rel %d · almas: %s" % [tick, rel, " | ".join(parts) if not parts.is_empty() else "ninguna"]
	print(line)
	return line


func height_px(n: String) -> String:
	var nb := _find(n)
	var cam := get_viewport().get_camera_3d()
	var mesh := nb.get_node_or_null("Tilt/Mesh") as MeshInstance3D if nb else null
	if mesh == null or cam == null:
		return "no %s" % n
	var box := mesh.get_aabb()
	var low := INF
	var high := -INF
	for i in 8:
		var corner := mesh.global_transform * box.get_endpoint(i)
		if cam.is_position_behind(corner):
			return "detras"
		var y := cam.unproject_position(corner).y
		low = minf(low, y)
		high = maxf(high, y)
	var line := "PT131 rel %d · %s alto en pantalla %.1f px (vista %s)" % [rel, n, high - low, str(get_viewport().get_visible_rect().size)]
	print(line)
	return line


func _look(target: Vector3, ox: float, oy: float, oz: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.look_at_from_position(target + Vector3(ox, oy, oz), target, Vector3.UP)


func frame_on(n: String, ox: float, oy: float, oz: float) -> String:
	var b := _find(n)
	if b == null:
		return "no %s" % n
	_look(b.global_transform.origin + Vector3(0, 1.0, 0), ox, oy, oz)
	return "framed %s" % n


func frame_between(a: String, b: String, ox: float, oy: float, oz: float) -> String:
	var na := _find(a)
	var nb := _find(b)
	if na == null or nb == null:
		return "no %s/%s" % [a, b]
	_look((na.global_transform.origin + nb.global_transform.origin) * 0.5 + Vector3(0, 1.0, 0), ox, oy, oz)
	return "framed %s-%s" % [a, b]
