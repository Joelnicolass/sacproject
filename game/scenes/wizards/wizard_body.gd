class_name WizardBody
extends CharacterBody3D

## One per player slot (WizardSpawner). The server (or solo) simulates the body; the owning client sends drive/walk
## commands, the listen host's own wizard reads its keys right there.

signal walk_changed(walking: bool)
signal pick_changed
## The book override changed: the Spellbook builds again.
signal book_changed

@export var step: WalkStep
@export var owner_slot := 0:
	set(value):
		owner_slot = value
		_refresh_owner()
## The wizard the player picked (data/catalog/wizards/). Every peer takes it from SacrificeFlow.pick_for(owner_slot) (the pick is
## typed on each of them); a bench without a flow sets it in its .tscn. It never looks the type up by text.
@export var wizard_type: WizardType:
	set(value):
		wizard_type = value
		_apply_type()
		if value != null and wizard_tag != value.id():
			wizard_tag = value.id()
## Wears the body scene of `wizard_type` (BodyFrame): its size and sockets. It is the one place that says which body this is.
@export var mount: BodyMount
## What he sees (Vision): its range comes from `wizard_type.vision_m`; the side's sight is the union of these (VisionSides).
@export var vision: Vision
## The id of `wizard_type` on the network (it travels in the synchronizer). Derived from the type: set the type, not this.
@export var wizard_tag := "":
	set(value):
		wizard_tag = value
		pick_changed.emit()
## The model id on the network (what the original calls the body): the one of the body scene `wizard_type` wears. Derived from the type.
@export var model := "":
	set(value):
		model = value
		pick_changed.emit()
## The god whose book the wizard casts (data/gods/). Taken from the seat's pick on every peer (it does not travel in the
## synchronizer); a bench without a flow sets it by hand.
@export var god_type: GodType:
	set(value):
		if value == god_type:
			return
		god_type = value
		pick_changed.emit()
## Book of THIS wizard (a bench, a solo game, the server). Empty: the book of `god_type`. It does not travel on the network.
@export var book: GodBook:
	set(value):
		if value == book:
			return
		book = value
		book_changed.emit()
## Wizard level (RFC-030 030b): the Spellbook keeps the entries up to it. The server sets it from
## MatchRules.wizard_level (WizardSpawner) and replicates it like `model`.
@export_range(1, 9) var level := 1:
	set(value):
		if value == level:
			return
		level = value
		pick_changed.emit()
## RFC-030 030c: added to the WIZD health and mana when the server sets the stats up.
## WizardSpawner fills them from MatchRules (wizard_level_stats); 0 keeps the WIZD numbers.
## Ref: makeWizard, state.d:2307-2311
@export var level_health_bonus := 0.0
@export var level_mana_bonus := 0.0
## Ray mask used to seat the body on the ground after spawning.
@export_flags_3d_physics var ground_mask := 1
@export var seat_attempts := 12
## It regenerates only in idle and not during a damage animation.
## Ref: sacengine; state.d:1429
@export var regen_pause_s := 0.5

const REST_FACING := Vector3(0.0, 0.0, 1.0)
const TURN_RATE := PI
## RFC-023 (023d): 1 rest loop in GESTURE_EVERY ends in the idle0 gesture, like the units.
## Ref: sacengine rolls 1 in 5
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
var _present_prev_pos := Vector3.ZERO
var _present_prev_ready := false
var _present_flat_speed := 0.0
var _debug_clip_role := ""
var _idle_loops := 0
var _gesturing := false
## The speed the last _update_clip_state saw (a gesture that ends re-picks the pose with it).
var _clip_flat_speed := 0.0

@onready var health: Health = $Health
@onready var mana: ManaPool = $ManaPool
@onready var souls: SoulPurse = $SoulPurse
@onready var ghost: GhostForm = $GhostForm
@onready var _clip_pose: ClipPlayback = $ClipPose
## The cast in progress as every peer sees it (`is_casting()` reads the replicated `cast_fx_shown` on a client), so the pose follows it.
@onready var _caster: Caster = $Caster
## F138 (RFC-030i-c): the one owner of «held» (stunned, petrified); walking, turning, casting and summoning ask it.
@onready var _afflictions: Afflictions = $Afflictions
@onready var _locomotion: Locomotion = $Locomotion


func _ready() -> void:
	add_to_group("wizard")
	_refresh_owner()
	floor_snap_length = 0.5
	look_yaw = rotation.y
	_net_yaw = rotation.y
	_wear_body()
	if _clip_pose.has_signal("clip_looped"):
		_clip_pose.connect("clip_looped", _on_clip_looped)
	_present_prev_pos = global_position
	_present_prev_ready = true
	if MpKit.is_networked() and not MpKit.is_server():
		vision.watching = false
		_take_pick_type()
		SacrificeFlow.slot_picks_changed.connect(_take_pick_type)
		return
	_seat_left = seat_attempts
	health.changed.connect(_on_health_changed)
	_apply_pick()
	SacrificeFlow.slot_picks_changed.connect(_apply_pick)


func _exit_tree() -> void:
	if SacrificeFlow.slot_picks_changed.is_connected(_apply_pick):
		SacrificeFlow.slot_picks_changed.disconnect(_apply_pick)
	if SacrificeFlow.slot_picks_changed.is_connected(_take_pick_type):
		SacrificeFlow.slot_picks_changed.disconnect(_take_pick_type)


func is_local() -> bool:
	return owner_slot > 0 and owner_slot == MpKit.local_slot()


## Creatures and spells only pick a living wizard: not one dying or a ghost (GhostForm).
func is_targetable() -> bool:
	return ghost.is_targetable()


func is_ghost() -> bool:
	return ghost.is_ghost()


## Escorts and retreats keep following a ghost (GhostForm.is_guard_target).
func is_guard_target() -> bool:
	return ghost.is_guard_target()


## A ghost still steers around the others and they around it.
## Ref: state.d:117, 125
func is_obstacle() -> bool:
	return ghost.is_obstacle()


## Idle or moving; a stunned or petrified wizard is neither (Caster cuts a cast in progress).
## Ref: sacengine canCast
func can_cast() -> bool:
	return ghost.can_cast() and not _afflictions.holds()


func can_take_mana() -> bool:
	return ghost.can_take_mana()


func can_collect_souls() -> bool:
	return ghost.can_collect_souls()


func spellbook_visible() -> bool:
	return ghost.spellbook_visible()


## Its WizardType: Afflictions/Stunned reads the stun clips from it.
func clip_type() -> WizardType:
	return wizard_type


func display_name() -> String:
	if wizard_type:
		return wizard_type.display_name
	return model


func _refresh_owner() -> void:
	if not is_inside_tree():
		return
	if is_local():
		add_to_group("local_wizard")
	elif is_in_group("local_wizard"):
		remove_from_group("local_wizard")


func _apply_pick() -> void:
	var chosen: WizardPick = SacrificeFlow.pick_for(owner_slot)
	if chosen != null and chosen.is_complete():
		## The replicated ids (`wizard_tag`, `model`) stay the wire until the body is a scene of its own (055s).
		if chosen.wizard != wizard_type:
			wizard_type = chosen.wizard
		if chosen.wizard.model_id() != model:
			model = chosen.wizard.model_id()
		if chosen.god != god_type:
			god_type = chosen.god
	_apply_type()


## A client: the wizard and god types come from the pick; the ids (`wizard_tag`, `model`) are the server's and reach it by replication.
func _take_pick_type() -> void:
	var chosen: WizardPick = SacrificeFlow.pick_for(owner_slot)
	if chosen == null or not chosen.is_complete():
		return
	if chosen.wizard != wizard_type:
		wizard_type = chosen.wizard
	if chosen.god != god_type:
		god_type = chosen.god


func _apply_type() -> void:
	if wizard_type == null:
		return
	_wear_body()
	if vision != null:
		vision.adopt_range(wizard_type.vision_m)
	if wizard_type.run_speed_m_s > 0.0:
		move_speed = wizard_type.run_speed_m_s
	if not is_node_ready() or _stats_ready:
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	_stats_ready = true
	health.setup(wizard_type.health + level_health_bonus)
	mana.setup(wizard_type.mana + level_mana_bonus)

func _wear_body() -> void:
	if mount != null and wizard_type != null:
		mount.wear(wizard_type.body)


## How far the soles of the feet are below the origin of the body (the Feet marker of its body scene).
func feet_drop() -> float:
	return mount.facts.feet.y


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
	var follower := get_node_or_null("PathFollower") as PathFollower
	if follower != null:
		follower.go_to(goal)
	else:
		begin_walk(goal)


func is_walking() -> bool:
	return _walking


## RFC-034 034g (F184): the player's link dropped. The wizard keeps its place, health and creatures but takes no step: no held
## key (`_net_forward`) and no walk order go on without a player. It answers to the player again when he comes back.
func stand_still() -> void:
	_net_forward = 0.0
	var follower := get_node_or_null("PathFollower") as PathFollower
	if follower != null:
		follower.cancel()
	if _walking:
		_walking = false
		walk_changed.emit(false)


func begin_walk(goal: Vector3) -> void:
	_goal = goal
	if _walking:
		return
	_walking = true
	walk_changed.emit(true)


## Teleport (RFC-021c). The server puts the wizard at `point`, a spot on the land (its Y is the land's), in
## one step: no walk goal, no velocity. the original keeps the height over the ground; a wizard
## stands on it. The clients are told not to glide.
## Ref: state.d:10262
func warp_to(point: Vector3) -> void:
	if _walking:
		_walking = false
		walk_changed.emit(false)
	velocity = Vector3.ZERO
	global_position = Vector3(point.x, point.y - feet_drop(), point.z)
	_announce_jump()


## Tells the clients the body jumped, so their copy of it jumps too instead of sliding there. On a client the pose is
## drawn by the MpActor child; this body never writes it there.
func _announce_jump() -> void:
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
	var ground := GroundRay.surface_y(self, at, ground_mask, [get_rid()], NAN)
	_seat_left -= 1
	if is_nan(ground):
		return
	global_position.y = ground - feet_drop()
	velocity = Vector3.ZERO
	_seat_left = 0


func _physics_process(delta: float) -> void:
	if not _should_simulate():
		_present_pose(delta)
		return
	if _seat_left > 0:
		_seat()
		return
	_locomotion.begin(delta)
	var pace := move_speed
	if pace <= 0.0 and step:
		pace = step.speed()
	pace *= speed_factor * ghost.speed_factor()
	## The player at this machine (solo or the listen host) drives with his own keys and camera; a remote player, by submit_drive.
	var forward := 0.0
	var yaw := look_yaw
	if is_local():
		forward = _read_forward()
	elif MpKit.is_networked():
		forward = _net_forward
		yaw = _net_yaw
	## Held (F138) or casting a structure (Caster.holds_wizard): it neither walks nor turns, and a walk order waits for it.
	## Ref: state.d:93-145, 1140-1142
	var held := _afflictions.holds() or _caster.holds_wizard()
	if held or not ghost.can_move():
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
	## Locomotion: the afflictions steer (a thrown wizard flies its own path), the engine's avoidance moves him around the others (a wizard is
	## above his creatures) and the step ends in its `resume`, this same physics step; then `moved` (the pose) or `fell` (back to the altar).
	_locomotion.finish(delta, false, is_obstacle)


func _on_moved() -> void:
	_update_clip_state(Vector2(velocity.x, velocity.z).length())


## Regeneration · mana/maxMana per second,
## only while standing (idle, not casting) and not just hit.
## Ref: sacengine updateCreatureStats (state.d:14400-14403); isRegenerating, state.d:1429
func _regenerate(delta: float) -> void:
	if not can_cast() or _since_damage < regen_pause_s or health.is_full():
		return
	if not is_zero_approx(velocity.x) or not is_zero_approx(velocity.z):
		return
	var caster := get_node_or_null("Caster") as Caster
	if caster and caster.is_casting():
		return
	if wizard_type == null:
		return
	var full := mana.maximum
	var factor := 1.0 if full <= 0.0 else mana.current / full
	health.regenerate(wizard_type.regeneration_per_s * factor * delta)


func _on_health_changed(current: float, _maximum: float) -> void:
	if current < _last_health:
		_since_damage = 0.0
	_last_health = current


## A wizard that fell through the map is sent to its closest altar.
## Ref: sacengine; state.d:14802-14815
func _return_to_altar() -> void:
	var best: Node3D = null
	for source in get_tree().get_nodes_in_group("mana_source"):
		if int(source.get("kind")) != ManaSource.Kind.ALTAR or int(source.get("owner_slot")) != owner_slot:
			continue
		var altar := source as Node3D
		if best == null or altar.global_position.distance_squared_to(global_position) < best.global_position.distance_squared_to(global_position):
			best = altar
	if best == null:
		return
	_walking = false
	velocity = Vector3.ZERO
	global_position = FallCheck.altar_return_spot(self, best.global_position) - Vector3.UP * feet_drop()
	_announce_jump()
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
	var pace := maxf(move_speed * speed_factor * ghost.speed_factor(), 0.001)
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
		_clip_pose.play(_debug_clip_role)
		return
	var held_role := _afflictions.pose_role(_clip_pose)
	if not held_role.is_empty():
		_clip_pose.play(held_role)
		return
	var moving := flat_speed > 0.1 and ghost.can_move()
	# RFC-023 023d: the spellcast loop while the Caster casts (the server says so, it is replicated), standing or walking.
	if _caster.is_casting():
		_gesturing = false
		_clip_pose.play("cast_run" if moving else "cast")
		return
	if moving:
		_gesturing = false
	elif _gesturing and _clip_pose.has_role("gesture"):
		_clip_pose.play("gesture")
		return
	_clip_pose.play("run" if moving else "idle")


## A rest loop ended: the original rolls a gesture after each stance loop; here (hash(name) + loops) % 5, the same on every peer
## and every run. The gesture ends and the body goes back to the rest pose.
func _on_clip_looped(role: String) -> void:
	if role != "idle" and role != "gesture":
		return
	_idle_loops += 1
	_gesturing = role == "idle" and posmod(hash(String(name)) + _idle_loops, GESTURE_EVERY) == 0 \
		and _clip_pose.has_role("gesture")
	_update_clip_state(_clip_flat_speed)


func debug_set_clip_state(role: String) -> void:
	_debug_clip_role = role
	_update_clip_state(0.0)


func debug_clear_clip_state() -> void:
	_debug_clip_role = ""


func debug_clip_info() -> Dictionary:
	return {
		"role": _clip_pose.active_role() if _clip_pose else "",
		"tag": _clip_pose.active_tag() if _clip_pose else "",
		"frame": _clip_pose.active_frame() if _clip_pose else 0,
		"fps": _clip_pose.active_framerate() if _clip_pose else 0,
		"impact_frame": _clip_pose.impact_frame() if _clip_pose else -1,
	}
