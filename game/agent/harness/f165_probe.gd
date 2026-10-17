extends Node

## F165 (RFC-030): what the AgentKit flow agent/flows/f165_divine_sight.json reads of the Divine Sight eye. It does not play: the flow
## clicks the Ranger's ability button like a player; this node only watches every physics tick and keeps numbers the flow can
## assert on (properties, read with {"assert": {"node": "AgentKit/f165_probe", "prop": ...}}). AgentKit mounts every script of this
## folder under its autoload on each flow run, so this one stays inert unless the scene is debug/f165_divine_sight.tscn. Nothing here
## is read by the game.
##
## Own side = 1 (the Ranger), foe side = 2 (the still Druid), as debug/ability_spit.gd spawns them.

const SCENE := "res://debug/f165_divine_sight.tscn"
const SIDE := 1
const FOE_SIDE := 2

var ranger: UnitBody
var foe: UnitBody
var vision: SideVision
var _armed := false
var _pose := Vector4.ZERO
var _has_pose := false
var _start_at := Vector3.ZERO
var _forward := Vector3.ZERO

## Numbers of the eye seen so far.
var eye_seen := false
var eye_name := ""
var eye_frame := 0
var eye_scale := 0.0
var eye_target := ""
## Where the eye was first seen, relative to the Ranger: along its facing and sideways (m).
var spawn_ahead_m := -1.0
var spawn_side_m := -1.0
## The most the eye moved on the ground during the rise (frame < 45), and the fastest it ever went (m/s).
var rise_drift_m := 0.0
var max_speed_mps := 0.0
## The least height over the land after the rise.
var min_clear_m := 1000.0
## Flat distance from the eye to the foe's center now, and the smallest ever.
var eye_to_foe_m := 1000.0
var closest_to_foe_m := 1000.0
var locked_frame := -1
var _spawn_xz := Vector2.ZERO
var _last_pos := Vector3.ZERO
var _prev_valid := false

## SideVision answers about the eye's side.
var sees_foe := false
var sees_beside_60 := false
var sees_beside_90 := false
var sees_behind_ranger_90 := false
var visible_cells := 0
var explored_foe := false

var eye_count: int:
	get:
		return get_tree().get_nodes_in_group(DivineSightEye.GROUP).size() if is_inside_tree() else 0
var eye_gone: bool:
	get:
		return eye_seen and eye_count == 0
var mana: float:
	get:
		return float(ranger.get_node("ManaPool").get("current")) if is_instance_valid(ranger) else -1.0


func _physics_process(_delta: float) -> void:
	var current := get_tree().current_scene
	if current == null or current.scene_file_path != SCENE:
		return
	if not _armed:
		_armed = true
		DivineSightEye.log_eye = true
		AbilityEffect.log_effects = true
		ActiveAbility.log_ability = true
	if not is_instance_valid(ranger) or not is_instance_valid(foe):
		_find_bodies()
		return
	if vision == null:
		vision = get_tree().get_first_node_in_group(SideVision.GROUP) as SideVision
	var eyes := get_tree().get_nodes_in_group(DivineSightEye.GROUP)
	if not eyes.is_empty():
		_sample(eyes[0] as DivineSightEye)
	if vision:
		_read_vision(_last_pos)


func _find_bodies() -> void:
	for node in get_tree().get_nodes_in_group("unit"):
		var body := node as UnitBody
		if body == null or not body.is_inside_tree():
			continue
		if body.owner_slot == SIDE and not is_instance_valid(ranger):
			ranger = body
			_start_at = _at(body)
			_forward = body.facing_flat()
		elif body.owner_slot == FOE_SIDE and not is_instance_valid(foe):
			foe = body


func _sample(eye: DivineSightEye) -> void:
	var here := _at(eye)
	if not eye_seen:
		eye_seen = true
		var offset := here - _start_at
		spawn_ahead_m = offset.dot(_forward)
		spawn_side_m = absf(offset.dot(_forward.cross(Vector3.UP)))
		_spawn_xz = Vector2(here.x, here.z)
	eye_name = str(eye.name)
	eye_frame = eye.frame
	eye_scale = eye.scale.x
	eye_target = str(eye.target.name) if eye.target else ""
	if eye.target and locked_frame < 0:
		locked_frame = eye.frame
	if eye.frame < eye.rising_ticks:
		rise_drift_m = maxf(rise_drift_m, Vector2(here.x, here.z).distance_to(_spawn_xz))
	## The rise starts with a jump from the land to half the flying height (sacengine position.z = getHeight + 2 at frame 0): not flying yet.
	if _prev_valid and eye.frame >= eye.rising_ticks:
		var speed := here.distance_to(_last_pos) * float(MatchClock.TICKS_PER_SECOND)
		if speed > 31.0:
			print("sonda salto del ojo en el cuadro %d (tick %d): %.2f m/s de %s a %s" % [eye.frame, MatchClock.now(), speed, _last_pos, here])
		max_speed_mps = maxf(max_speed_mps, speed)
	var land := RangedShot.land_height(eye, here)
	if eye.frame >= eye.rising_ticks and land > -INF:
		min_clear_m = minf(min_clear_m, here.y - land)
	var center := BodyNudge.center(foe)
	eye_to_foe_m = Vector2(here.x - center.x, here.z - center.z).length()
	closest_to_foe_m = minf(closest_to_foe_m, eye_to_foe_m)
	_last_pos = here
	_prev_valid = true


func _read_vision(eye_at: Vector3) -> void:
	var side := _forward.cross(Vector3.UP)
	var foe_at := _at(foe)
	visible_cells = vision.visible_cell_count(SIDE)
	sees_foe = vision.position_visible_to(SIDE, foe_at)
	explored_foe = vision.position_explored_by(SIDE, foe_at)
	sees_beside_60 = vision.position_visible_to(SIDE, eye_at + side * 60.0) and vision.position_visible_to(SIDE, eye_at - side * 60.0)
	sees_beside_90 = vision.position_visible_to(SIDE, eye_at + side * 90.0) or vision.position_visible_to(SIDE, eye_at - side * 90.0)
	sees_behind_ranger_90 = vision.position_visible_to(SIDE, _start_at - _forward * 90.0)


func _at(node: Node3D) -> Vector3:
	return node.global_transform.origin


## The screen camera at one fixed pose for the captures (the flow calls it before each shot): `cam_ahead` m along the Ranger's facing,
## `cam_side` m beside it and `cam_up` m high, looking at the point `look_ahead` m ahead (4 m up). Same pose on every run (it only
## reads the Ranger's first spot).
## The pose is kept every frame (the screen camera's own rig would drift back to its player view): it stays until the next call.
func frame_fixed(cam_ahead: float, cam_side: float, cam_up: float, look_ahead: float) -> String:
	if not is_instance_valid(ranger):
		return "no ranger"
	_pose = Vector4(cam_ahead, cam_side, cam_up, look_ahead)
	_has_pose = true
	process_priority = 1000
	return "framed" if _apply_pose() else "no camera"


func _process(_delta: float) -> void:
	if _has_pose:
		_apply_pose()


func _apply_pose() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_instance_valid(ranger):
		return false
	var looked_at := _start_at + _forward * _pose.w + Vector3.UP * 4.0
	camera.look_at_from_position(_start_at + _forward * _pose.x + _forward.cross(Vector3.UP) * _pose.y + Vector3.UP * _pose.z, looked_at, Vector3.UP)
	return true
