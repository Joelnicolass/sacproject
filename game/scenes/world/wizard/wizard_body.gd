class_name WizardBody
extends CharacterBody3D

## One per player slot (WizardSpawner). The server (or solo) simulates the body;
## only the owning client sends drive/walk commands.

signal walk_changed(walking: bool)
signal pick_changed

@export var step: WalkStep
@export var owner_slot := 0:
	set(value):
		owner_slot = value
		_refresh_owner()
## WizardType tag (cwa0…). The server sets it from SacrificeFlow.pick_for(owner_slot).
@export var wizard_tag := "":
	set(value):
		wizard_tag = value
		_apply_type()
		pick_changed.emit()
@export var model := "":
	set(value):
		model = value
		_apply_model()
		pick_changed.emit()
@export var god := "":
	set(value):
		god = value
		pick_changed.emit()
## Wizard level (RFC-030 030b): the Spellbook keeps the entries up to it. The server sets it from
## MatchRules.wizard_level (WizardSpawner) and replicates it like `god`.
@export_range(1, 9) var level := 1:
	set(value):
		if value == level:
			return
		level = value
		pick_changed.emit()
## RFC-030 030c: added to the WIZD health and mana when the server sets the stats up (makeWizard, state.d:2307-2311).
## WizardSpawner fills them from MatchRules (wizard_level_stats); 0 keeps the WIZD numbers.
@export var level_health_bonus := 0.0
@export var level_mana_bonus := 0.0
## Ray mask used to seat the body on the ground after spawning.
@export_flags_3d_physics var ground_mask := 1
@export var seat_attempts := 12
## sacengine regenerates only in idle and not during a damage animation (state.d:1429).
@export var regen_pause_s := 0.5

const REST_FACING := Vector3(0.0, 0.0, 1.0)
const TURN_RATE := PI
const MANA_SOURCE := preload("res://scenes/world/mana_source.gd")
## RFC-023 (023d): 1 rest loop in GESTURE_EVERY ends in the idle0 gesture (sacengine rolls 1 in 5), like the units.
const GESTURE_EVERY := 5

var move_speed: float = 0.0
## Speedup sets it on the server (or solo); the pace is multiplied by it.
var speed_factor := 1.0
var look_yaw := 0.0
var _goal := Vector3.ZERO
var _walking := false
var _net_forward := 0.0
var _net_yaw := 0.0
var _seat_left := 0
var _stats_ready := false
var _since_damage := INF
var _last_health := 0.0
var _mesh_base_pos := Vector3.ZERO
var _mesh_base_rot := Vector3.ZERO
var _type: WizardType
var _present_prev_pos := Vector3.ZERO
var _present_prev_ready := false
var _present_flat_speed := 0.0
var _debug_clip_role := ""
var _idle_loops := 0
var _gesturing := false
## The speed the last _update_clip_state saw (a gesture that ends re-picks the pose with it).
var _clip_flat_speed := 0.0

@onready var health: Node = $Health
@onready var mana: Node = $ManaPool
@onready var souls: Node = $SoulPurse
@onready var ghost: Node = $GhostForm
@onready var _clip_pose: Node = $ClipPose
## The cast in progress as every peer sees it: `cast_fx_shown` is replicated, so the pose follows it on a client too.
@onready var _caster: Node = $Caster
## F138 (RFC-030i-c): the one owner of «held» (stunned, petrified); walking, turning, casting and summoning ask it.
@onready var _afflictions: Afflictions = $Afflictions


func _ready() -> void:
	add_to_group("wizard")
	_refresh_owner()
	floor_snap_length = 0.5
	look_yaw = rotation.y
	_net_yaw = rotation.y
	_apply_model()
	var mesh := get_node_or_null("Tilt/Mesh") as Node3D
	if mesh:
		_mesh_base_pos = mesh.position
		_mesh_base_rot = mesh.rotation
		if _clip_pose.has_method("setup"):
			_clip_pose.call("setup", model, _clip_roles(), _mesh_base_pos, _mesh_base_rot)
	if _clip_pose.has_signal("clip_looped"):
		_clip_pose.connect("clip_looped", _on_clip_looped)
	_present_prev_pos = global_position
	_present_prev_ready = true
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_seat_left = seat_attempts
	health.changed.connect(_on_health_changed)
	_apply_pick()
	SacrificeFlow.slot_picks_changed.connect(_apply_pick)


func _exit_tree() -> void:
	if SacrificeFlow.slot_picks_changed.is_connected(_apply_pick):
		SacrificeFlow.slot_picks_changed.disconnect(_apply_pick)


func is_local() -> bool:
	return owner_slot > 0 and owner_slot == MpKit.local_slot()


## Creatures and spells only pick a living wizard: not one dying or a ghost (GhostForm).
func is_targetable() -> bool:
	return ghost.call("is_targetable")


func is_ghost() -> bool:
	return ghost.call("is_ghost")


## Escorts and retreats keep following a ghost (GhostForm.is_guard_target).
func is_guard_target() -> bool:
	return ghost.call("is_guard_target")


## BodySeparation: a ghost still pushes and is pushed (state.d:117, 125).
func is_obstacle() -> bool:
	return ghost.call("is_obstacle")


## sacengine canCast: idle or moving; a stunned or petrified wizard is neither (Caster cuts a cast in progress).
func can_cast() -> bool:
	return ghost.call("can_cast") and not _afflictions.holds()


func can_take_mana() -> bool:
	return ghost.call("can_take_mana")


func can_collect_souls() -> bool:
	return ghost.call("can_collect_souls")


func spellbook_visible() -> bool:
	return ghost.call("spellbook_visible")


## Its WizardType: Afflictions/Stunned reads the stun clips from it.
func clip_type() -> WizardType:
	return _type


func display_name() -> String:
	if _type:
		return _type.display_name
	return model


func _refresh_owner() -> void:
	if not is_inside_tree():
		return
	if is_local():
		add_to_group("local_wizard")
	elif is_in_group("local_wizard"):
		remove_from_group("local_wizard")


func _apply_pick() -> void:
	var chosen: Dictionary = SacrificeFlow.pick_for(owner_slot)
	if not chosen.is_empty():
		if str(chosen.get("wizard", "")) != wizard_tag:
			wizard_tag = str(chosen.get("wizard", ""))
		if str(chosen.get("model", "")) != model:
			model = str(chosen.get("model", ""))
		if str(chosen.get("god", "")) != god:
			god = str(chosen.get("god", ""))
	_apply_type()


func _sync_clip_pose() -> void:
	if not is_inside_tree() or _clip_pose == null or not _clip_pose.has_method("setup"):
		return
	if model.is_empty():
		return
	_clip_pose.call("setup", model, _clip_roles(), _mesh_base_pos, _mesh_base_rot)

func _apply_type() -> void:
	_type = GameData.wizard(wizard_tag)
	if _type == null:
		return
	if _type.running_speed > 0.0:
		move_speed = _type.running_speed
	_sync_clip_pose()
	if not is_node_ready() or _stats_ready:
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_stats_ready = true
	health.setup(_type.health + level_health_bonus)
	mana.setup(_type.mana + level_mana_bonus)

func _apply_model() -> void:
	var visual := get_node_or_null("Tilt/Mesh")
	if visual == null or model.is_empty() or not visual.has_method("show_model"):
		return
	visual.call("show_model", model)
	var mesh := visual as Node3D
	if mesh:
		_mesh_base_pos = mesh.position
		_mesh_base_rot = mesh.rotation
	_sync_clip_pose()
	_fit_shape()

func _fit_shape() -> void:
	var visual := get_node_or_null("Tilt/Mesh")
	var col := get_node_or_null("Collision") as CollisionShape3D
	if visual == null or col == null or not visual.has_method("body_height"):
		return
	var capsule := CapsuleShape3D.new()
	capsule.height = maxf(float(visual.call("body_height")), 0.6)
	capsule.radius = minf(float(visual.call("body_radius")), capsule.height * 0.45)
	col.shape = capsule
	col.position = Vector3(0.0, capsule.height * 0.5, 0.0)


func feet_drop() -> float:
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col == null or not col.shape is CapsuleShape3D:
		return 0.0
	var capsule := col.shape as CapsuleShape3D
	return col.position.y - capsule.height * 0.5


func facing_flat() -> Vector3:
	var ahead := REST_FACING.rotated(Vector3.UP, rotation.y)
	ahead.y = 0.0
	if ahead.length_squared() < 0.000001:
		return Vector3(0.0, 0.0, 1.0)
	return ahead.normalized()


func _process(delta: float) -> void:
	if not _should_simulate():
		_present_pose(delta)
	if not MpAuthority.should_send_command() or not is_local():
		return
	submit_drive.rpc_id(MpAuthority.SERVER_PEER, _read_forward(), look_yaw)


## Exact match: Shift+W is creature_3 and must not walk. A modal UI (WorldInput, RFC-031 031c) stops it.
func _read_forward() -> float:
	var forward := 0.0
	if WorldInput.blocked(self):
		return forward
	if Input.is_action_pressed("move_forward", true):
		forward += 1.0
	if Input.is_action_pressed("move_backward", true):
		forward -= 1.0
	return clampf(forward, -1.0, 1.0)


@rpc("any_peer", "call_remote", "unreliable")
func submit_drive(forward: float, yaw: float) -> void:
	if not MpAuthority.accept_command(self, owner_slot):
		return
	var was_moving := not is_zero_approx(_net_forward)
	_net_forward = clampf(forward, -1.0, 1.0)
	_net_yaw = yaw
	if was_moving != (not is_zero_approx(_net_forward)):
		print("mago %d %s en %.1f %.1f" % [owner_slot, "para" if was_moving else "arranca", position.x, position.z])


func request_walk(goal: Vector3) -> void:
	if MpAuthority.should_send_command():
		submit_walk.rpc_id(MpAuthority.SERVER_PEER, {"x": goal.x, "y": goal.y, "z": goal.z})
		return
	walk_to(goal)


## An order-level walk (RFC-024 024b): by the waypoints of the PathFollower child, or straight (begin_walk)
## when the body has none. request_walk and the server side of submit_walk call this.
func walk_to(goal: Vector3) -> void:
	var follower := get_node_or_null("PathFollower")
	if follower != null:
		follower.call("go_to", goal)
	else:
		begin_walk(goal)


func is_walking() -> bool:
	return _walking


func begin_walk(goal: Vector3) -> void:
	_goal = goal
	if _walking:
		return
	_walking = true
	walk_changed.emit(true)


## Teleport (RFC-021c). The server puts the wizard at `point`, a spot on the land (its Y is the land's), in
## one step: no walk goal, no velocity. sacengine keeps the height over the ground (state.d:10262); a wizard
## stands on it. The clients are told not to glide.
func warp_to(point: Vector3) -> void:
	if _walking:
		_walking = false
		walk_changed.emit(false)
	velocity = Vector3.ZERO
	global_position = Vector3(point.x, point.y - feet_drop(), point.z)
	var snap := get_node_or_null("WarpSnap") as WarpSnap
	if snap != null:
		snap.announce()


@rpc("any_peer", "call_remote", "reliable")
func submit_walk(payload: Dictionary) -> void:
	if not MpAuthority.accept_command(self, owner_slot):
		return
	walk_to(Vector3(float(payload["x"]), float(payload["y"]), float(payload["z"])))


func _should_simulate() -> bool:
	if not MpKit.is_networked():
		return true
	return MpKit.is_server()


func _seat() -> void:
	var at := global_position
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
	query.collision_mask = ground_mask
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_seat_left -= 1
	if hit.is_empty():
		return
	global_position.y = float(hit.position.y) - feet_drop()
	velocity = Vector3.ZERO
	_seat_left = 0


func _physics_process(delta: float) -> void:
	if not _should_simulate():
		_present_pose(delta)
		return
	if _seat_left > 0:
		_seat()
		return
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	var pace := move_speed
	if pace <= 0.0 and step:
		pace = step.speed()
	pace *= speed_factor * float(ghost.call("speed_factor"))
	var forward := 0.0
	var yaw := look_yaw
	if MpKit.is_networked():
		forward = _net_forward
		yaw = _net_yaw
	elif is_local():
		forward = _read_forward()
	## Held (F138): it neither walks nor turns, and a walk order waits for it (state.d:93-145, 1140-1142).
	var held := _afflictions.holds()
	if held or not ghost.call("can_move"):
		forward = 0.0
		_walking = _walking and held
		yaw = rotation.y
	rotation.y = yaw
	if absf(forward) > 0.001 and pace > 0.0:
		_walking = false
		var ahead := facing_flat()
		velocity.x = ahead.x * pace * forward
		velocity.z = ahead.z * pace * forward
	elif _walking and pace > 0.0 and not held:
		var flat := Vector3(_goal.x - global_position.x, 0.0, _goal.z - global_position.z)
		if flat.length() <= pace * delta:
			_walking = false
			velocity.x = 0.0
			velocity.z = 0.0
			walk_changed.emit(false)
		else:
			var direction := flat.normalized()
			velocity.x = direction.x * pace
			velocity.z = direction.z * pace
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_since_damage += delta
	_regenerate(delta)
	velocity = _afflictions.steer(velocity, delta)  ## F121: a thrown wizard (Tumbling) flies its own ballistic path.
	if is_obstacle() and not _afflictions.fixed():
		velocity = BodySeparation.resolve(self, velocity, delta)
	velocity = GroundGuard.keep_on_ground(self, velocity, delta)
	var before := global_position
	move_and_slide()
	GroundGuard.hold_on_ground(self, before)
	if GroundGuard.has_fallen(self):
		_return_to_altar()
	_update_clip_state(Vector2(velocity.x, velocity.z).length())


## sacengine updateCreatureStats (state.d:14400-14403): regeneration · mana/maxMana per second,
## only while standing (idle, not casting) and not just hit (isRegenerating, state.d:1429).
func _regenerate(delta: float) -> void:
	if not can_cast() or _since_damage < regen_pause_s or health.call("is_full"):
		return
	if not is_zero_approx(velocity.x) or not is_zero_approx(velocity.z):
		return
	var caster := get_node_or_null("Caster")
	if caster and caster.call("is_casting"):
		return
	var type: WizardType = GameData.wizard(wizard_tag)
	if type == null:
		return
	var full := float(mana.get("maximum"))
	var factor := 1.0 if full <= 0.0 else float(mana.get("current")) / full
	health.call("regenerate", type.regeneration_per_s * factor * delta)


func _on_health_changed(current: float, _maximum: float) -> void:
	if current < _last_health:
		_since_damage = 0.0
	_last_health = current


## sacengine sends a wizard that fell through the map to its closest altar (state.d:14802-14815).
func _return_to_altar() -> void:
	var best: Node3D = null
	for source in get_tree().get_nodes_in_group("mana_source"):
		if int(source.get("kind")) != MANA_SOURCE.Kind.ALTAR or int(source.get("owner_slot")) != owner_slot:
			continue
		var altar := source as Node3D
		if best == null or altar.global_position.distance_squared_to(global_position) < best.global_position.distance_squared_to(global_position):
			best = altar
	if best == null:
		return
	_walking = false
	velocity = Vector3.ZERO
	global_position = GroundGuard.altar_return_spot(self, best.global_position) - Vector3.UP * feet_drop()
	print("mago %d volvio al altar" % owner_slot)


func _present_pose(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _present_prev_ready:
		_present_prev_pos = global_position
		_present_prev_ready = true
		return
	var from := _present_prev_pos
	var to := global_position
	_present_prev_pos = to
	var flat_delta := Vector2(to.x - from.x, to.z - from.z).length()
	var sampled_speed := flat_delta / delta
	var pace := maxf(move_speed * speed_factor * float(ghost.call("speed_factor")), 0.001)
	sampled_speed = clampf(sampled_speed, 0.0, pace * 1.6)
	var rise := clampf(delta * 20.0, 0.0, 1.0)
	var fall := clampf(delta * 6.0, 0.0, 1.0)
	if sampled_speed >= _present_flat_speed:
		_present_flat_speed = lerpf(_present_flat_speed, sampled_speed, rise)
	else:
		_present_flat_speed = lerpf(_present_flat_speed, sampled_speed, fall)
	_update_clip_state(_present_flat_speed)


func _update_clip_state(flat_speed: float) -> void:
	_clip_flat_speed = flat_speed
	if _clip_pose == null:
		return
	if not _debug_clip_role.is_empty():
		_clip_pose.call("play", _debug_clip_role)
		return
	var held_role := _afflictions.pose_role(_clip_pose as ClipPlayback)
	if not held_role.is_empty():
		_clip_pose.call("play", held_role)
		return
	var moving := flat_speed > 0.1 and bool(ghost.call("can_move"))
	# RFC-023 023d: the spellcast loop while the Caster casts (the server says so, it is replicated), standing or walking.
	if not str(_caster.get("cast_fx_shown")).is_empty():
		_gesturing = false
		_clip_pose.call("play", "cast_run" if moving else "cast")
		return
	if moving:
		_gesturing = false
	elif _gesturing and bool(_clip_pose.call("has_role", "gesture")):
		_clip_pose.call("play", "gesture")
		return
	_clip_pose.call("play", "run" if moving else "idle")


## A rest loop ended: sacengine rolls a gesture after each stance loop; here (hash(name) + loops) % 5, the same on every peer
## and every run. The gesture ends and the body goes back to the rest pose.
func _on_clip_looped(role: String) -> void:
	if role != "idle" and role != "gesture":
		return
	_idle_loops += 1
	_gesturing = role == "idle" and posmod(hash(String(name)) + _idle_loops, GESTURE_EVERY) == 0 \
		and bool(_clip_pose.call("has_role", "gesture"))
	_update_clip_state(_clip_flat_speed)


func _clip_roles() -> Dictionary:
	return UnitClipRoles.for_wizard(_type, model)


func debug_set_clip_state(role: String) -> void:
	_debug_clip_role = role
	_update_clip_state(0.0)


func debug_clear_clip_state() -> void:
	_debug_clip_role = ""


func debug_clip_info() -> Dictionary:
	return {
		"role": _clip_pose.call("active_role") if _clip_pose else "",
		"tag": _clip_pose.call("active_tag") if _clip_pose else "",
		"frame": _clip_pose.call("active_frame") if _clip_pose else 0,
		"fps": _clip_pose.call("active_framerate") if _clip_pose else 0,
		"impact_frame": _clip_pose.call("impact_frame") if _clip_pose else -1,
	}
