extends Node

## Observation only (RFC-021c playtest): frames the world camera on a point after the game's own camera
## placed itself, and when the local wizard jumps (a move of more than JUMP_M in one frame) takes three
## screenshots by itself: the origin right after the jump, the destination a moment later and the
## formation seen from above. Touches no actor. release() hands the camera back (picking needs it).

const JUMP_M := 20.0

var _hold := false
var _center := Vector3.ZERO
var _dist := 30.0
var _height := 8.0
var _yaw := 90.0
var _armed := false
var _out := ""
var _prev := Vector3.INF
var _origin := Vector3.ZERO
var _jump_t := -1.0
var _shots := 0
var text := "sin salto"
var _shooting := false
var _watch_name := ""
var _track_prev := Vector3.INF
var _max_step := 0.0
var _steps_taken := 0


func _ready() -> void:
	process_priority = 1000


func frame_on(x: float, y: float, z: float, dist: float = 30.0, height: float = 8.0, yaw: float = 90.0) -> void:
	_hold = true
	_center = Vector3(x, y, z)
	_dist = dist
	_height = height
	_yaw = yaw


func release() -> void:
	_hold = false


## `out` is an absolute folder; names f64_<n>_<what>.png.
## `watch` is the name of the node whose jump is looked for (a peer's wizard); empty = the local wizard.
func arm(out: String, watch: String = "") -> void:
	_watch_name = watch
	_armed = true
	_out = out
	DirAccess.make_dir_recursive_absolute(out)


func report() -> String:
	var root := get_tree().current_scene
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	var altar: Node3D = null
	for node in get_tree().get_nodes_in_group("altar"):
		if int(node.get("owner_slot")) == 1:
			altar = node as Node3D
	var parts := PackedStringArray()
	if wizard and altar:
		parts.append("mago %.1f m del altar (%.1f, %.1f, %.1f)" % [_flat(wizard.global_transform.origin, altar.global_transform.origin), wizard.global_transform.origin.x, wizard.global_transform.origin.y, wizard.global_transform.origin.z])
	for n in ["Pack1", "Pack2", "Pack3", "Stray"]:
		var body := root.find_child(n, true, false) as Node3D if root else null
		if body and altar:
			parts.append("%s %.1f m del altar, %.1f del mago" % [n, _flat(body.global_transform.origin, altar.global_transform.origin), _flat(body.global_transform.origin, wizard.global_transform.origin) if wizard else -1.0])
	text = "; ".join(parts)
	return text


## Largest move of the watched wizard in one frame, and in how many frames it moved: a jump that is
## not smoothed is one big step; a glide is many small ones.
func steps() -> String:
	return "paso maximo %.1f m en un cuadro, %d cuadros con movimiento" % [_max_step, _steps_taken]


func altar_position() -> Variant:
	for node in get_tree().get_nodes_in_group("altar"):
		if int(node.get("owner_slot")) == 1:
			return (node as Node3D).global_transform.origin
	return null


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _process(delta: float) -> void:
	var root := get_tree().current_scene
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	if not _watch_name.is_empty() and root:
		wizard = root.find_child(_watch_name, true, false) as Node3D
	if wizard:
		var here := wizard.global_transform.origin
		if _track_prev != Vector3.INF:
			var step := _flat(here, _track_prev)
			if step > _max_step:
				_max_step = step
			if step > 0.001:
				_steps_taken += 1
		_track_prev = here
	if _armed and wizard:
		var now := wizard.global_transform.origin
		if _prev != Vector3.INF and _jump_t < 0.0 and _flat(now, _prev) > JUMP_M:
			_origin = _prev
			_jump_t = 0.0
			text = "salto de %.1f m" % _flat(now, _prev)
			print("TELEPORT_WATCH ", text)
		_prev = now
		if _jump_t >= 0.0:
			_jump_t += delta
			_phases(cam, wizard)
			return
	if _hold and cam:
		_place(cam, _center, _dist, _height, _yaw)


func _phases(cam: Camera3D, wizard: Node3D) -> void:
	if cam == null:
		return
	var dest := wizard.global_transform.origin + Vector3.UP
	if _jump_t < 0.35:
		_place(cam, _origin + Vector3.UP, 12.0, 3.0, 180.0)
		if _shots == 0 and _jump_t > 0.12:
			_shoot("origin")
	elif _jump_t < 1.2:
		_place(cam, dest, 9.0, 2.5, 180.0)
		if _shots == 1 and _jump_t > 0.4:
			_shoot("destination")
	else:
		_place(cam, dest, 24.0, 22.0, 180.0)
		if _shots == 2 and _jump_t > 1.6:
			_shoot("formation")


func _shoot(what: String) -> void:
	if _shooting:
		return
	_shooting = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/f64_%d_%s.png" % [_out, _shots, what])
	var root := get_tree().current_scene
	var who := PackedStringArray()
	for n in ["Wizard1", "Wizard2", "Pack1"]:
		var body := root.find_child(n, true, false) as Node3D if root else null
		if body:
			who.append("%s %s" % [n, str(body.global_transform.origin)])
	print("TELEPORT_WATCH shot ", what, " camara ", str(get_viewport().get_camera_3d().global_transform.origin), " ", "; ".join(who))
	_shots += 1
	_shooting = false


func _place(cam: Camera3D, center: Vector3, dist: float, height: float, yaw_deg: float) -> void:
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	cam.position = center + dir * dist + Vector3(0, height, 0)
	cam.look_at(center, Vector3.UP)
