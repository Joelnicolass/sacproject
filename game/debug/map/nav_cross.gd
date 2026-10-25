extends Node

## 024b test bed (RFC-024 §6): one own Trogg at Start1 and a marker at Start2. The straight line between
## them crosses the central manafount, so a walk that goes around it is a walk that uses NavService.
## With a window it waits for check_tick (Enter) and then orders the Trogg to the marker through
## Orders.request, the same call a right click on the ground ends in (order_units). Headless it starts by
## itself, measures and prints `NAV_CROSS {json}`, then quits.
##
## Measures: the length of the path A* gives, the time to come within `arrive_m` of the marker, the
## longest stretch standing still, the closest approach to a manafount and the cost of the navmesh and of
## find_path (corner to corner and a seeded handful of others). Nothing here moves the Trogg but the order.

const TAG := "NAV_CROSS "

@export var world: Node3D
## The walker: a UnitBody (ordered through Orders.request) or, with `wizard_slot`, the wizard of that slot
## (spawned here, ordered through request_walk: what order_units does in a WalkOrder scene).
@export var walker: Node3D
@export var wizard_slot := 0
@export var goal: Node3D
## A creature that holds the goal (match_defeat: the Executioner). `--aggro` lets it fight what it sees.
@export var foe: UnitBody
@export var status_label: Label
## «Llegar» is arriving within this many meters of the marker (RFC-024 §6: 5 m).
@export var arrive_m := 5.0
## The path may be this much longer than the A* path before the walk fails (RFC-024 §6: 1.2).
@export var slack := 1.2
@export var still_limit_s := 2.0
@export var timeout_s := 400.0
@export var settle_ticks := 10
## Seeded pairs for the find_path timing, besides the corner to corner one.
@export var extra_paths := 24
@export var follow_with_camera := true
## Width in meters of the ribbons that draw the path (debug only).
@export var ribbon_m := 2.0
## A bird's-eye camera over the map for --overview (the walker's camera otherwise).
@export var overview_camera: Camera3D

const NODES := 512
const NODE_M := 5.0

var _ticks := 0
var _running := false
var _done := false
var _order_tick := 0
var _path := PackedVector3Array()
var _path_len := 0.0
var _straight := 0.0
var _last := Vector3.ZERO
var _still := 0
var _max_still := 0
var _min_fount := INF
var _args: Dictionary = {}
var _headless := false
var _trace: ImmediateMesh
var _crumbs := PackedVector3Array()
var _report: Dictionary = {}


func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	_headless = DisplayServer.get_name() == "headless"
	if foe != null:
		foe.idle_aggro = _args.has("aggro")
	_set_status("Pendiente")
	_make_trace()
	if _headless or _args.has("autostart"):
		_arm.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick") and not _running and not _done:
		_arm()


func _arm() -> void:
	if _running or _done:
		return
	_running = true
	_ticks = 0
	if _args.has("time-scale"):
		Engine.time_scale = float(_args["time-scale"])
	if wizard_slot > 0 and walker == null:
		SacrificeFlow.slot_picks[wizard_slot] = SacrificeFlow.pick
		walker = world.get_node("WizardSpawner").call("spawn_slot", wizard_slot) as Node3D
	if _args.has("nofollow") and walker != null:
		var follower := walker.get_node_or_null("PathFollower")
		if follower:
			follower.free()
	_set_status("Esperando la grilla")


func _physics_process(_delta: float) -> void:
	if not _running or _done:
		return
	_ticks += 1
	var nav := _nav()
	if _order_tick == 0:
		if walker != null and _ticks >= settle_ticks and nav != null and nav.is_ready():
			_order(nav)
		return
	var at := walker.global_position
	var step := Vector2(at.x - _last.x, at.z - _last.z).length()
	_last = at
	if step < 0.02:
		_still += 1
		_max_still = maxi(_max_still, _still)
	else:
		_still = 0
	for fount in get_tree().get_nodes_in_group("manafount"):
		var f := (fount as Node3D).global_position
		_min_fount = minf(_min_fount, Vector2(at.x - f.x, at.z - f.z).length())
	if (_ticks - _order_tick) % 30 == 0:
		_crumbs.append(at)
		_draw()
	var seconds := float(_ticks - _order_tick) / 60.0
	var left := Vector2(at.x - goal.global_position.x, at.z - goal.global_position.z).length()
	_set_status("Caminando · %.0f m del marcador · %.0f s" % [left, seconds])
	if left <= arrive_m:
		_finish("arrived", left)
	elif seconds >= timeout_s:
		_finish("timeout", left)


func _order(nav: NavService) -> void:
	var from := walker.global_position
	var to := goal.global_position
	var started := Time.get_ticks_usec()
	_path = nav.find_path(from, to)
	var first_us := Time.get_ticks_usec() - started
	_path_len = NavService.path_length(from, _path)
	_straight = Vector2(to.x - from.x, to.z - from.z).length()
	_report["build_ms"] = nav.mesh.build_ms
	_report["polygons"] = nav.mesh.polygon_count
	_report["regions"] = nav.mesh.regions.component_count
	_report["same_region"] = nav.same_region(from, to)
	_report["start_us"] = first_us
	_report["find_us"] = _time_paths(nav)
	_report["path_nodes"] = _path.size()
	_report["path_m"] = snappedf(_path_len, 0.1)
	_report["straight_m"] = snappedf(_straight, 0.1)
	_order_tick = _ticks
	_last = from
	_crumbs.append(from)
	if walker is UnitBody:
		world.get_node("%Orders").call("request", [walker], "move", to, null, 0.0)
	else:
		walker.call("request_walk", to)
	if _args.has("overview") and overview_camera != null and not _headless:
		overview_camera.current = true
	elif follow_with_camera and not _headless:
		var camera := world.get_node_or_null("%Camera")
		if camera:
			camera.call("set_follow", walker)
	_draw()
	print("nav_cross: orden de %.0f m en línea recta, camino %.0f m con %d puntos" % [_straight, _path_len, _path.size()])


func _finish(reason: String, left: float) -> void:
	_done = true
	_running = false
	Engine.time_scale = 1.0
	var seconds := float(_ticks - _order_tick) / 60.0
	var speed := float(walker.get("move_speed")) * float(walker.get("speed_factor"))
	var limit := slack * _path_len / maxf(speed, 0.001)
	_report["reason"] = reason
	_report["seconds"] = snappedf(seconds, 0.1)
	_report["limit_s"] = snappedf(limit, 0.1)
	_report["speed"] = speed
	_report["left_m"] = snappedf(left, 0.1)
	_report["max_still_s"] = snappedf(float(_max_still) / 60.0, 0.01)
	_report["min_fount_m"] = snappedf(_min_fount, 0.1)
	_report["ok"] = reason == "arrived" and seconds <= limit and float(_max_still) / 60.0 <= still_limit_s
	_set_status("%s · %.1f s de %.1f · quieto máx %.1f s" % ["Llegó" if reason == "arrived" else "No llegó", seconds, limit, float(_max_still) / 60.0])
	print(TAG + JSON.stringify(_report))
	if _args.has("grid-png"):
		_dump_grid(str(_args["grid-png"]))
	if _args.has("out"):
		var file := FileAccess.open(str(_args["out"]), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(_report, "  "))
	_draw()
	if _headless or _args.has("quit"):
		get_tree().quit(0 if bool(_report["ok"]) else 1)


## Microseconds of the slowest find_path among: the corner to corner walk of the scene and `extra_paths`
## seeded pairs of land points, plus the cost of the mean. Also a list for the report.
func _time_paths(nav: NavService) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	var land: Array[Vector3] = []
	var tries := 0
	while land.size() < extra_paths * 2 and tries < 20000:
		tries += 1
		var i := rng.randi_range(0, NODES - 1)
		var j := rng.randi_range(0, NODES - 1)
		var point := _node_point(Vector2i(i, j))
		if nav.is_free_at(point):
			land.append(point)
	var worst := 0
	var total := 0
	var count := 0
	var from := walker.global_position
	var pairs: Array = [[from, goal.global_position]]
	for k in range(0, land.size() - 1, 2):
		pairs.append([land[k], land[k + 1]])
	for pair in pairs:
		var t := Time.get_ticks_usec()
		var path: PackedVector3Array = nav.find_path(pair[0], pair[1])
		var us := Time.get_ticks_usec() - t
		worst = maxi(worst, us)
		total += us
		count += 1
		if path.is_empty():
			push_warning("nav_cross: sin camino")
	return {"worst": worst, "mean": total / maxi(count, 1), "pairs": count}


## A picture of the grid for the reviewer: free nodes grey, blocked white-on-black, the planned path red,
## where the Trogg went cyan, the manafounts and altars yellow. 4 px per node over the playable part.
func _dump_grid(path: String) -> void:
	var nav := _nav()
	if nav == null:
		return
	var scale := 4
	var x0 := 170
	var x1 := 340
	var z0 := 150
	var z1 := 340
	var image := Image.create((x1 - x0) * scale, (z1 - z0) * scale, false, Image.FORMAT_RGB8)
	image.fill(Color(0.05, 0.05, 0.08))
	for j in range(z0, z1):
		for i in range(x0, x1):
			if nav.is_free_at(_node_point(Vector2i(i, j))):
				image.fill_rect(Rect2i((i - x0) * scale, (j - z0) * scale, scale, scale), Color(0.45, 0.5, 0.45))
	for group in ["manafount", "altar"]:
		for node in get_tree().get_nodes_in_group(group):
			var at := _node_of((node as Node3D).global_position)
			image.fill_rect(Rect2i((at.x - x0) * scale - 2, (at.y - z0) * scale - 2, scale + 4, scale + 4), Color(1.0, 0.9, 0.1))
	for point in _path:
		var n := _node_of(point)
		image.fill_rect(Rect2i((n.x - x0) * scale - 1, (n.y - z0) * scale - 1, scale + 2, scale + 2), Color(1.0, 0.2, 0.1))
	for point in _crumbs:
		var n := _node_of(point)
		image.fill_rect(Rect2i((n.x - x0) * scale, (n.y - z0) * scale, scale, scale), Color(0.1, 0.9, 1.0))
	image.save_png(path)


## The 5 m lattice of the debug picture and of the seeded land points (the old grid's nodes; node (i, j) stands at world (5i, 5j)).
func _node_of(point: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi(point.x / NODE_M), 0, NODES - 1), clampi(roundi(point.z / NODE_M), 0, NODES - 1))


func _node_point(node: Vector2i) -> Vector3:
	return Vector3(float(node.x) * NODE_M, 0.0, float(node.y) * NODE_M)


func _nav() -> NavService:
	return get_tree().get_first_node_in_group(NavService.GROUP) as NavService


func _make_trace() -> void:
	_trace = ImmediateMesh.new()
	var node := MeshInstance3D.new()
	node.mesh = _trace
	node.name = "Trace"
	node.top_level = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	add_child(node)


## The planned path in red, where the walker has been in cyan: flat ribbons over the ground, so they
## read from a bird's-eye camera too.
func _draw() -> void:
	_trace.clear_surfaces()
	if _path.size() > 0:
		var planned := PackedVector3Array()
		planned.append(_crumbs[0] if not _crumbs.is_empty() else _path[0])
		planned.append_array(_path)
		_ribbon(planned, ribbon_m * 1.5, Color(1.0, 0.2, 0.1), 3.0)
	if _crumbs.size() > 1:
		_ribbon(_crumbs, ribbon_m, Color(0.1, 0.9, 1.0), 3.6)


func _ribbon(points: PackedVector3Array, width: float, color: Color, lift: float) -> void:
	if points.size() < 2:
		return
	_trace.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_trace.surface_set_color(color)
	for k in points.size() - 1:
		var a := points[k] + Vector3.UP * lift
		var b := points[k + 1] + Vector3.UP * lift
		var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if along.length_squared() < 0.0001:
			continue
		var side := along.normalized().cross(Vector3.UP) * width * 0.5
		_trace.surface_add_vertex(a - side)
		_trace.surface_add_vertex(a + side)
		_trace.surface_add_vertex(b + side)
		_trace.surface_add_vertex(a - side)
		_trace.surface_add_vertex(b + side)
		_trace.surface_add_vertex(b - side)
	_trace.surface_end()


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


static func _parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var cut := body.find("=")
		if cut < 0:
			out[body] = true
		else:
			out[body.substr(0, cut)] = body.substr(cut + 1)
	return out
