extends Node

## RFC-024 024d: the Sac Doctors walk by waypoints (PathFollower), the debt of F73. The scene: the real High Noon (the real NavService), a
## Farmer killed >= 150 m from the altar of slot 1 with a pillar in the middle of the way; the wizard of slot 1 casts Convert on its soul.
## The carrier doctor has to go to the corpse, pump, carry it around the pillar and the ritual of the altar has to give the soul.
## Prints `DOCTOR_PATH_RESULT {json}` and quits (headless) with exit code 0 when it passed. Options after `--`:
##   --nofollow   the control: the carrier loses its PathFollower, so it walks in a line as before 024d (it must fail at the pillar)
##   --nopillar   no pillar (a plain 170 m walk)
##   --distance=  metres from the altar to the Farmer (170)
##   --radius=    radius of the pillar (22); the wall is 4 x radius wide
##   --shape=     wall (default) or cylinder
##   --timeout=   seconds of game time to wait (240)

@export var world_scene: PackedScene
@export var rules: MatchRules

var _args := {}
var _world: Node3D
var _converted := 0
var _stuck := 0
var _doctor_tracks: Dictionary = {}
var _log := {}
var _line_dir := Vector3.FORWARD


func _ready() -> void:
	_args = _parse(OS.get_cmdline_user_args())
	_world = world_scene.instantiate()
	_world.set("rules", rules.duplicate())
	var population := _world.get_node_or_null("%Population")
	if population:
		population.set("spawn_creatures", false)
	add_child(_world)
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _run() -> void:
	await _frames(30)
	var windowed := DisplayServer.get_name() != "headless"
	var altar: Node3D
	for node in get_tree().get_nodes_in_group(Altar.GROUP):
		if int(node.get("owner_slot")) == 1:
			altar = node as Node3D
	var distance := float(_args.get("distance", 170.0))
	var toward := Vector3(1270.0, 0.0, 1270.0) - altar.global_position
	toward.y = 0.0
	toward = toward.normalized()
	_line_dir = toward
	var spot := BenchEvents.find_spot(_world, altar.global_position, toward, distance, 0.0, false)
	var straight := Vector2(spot.x - altar.global_position.x, spot.z - altar.global_position.z).length()
	_log["altar"] = _fmt(altar.global_position)
	_log["farmer_at"] = _fmt(spot)
	_log["flat_distance_m"] = snappedf(straight, 0.1)
	var middle := altar.global_position.lerp(spot, 0.5)
	var radius := float(_args.get("radius", 22.0))
	if not _args.has("nopillar"):
		_put_pillar(middle, radius)
		var nav := get_tree().get_first_node_in_group(NavService.GROUP) as NavService
		nav.build()
		await _frames(3)
	if windowed:
		_look_at_the_way(altar.global_position, spot, middle)
	_log["pillar"] = {"at": _fmt(middle), "radius": radius} if not _args.has("nopillar") else "none"
	## The doctors are watched as they appear.
	var doctors_root: Node = _world.get_node("SacrificeSystem").doctors_root
	doctors_root.child_entered_tree.connect(_on_doctor.bind(altar.global_position, spot))
	var souls := _world.get_node("SoulSystem")
	var sacrifice := _world.get_node("SacrificeSystem")
	sacrifice.souls_converted.connect(func(slot: int, count: int, _origin: StringName) -> void: _converted += count if slot == 1 else 0)
	## The Farmer (a villager of the map: slot 3) dies where it stands; its soul stays red on the corpse.
	var farmer: Node3D = _world.get_node("UnitSpawner").call("spawn_unit", {
		"tag": "zepe", "label": "Farmer", "slot": 3, "x": spot.x, "y": spot.y, "z": spot.z, "yaw": 0.0,
		"npc": true, "peasant": true})
	await _frames(20)
	farmer.get_node("Health").call("damage", 1.0e9, 1)
	var wizard := _wizard(1)
	var back := (altar.global_position - spot)
	back.y = 0.0
	var stand := BenchEvents.find_spot(_world, spot, back.normalized(), 14.0, 0.0, false)
	wizard.call("warp_to", stand)
	await _frames(10)
	var soul: Soul
	var waited := 0
	while soul == null and waited < 900:
		await _frames(10)
		waited += 10
		for node in get_tree().get_nodes_in_group("soul"):
			if (node as Soul).corpse == farmer and sacrifice.convert_status(1, node).is_empty():
				soul = node as Soul
	_log["soul_ready_after_s"] = snappedf(float(waited) / 60.0, 0.1)
	if soul == null:
		_finish(false, "no hay un alma convertible")
		return
	var caster := wizard.get_node("Caster")
	var answers: Array[String] = []
	caster.connect("feedback", func(text: String) -> void: answers.append(text))
	caster.call("request_cast", "ccas", soul.global_position, soul)
	_log["cast_answers"] = answers
	var started := Engine.get_physics_frames()
	var timeout := int(float(_args.get("timeout", 240.0)) * 60.0)
	while _converted == 0 and Engine.get_physics_frames() - started < timeout and _stuck_total() == 0:
		await _frames(6)
		_sample()
	var seconds := float(Engine.get_physics_frames() - started) / 60.0
	_log["seconds"] = snappedf(seconds, 0.1)
	_log["converted_souls"] = _converted
	_log["stuck_doctors"] = _stuck
	_log["doctors"] = _doctor_report(altar.global_position, spot, middle, radius)
	_finish(_converted > 0, "")


func _stuck_total() -> int:
	return _stuck


func _put_pillar(at: Vector3, radius: float) -> void:
	var pillar := StaticBody3D.new()
	pillar.name = "Pillar"
	pillar.collision_layer = 1
	pillar.add_to_group(&"nav_blocker")
	var shape := CollisionShape3D.new()
	var visual_mesh: Mesh
	if _args.get("shape", "wall") == "wall":
		## A wall across the way (a 4x`radius*4` m slab, perpendicular to the line from the altar): a body that pushes against it
		## head-on does not slide round it, so only a path gets past (a cylinder it simply slides along).
		var box := BoxShape3D.new()
		box.size = Vector3(radius * 4.0, 30.0, 4.0)
		shape.shape = box
		var slab := BoxMesh.new()
		slab.size = box.size
		visual_mesh = slab
		pillar.rotation.y = atan2(_line_dir.x, _line_dir.z)
	else:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = 30.0
		shape.shape = cylinder
		var round_mesh := CylinderMesh.new()
		round_mesh.top_radius = radius
		round_mesh.bottom_radius = radius
		round_mesh.height = 30.0
		visual_mesh = round_mesh
	pillar.add_child(shape)
	_world.add_child(pillar)
	var terrain := _world.get_node("Map/Terrain")
	var ground := float(terrain.call("ground_height", at.x, at.z))
	pillar.global_position = Vector3(at.x, (0.0 if is_nan(ground) else ground) + 15.0, at.z)
	var mesh := MeshInstance3D.new()
	mesh.mesh = visual_mesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.15, 0.1, 0.85)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = paint
	pillar.add_child(mesh)


func _on_doctor(node: Node, _altar: Vector3, _spot: Vector3) -> void:
	var doctor := node as DoctorBody
	if doctor == null:
		return
	if _args.has("nofollow"):
		var follower := doctor.get_node_or_null("PathFollower")
		if follower != null:
			follower.queue_free()
			doctor._path_follower = null
	doctor.stuck.connect(func() -> void: _stuck += 1)
	_doctor_tracks[doctor.get_instance_id()] = {"node": doctor, "name": str(doctor.name), "samples": PackedVector3Array()}


func _sample() -> void:
	for id in _doctor_tracks.keys():
		var doctor: Variant = _doctor_tracks[id]["node"]
		if is_instance_valid(doctor) and not (doctor as DoctorBody).is_dead():
			var samples: PackedVector3Array = _doctor_tracks[id]["samples"]
			samples.append((doctor as DoctorBody).global_position)
			_doctor_tracks[id]["samples"] = samples


## For each doctor: the length of what it walked and how close it came to the pillar (it must stay out of the radius).
func _doctor_report(altar: Vector3, spot: Vector3, middle: Vector3, radius: float) -> Array:
	var out := []
	for id in _doctor_tracks.keys():
		var track: Dictionary = _doctor_tracks[id]
		var samples: PackedVector3Array = track["samples"]
		var length := 0.0
		var closest := INF
		var crossed := 0
		for k in samples.size():
			if k > 0:
				length += Vector2(samples[k].x - samples[k - 1].x, samples[k].z - samples[k - 1].z).length()
			closest = minf(closest, Vector2(samples[k].x - middle.x, samples[k].z - middle.z).length())
			if k > 0:
				var a := samples[k - 1] - middle
				var b := samples[k] - middle
				var along_a := a.dot(_line_dir)
				var along_b := b.dot(_line_dir)
				var side := (a + b) * 0.5
				var across := absf(side.dot(Vector3(-_line_dir.z, 0.0, _line_dir.x)))
				if along_a * along_b < 0.0 and across < radius * 2.0:
					crossed += 1
		out.append({"doctor": track["name"], "samples": samples.size(), "walked_m": snappedf(length, 0.1), "closest_to_pillar_m": snappedf(closest, 0.1) if closest < INF else -1.0, "crossed_the_wall": crossed})
	return out


func _wizard(slot: int) -> Node3D:
	for wizard in get_tree().get_nodes_in_group("wizard"):
		if int(wizard.get("owner_slot")) == slot:
			return wizard as Node3D
	return null


func _finish(ok: bool, why: String) -> void:
	_log["ok"] = ok
	_log["nofollow"] = _args.has("nofollow")
	if not why.is_empty():
		_log["why"] = why
	print("DOCTOR_PATH_RESULT " + JSON.stringify(_log))
	print("DOCTOR_PATH " + ("PASS" if ok else "FAIL"))
	## With a window it stays on screen (the playtest takes its pictures); headless it quits with the verdict.
	if DisplayServer.get_name() == "headless" or _args.has("quit"):
		get_tree().quit(0 if ok else 1)


static func _fmt(at: Vector3) -> String:
	return "%.1f,%.1f,%.1f" % [at.x, at.y, at.z]


static func _parse(raw: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in raw:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var cut := body.find("=")
		if cut < 0:
			out[body] = true
		else:
			out[body.substr(0, cut)] = body.substr(cut + 1)
	return out


## A camera above the middle of the way, high enough to see the wall, the corpse and the altar (window only).
func _look_at_the_way(altar: Vector3, spot: Vector3, middle: Vector3) -> void:
	var camera := Camera3D.new()
	camera.far = 4000.0
	add_child(camera)
	camera.global_position = middle + _line_dir * 130.0 + Vector3.UP * 85.0
	camera.look_at(middle, Vector3.UP)
	camera.current = true
	_camera = camera
	_middle = middle


var _camera: Camera3D
var _middle := Vector3.ZERO


## With a window the camera follows the first carrier doctor from the side (45 m off, 28 m up), so the picture shows it going round the wall.
func _process(_delta: float) -> void:
	if _camera == null:
		return
	for id in _doctor_tracks.keys():
		var doctor: Variant = _doctor_tracks[id]["node"]
		if is_instance_valid(doctor) and not (doctor as DoctorBody).is_dead() and str(_doctor_tracks[id]["name"]) == "Doctor1":
			var at := (doctor as DoctorBody).global_position
			var side := Vector3(-_line_dir.z, 0.0, _line_dir.x)
			_camera.global_position = at + side * 40.0 + _line_dir * 25.0 + Vector3.UP * 28.0
			_camera.look_at(at + Vector3.UP * 2.0, Vector3.UP)
			return
