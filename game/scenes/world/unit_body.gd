class_name UnitBody
extends CharacterBody3D

## A creature with CRE8 stats from GameData. The server (or solo) runs movement, aggro and
## melee; clients get position, rotation, mode and Health through the MultiplayerSynchronizer
## of units/unit.tscn and only present them.
##
## Modes follow sacengine CreatureMode loosely: IDLE (idle + patrol), MOVE (move order),
## CHASE (moving toward the attack target), ATTACK (meleeAttacking), DEAD (dying + dead).
## Aggro is sacengine `patrol` (state.d:13029): with no order, a creature whose CRE8
## aggressiveness is not 0 (`isPacifist`, sacobject.d:84) attacks the closest enemy within
## sightRange·0.1 (sacobject.d:88). A move order ignores enemies until it arrives.
## SUMMONING is sacengine preSpawning: translucent (alpha 0.36), no orders, no aggro and not a
## target until the wizard's cast ends (finish_summon).
## SHOOT is sacengine shooting (RangedAttack plays shoot0 and fires on its tick). ROCK_FORM is
## the Earthfling's Rockform (ActiveAbility): still, 5 % damage, hidden from enemy AI.

signal died(tag: String, owner_slot: int, at: Vector3)
signal struck(target: Node3D, amount: float, hit_chance: float, roll: float)
## The summon cast ended; it now acts and joins its owner's selection.
signal summoned
## F135: `model` changed (data, not order). BodyCollider refits the capsule from it.
signal model_changed
## Held by a Sac Doctor (true) or let go (false). The Captive child draws its ring.
signal held_changed(held: bool)
## Held or being revived by a Sac Doctor (true) or neither (false). The Captive child keeps the group
## and the collision.
signal taken_changed(taken: bool)

## HELD: taken by a Sac Doctor (RFC-020c). REVIVING: a Convert doctor is pumping its corpse back to life
## (RFC-020e, sacengine convertReviving). COWER: a peasant far from any shelter crouches and waits
## (sacengine cower, RFC-024 addendum 1). Last in the enum: `mode` is replicated as an integer.
enum Mode { IDLE, MOVE, CHASE, ATTACK, DEAD, SUMMONING, SHOOT, ROCK_FORM, HELD, REVIVING, COWER }

const REST_FACING := Vector3(0.0, 0.0, 1.0)
## sacengine startCasting: setAlpha(creature, 0.36) while the summon is cast.
const SUMMONING_ALPHA := 0.36
## The pose of a cowering creature with no cower clip in the cache: the model crouches (presentation only,
## on every peer). With the clip (RFC-028c) the clip plays instead.
const COWER_SCALE := Vector3(1.08, 0.6, 1.08)
## sacengine cower (state.d:8164-8171): when the cower clip ends, 1 time in 5 the peasant talks while cowering.
const TALK_COWER_EVERY := 5
## RFC-023: 1 rest loop in GESTURE_EVERY ends in the idle gesture (sacengine's 1/5, state.d:7957-7992).
const GESTURE_EVERY := 5
## sacengine dealDamage: damage ×0.05 in rockForm (state.d:8964).
const ROCK_FORM_DAMAGE := 0.05
const _RANGED := preload("res://scenes/world/units/ranged_attack.gd")

## CreatureType tag (CRE8 SpellTag) read from GameData.
@export var creature_tag := "ycro":
	set(value):
		creature_tag = value
		_apply_type()
## Baked model; empty = the CreatureType model.
@export var model := "":
	set(value):
		model = value
		_apply_model()
		model_changed.emit()
## Player slot that summoned it (0 = nobody).
@export var owner_slot := 0:
	set(value):
		owner_slot = value
		var bar := get_node_or_null("HealthBar")
		if bar:
			bar.call("set_owner_slot", owner_slot)
@export var mode: Mode = Mode.IDLE:
	set(value):
		var was := mode
		mode = value
		if mode == Mode.DEAD and was != Mode.DEAD and is_node_ready():
			_show_corpse()
		elif was == Mode.DEAD and mode != Mode.DEAD and is_node_ready():
			_hide_corpse()
		if (mode == Mode.SUMMONING) != (was == Mode.SUMMONING):
			_apply_summon_look()
			if was == Mode.SUMMONING:
				summoned.emit()
		if (mode == Mode.ROCK_FORM) != (was == Mode.ROCK_FORM):
			_apply_rock_form()
		if _is_taken(mode) != _is_taken(was):
			taken_changed.emit(_is_taken(mode))
		if (mode == Mode.HELD) != (was == Mode.HELD):
			held_changed.emit(mode == Mode.HELD)
		if is_node_ready():
			_update_clip_state()
## Bumped on every swing so clients play the lunge too.
@export var swings := 0:
	set(value):
		swings = value
		if is_node_ready():
			_lunge()
## Bumped when a shot starts (shoot0), for the same cue on clients.
@export var shots := 0:
	set(value):
		shots = value
		if is_node_ready():
			_lunge()

@export_flags_3d_physics var unit_layer := 2
@export_flags_3d_physics var ground_mask := 1
@export var seat_attempts := 12
## sacengine stats.d:104: ground creatures turn at π rad/s.
@export var turn_rate := PI
@export var scan_interval_s := 0.25
## sacengine regenerates only in idle and not during a damage animation (state.d:1429).
@export var regen_pause_s := 0.5
@export var target_groups: PackedStringArray = PackedStringArray(["unit", "wizard", "structure", "doctor"])
## sacengine CreatureStats.flyingHeight.
@export var flying_height := 4.5
## sacengine upwardHoverSpeed / downwardHoverSpeed.
@export var flying_hover_speed := 3.0
## 0 = random. Fixed seeds make a duel repeatable.
@export var rng_seed := 0
## Off: an idle creature without an order never picks a fight (debug scenes hold still).
@export var idle_aggro := true
@export var rules: MatchRules

@export_group("Swing")
@export var lunge_back_deg := 6.0
@export var lunge_forward_deg := 10.0
@export var lunge_back_s := 0.3
@export var lunge_forward_s := 0.08
@export var lunge_recover_s := 0.25

## Speedup sets it on the server (or solo); the pace is multiplied by it.
var speed_factor := 1.0
## Multiplies the damage of its melee and ranged attacks (attackDamageFactor, state.d:8884). A guardian
## has 1.5; GuardianBond writes it.
var attack_factor := 1.0
var move_speed := 0.0
var type: CreatureType
var target: Node3D
## Set by the Orders child while an RTS order steers the body: no idle aggro, and a chase
## does not give up at sight range.
var ordered := false

var _goal := Vector3.ZERO
var _scan_left := 0.0
var _since_damage := INF
var _seat_left := 0
## Whether the body flew when this physics step began (the avoidance ends the step later in it).
var _airborne_step := false
var _stats_ready := false
var _last_health := 0.0
var _pose_tween: Tween
var _rng := RandomNumberGenerator.new()
var _debug_clip_role := ""
## Clip role played in IDLE (RFC-028c): a calm peasant digs ("work", PeasantBehavior sets it). Presentation only.
var _idle_role := "idle"
## Clip role of COWER: "cower", or "talk_cower" after a loop when (hash(name) + loops) % 5 == 0 (no randi()).
var _cower_role := "cower"
var _cower_loops := 0
## RFC-023: after a rest loop (stance1) the body plays the idle gesture 1 time in GESTURE_EVERY, picked like the talk-cower.
var _idle_loops := 0
var _gesturing := false
var _playing_dead := false
## Replicated (unit.tscn, ON_CHANGE) so a client hides an enemy in stealth on the minimap (RFC-037). The server stays the
## only writer (`set_stealth`); the setter applies the 3D fade on every peer.
var _stealth := false:
	set(value):
		if _stealth == value:
			return
		_stealth = value
		if is_node_ready():
			_apply_stealth_look()
			_update_clip_state()
## RFC-023 023e: the clip role of a creature a Sac Doctor holds or revives (rise, held, thrash). Captive picks it on every
## peer from the mode; "" = none. A model with no such clip rests on the role it would play anyway.
var captive_role := "":
	set(value):
		captive_role = value
		if is_node_ready():
			_update_clip_state()

@onready var _clip_pose: Node = $ClipPose
## Optional children (RFC-024 024b): without them the body walks and picks as it did before.
@onready var _path_follower: Node = get_node_or_null("PathFollower")
@onready var _target_picker: Node = get_node_or_null("TargetPicker")
## F116 (RFC-030e): takes off, flies and lands a hybrid flier. Without it every hybrid walks.
@onready var _flight: Flight = get_node_or_null("Flight")
## F120 (RFC-030i): the one owner of «can it act?» (stunned, petrified). Held, the body neither thinks nor turns.
@onready var _afflictions: Afflictions = $Afflictions
@onready var _avoidance: BodyAvoidance = $Avoidance


## Before it enters the tree: the summon cast has just started.
func begin_summon() -> void:
	mode = Mode.SUMMONING


## Server or solo, when the summon cast ends and the souls are paid.
func finish_summon() -> void:
	if mode == Mode.SUMMONING:
		mode = Mode.IDLE


func is_summoning() -> bool:
	return mode == Mode.SUMMONING


func is_held() -> bool:
	return mode == Mode.HELD


## A Sac Doctor has it: held, or being pumped back to life. Not a creature of the match meanwhile.
func is_taken() -> bool:
	return _is_taken(mode)


func is_reviving() -> bool:
	return mode == Mode.REVIVING


static func _is_taken(value: Mode) -> bool:
	return value == Mode.HELD or value == Mode.REVIVING


func _ready() -> void:
	add_to_group("unit")
	floor_snap_length = 0.5
	collision_layer = unit_layer
	collision_mask = ground_mask
	_apply_type()
	_apply_model()
	if get_node_or_null("Tilt/Mesh"):
		_clip_pose.call("setup", model)
	if _clip_pose and _clip_pose.has_signal("clip_looped"):
		_clip_pose.connect("clip_looped", _on_clip_looped)
	if _flight:
		_flight.state_changed.connect(_on_flight_changed)
	var health := _health()
	health.changed.connect(_on_health_changed)
	$HealthBar.call("bind", health, owner_slot)
	$MeleeAttack.struck.connect(_on_struck)
	_afflictions.held_changed.connect(_cancel_attacks.unbind(1))
	$RangedAttack.call("setup", self, type, $ManaPool, $MeleeAttack, _rng)
	$ActiveAbility.call("setup", self, type, $ManaPool)
	var mana_support := get_node_or_null("ManaSupport")
	if mana_support and mana_support.has_method("setup"):
		mana_support.call("setup", self, type, owner_slot, rules)
	if mode == Mode.DEAD:
		_show_corpse(false)
	elif mode == Mode.ROCK_FORM:
		_apply_rock_form()
	if _stealth:
		_apply_stealth_look()
	_update_clip_state()
	if MpKit.is_networked() and not MpKit.is_server():
		return
	health.died.connect(_on_died)
	_init_stats()
	MatchSeed.seed_rng(_rng, ["body", String(name)], rng_seed)
	if type and not is_flying():
		_seat_left = seat_attempts
	_setup_melee()


func display_name() -> String:
	return type.display_name if type else creature_tag


func is_dead() -> bool:
	return mode == Mode.DEAD


## sacengine isObstacle / isReactingToObstacles (state.d:112-126): not dead, not preSpawning.
func is_obstacle() -> bool:
	return mode != Mode.DEAD and mode != Mode.SUMMONING and not is_taken() and not _afflictions.hides()


func facing_flat() -> Vector3:
	var ahead := REST_FACING.rotated(Vector3.UP, rotation.y)
	ahead.y = 0.0
	if ahead.length_squared() < 0.000001:
		return REST_FACING
	return ahead.normalized()


func melee_profile() -> Dictionary:
	var info := BodyLibrary.info(model)
	return {
		"evasion": float(type.melee_evasion) if type else 0.0,
		"resistance": type.melee_resistance if type else 1.0,
		"reach": float(info.get("reach", 0.35)),
		"height": float(info.get("height", 1.8)),
	}


func begin_walk(goal: Vector3) -> void:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken():
		return
	_goal = goal
	target = null
	_cancel_attacks()
	mode = Mode.MOVE


## An order-level walk (RFC-024 024b): to `point` by the waypoints of the PathFollower child, or straight
## (begin_walk) when the body has none. UnitOrders and the AI call this; begin_walk stays the one leg.
func walk_to(point: Vector3) -> void:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken():
		return
	if _flies_to(point):
		begin_walk(point)
		return
	if is_instance_valid(_path_follower):
		_path_follower.call("go_to", point)
	else:
		begin_walk(point)


func is_walking() -> bool:
	return mode == Mode.MOVE


## In the air: a creature that must fly, or a hybrid the Flight child has up (F116).
func is_flying() -> bool:
	if type and type.is_flying():
		return true
	return _flight != null and _flight.is_airborne()


## F116: the Flight child takes the walk to `point` by air (sacengine moveTowards, state.d:12335-12339). A flier goes
## straight: its waypoints are dropped.
func _flies_to(point: Vector3) -> bool:
	if not _should_simulate():
		return false
	## A creature that must fly has no Flight child (it is never on the ground): it always goes straight, no path on the navmesh or the grid.
	if type != null and type.is_flying():
		if is_instance_valid(_path_follower):
			_path_follower.call("cancel")
		return true
	if _flight == null:
		return false
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z).length()
	if not _flight.goes_by_air(flat):
		return false
	if is_instance_valid(_path_follower):
		_path_follower.call("cancel")
	return true


## Teleport (RFC-021c). The server puts the body at `point` (a spot on the land) in one step: it keeps the
## height it had over the ground (a flier), has no goal, target or velocity, and keeps its order only if it is
## guard or retreat (sacengine teleport, state.d:10260-10261, 10269). The clients are told not to glide.
func warp_to(point: Vector3) -> void:
	var above := maxf(0.0, global_position.y - _ground_height(global_position)) if is_flying() else 0.0
	global_position = Vector3(point.x, point.y + above, point.z)
	velocity = Vector3.ZERO
	halt()
	var orders := get_node_or_null("Orders")
	if orders != null:
		orders.call("warped")
	var snap := get_node_or_null("WarpSnap") as WarpSnap
	if snap != null:
		snap.announce()


func engage(foe: Node3D) -> void:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken() or not _is_valid_foe(foe):
		return
	if target != foe:
		_cancel_attacks()
		target = foe
	if mode != Mode.ATTACK and mode != Mode.SHOOT:
		mode = Mode.CHASE


func halt() -> void:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken():
		return
	target = null
	_cancel_attacks()
	mode = Mode.IDLE


## sacengine startCowering (state.d:13760): stops where it is and crouches until something else moves it.
func start_cower() -> void:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken() or mode == Mode.COWER:
		return
	target = null
	_cancel_attacks()
	mode = Mode.COWER


func is_cowering() -> bool:
	return mode == Mode.COWER


## F27 calls this for Ctrl+Q / Shift+B on the owner's peer. Returns the local refusal (mana,
## no ability, «No implementado»), or "" once sent. The server checks the cooldown again.
func request_ability(target_pos: Vector3, foe: Node3D = null) -> String:
	var reason := ability_status(target_pos, foe)
	if not reason.is_empty() or not MpAuthority.should_send_command():
		return reason if not reason.is_empty() else use_ability(target_pos, foe)
	submit_ability.rpc_id(MpAuthority.SERVER_PEER, {
		"x": target_pos.x, "y": target_pos.y, "z": target_pos.z,
		"target": str(foe.get_path()) if foe else "",
	})
	return ""


func ability_status(target_pos: Vector3, foe: Node3D = null) -> String:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken() or _afflictions.holds():
		return "Blanco inválido"
	return str($ActiveAbility.call("status", target_pos, foe))


## Server or solo: sacengine useAbility. "" = used.
func use_ability(target_pos: Vector3, foe: Node3D = null) -> String:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken() or _afflictions.holds():
		return "Blanco inválido"
	return str($ActiveAbility.call("use", target_pos, foe))


@rpc("any_peer", "call_remote", "reliable")
func submit_ability(payload: Dictionary) -> void:
	if not MpAuthority.accept_command(self, owner_slot):
		return
	var path := str(payload.get("target", ""))
	var foe := get_node_or_null(path) as Node3D if not path.is_empty() else null
	use_ability(Vector3(float(payload["x"]), float(payload["y"]), float(payload["z"])), foe)


## sacengine rockForm (state.d:13052): drops its order and target and stands as a rock.
func enter_rock_form() -> void:
	var orders := get_node_or_null("Orders")
	if orders:
		orders.call("clear")
	target = null
	_cancel_attacks()
	mode = Mode.ROCK_FORM


func is_rock_form() -> bool:
	return mode == Mode.ROCK_FORM


func is_targetable() -> bool:
	return mode != Mode.DEAD and mode != Mode.SUMMONING and not is_taken() and not _playing_dead and not _stealth and not _afflictions.hides()


func set_playing_dead(on: bool) -> void:
	if _playing_dead == on:
		return
	_playing_dead = on
	var visual := get_node_or_null("Tilt/Mesh") as BodyVisual
	if visual:
		visual.set_fade(0.5 if on else 0.0)
	if on:
		halt()
	_update_clip_state()


func set_stealth(on: bool) -> void:
	if _stealth == on:
		return
	_stealth = on


func _apply_stealth_look() -> void:
	var visual := get_node_or_null("Tilt/Mesh") as BodyVisual
	if visual:
		visual.set_fade(0.75 if _stealth else 0.0)


func clear_special_states() -> void:
	set_playing_dead(false)
	set_stealth(false)


## sacengine canRegenerateMana (state.d:168): not while dead or still being summoned.
func can_take_mana() -> bool:
	return mode != Mode.DEAD and mode != Mode.SUMMONING


## A foe by the rules of orders (Orders retarget, UnitOrders); not the target this body keeps (_is_valid_foe, its TargetPolicy).
func is_foe(node: Variant) -> bool:
	return UnitBody.is_valid_foe_of(owner_slot, node, self, not ordered)


func _health() -> Node:
	return $Health


func _sync_clip_pose() -> void:
	if not is_inside_tree() or _clip_pose == null or not _clip_pose.has_method("setup"):
		return
	if model.is_empty():
		return
	_clip_pose.call("setup", model)

func _apply_type() -> void:
	type = GameData.creature(creature_tag)
	if type:
		move_speed = type.flying_speed if is_flying() else type.running_speed
	else:
		move_speed = 0.0
	_sync_clip_pose()
	if type and model.is_empty():
		model = type.model

func _init_stats() -> void:
	if type == null or _stats_ready:
		return
	_stats_ready = true
	_health().call("setup", float(type.health))
	_last_health = float(type.health)
	$ManaPool.call("setup", float(type.mana))


func _apply_model() -> void:
	var visual := get_node_or_null("Tilt/Mesh")
	if visual == null or model.is_empty():
		return
	visual.call("show_model", model)
	_sync_clip_pose()
	# The capsule is BodyCollider's (F135): the only writer of the Collision shape.
	var height := float(visual.call("body_height"))
	var bar := get_node_or_null("HealthBar")
	if bar:
		bar.call("place_above", height)
	if is_node_ready():
		_setup_melee()


func _setup_melee() -> void:
	var info := BodyLibrary.info(model)
	$MeleeAttack.call("setup", self, type, float(info.get("reach", 0.35)), float(info.get("height", 1.8)), _rng)


func _seat() -> void:
	var at := global_position
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
	query.collision_mask = ground_mask
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_seat_left -= 1
	if hit.is_empty():
		return
	global_position.y = float(hit.position.y)
	velocity = Vector3.ZERO
	_seat_left = 0


func _physics_process(delta: float) -> void:
	if not _should_simulate():
		_update_clip_state()
		return
	if is_taken():
		## The Captive child moves it (a Sac Doctor carries it): no AI, no gravity, no collision.
		_update_clip_state()
		return
	if _seat_left > 0:
		_seat()
		return
	var must_fly := type != null and type.is_flying()
	var airborne := is_flying()
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if must_fly and not (_flight != null and _flight.is_dropped()):
		_hold_flying_height(delta)
	elif _flight != null and (must_fly or _flight.is_capable()):
		var above := global_position.y - _ground_height(global_position) if airborne else 0.0
		var lift := _flight.advance(delta, mode == Mode.MOVE, above, is_on_floor())
		if airborne:
			velocity.y = lift
		elif is_on_floor():
			velocity.y = 0.0
		else:
			velocity.y -= gravity * delta
	elif is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	_since_damage += delta
	velocity.x = 0.0
	velocity.z = 0.0
	## The gate: playing dead (regenerating) or held by Afflictions, the body only falls and is pushed; its mode (and its
	## order) waits for it. Declared (F120): Play Dead now also gibs over a hole (has_fallen) and, in the air, shows idle, not fly.
	if _playing_dead or _afflictions.holds():
		if _playing_dead:
			_regenerate(delta)
	else:
		match mode:
			Mode.IDLE:
				_idle(delta)
			Mode.MOVE:
				_move(delta)
			Mode.CHASE:
				_chase(delta)
			Mode.ATTACK:
				_attack(delta)
			Mode.SHOOT:
				_shoot(delta)
			Mode.ROCK_FORM, Mode.COWER:
				_regenerate(delta)
			Mode.DEAD, Mode.SUMMONING:
				if not airborne and is_on_floor():
					return
	if _flight != null and _flight.holds_still():
		velocity.x = 0.0
		velocity.z = 0.0
	velocity = _afflictions.steer(velocity, delta)  ## F121: a thrown body (Tumbling) flies its own ballistic path.
	_airborne_step = airborne
	## RFC-036 036f: the engine's avoidance steers the body around the others; the step ends in _on_avoided, this same
	## physics step, with the velocity it gives back.
	if is_obstacle() and _avoidance.steer(velocity, _afflictions.fixed()):
		return
	_finish_step()


## The velocity (x, z) the avoidance gave back: the second half of the physics step of the body.
func _on_avoided(flat_velocity: Vector3) -> void:
	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z
	_finish_step()


func _finish_step() -> void:
	var airborne := _airborne_step
	if _flight != null and _flight.is_airborne():
		_cap_air_pace()
	if not airborne:
		velocity = EdgeClamp.clamp_velocity(self, velocity, get_physics_process_delta_time())
	move_and_slide()
	if not airborne and FallCheck.has_fallen(self):
		_gib_fallen()
	_update_clip_state()


## F116: a hybrid in the air keeps its flying pace; the avoidance turns its heading but does not add to
## it (sacengine caps the air speed at speedInAir, state.d:14742-14751).
func _cap_air_pace() -> void:
	var pace := move_speed * speed_factor
	var flat := Vector2(velocity.x, velocity.z)
	if pace > 0.0 and flat.length() > pace:
		flat = flat.normalized() * pace
		velocity.x = flat.x
		velocity.z = flat.y


func _should_simulate() -> bool:
	if not MpKit.is_networked():
		return true
	return MpKit.is_server()


func _hold_flying_height(delta: float) -> void:
	var ground_y := _ground_height(global_position)
	if not is_finite(ground_y):
		velocity.y = 0.0
		return
	var target_y := ground_y + flying_height
	var dy := target_y - global_position.y
	if absf(dy) < 0.001:
		velocity.y = 0.0
		return
	var step := flying_hover_speed * delta
	if absf(dy) <= step:
		velocity.y = dy / maxf(delta, 0.000001)
	else:
		velocity.y = signf(dy) * flying_hover_speed


func _ground_height(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
	query.collision_mask = ground_mask
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else NAN


## sacengine (state.d:14800-14821): a creature gibDepth below the land over a hole is gibbed
## with no soul (gib(state, -2), state.d:8341-8365): blood burst, out of the selection, removed.
func _gib_fallen() -> void:
	set_physics_process(false)
	var center := soul_anchor()
	FxBus.broadcast("hover_blood", center)
	FxBus.broadcast("blood", center)
	print("%s cae al vacio" % display_name())
	queue_free()


## sacengine updateCreatureStats (state.d:14400-14403): regeneration · mana/maxMana (1 without mana).
func _regenerate(delta: float) -> void:
	var health := _health()
	if type == null or _since_damage < regen_pause_s or health.call("is_full"):
		return
	var mana := $ManaPool
	var full := float(mana.get("maximum"))
	var factor := 1.0 if full <= 0.0 else float(mana.get("current")) / full
	health.call("regenerate", (type.regeneration_per_s + DevourGrowth.extra_regeneration_of(self)) * factor * delta)
	_last_health = float(health.get("current"))


func _idle(delta: float) -> void:
	_regenerate(delta)
	if ordered or not idle_aggro:
		return
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = scan_interval_s
	var foe := _closest_enemy()
	if foe:
		target = foe
		mode = Mode.CHASE


func _move(delta: float) -> void:
	if _flight != null and _flight.state == Flight.State.GROUND and _flight.is_capable():
		var final_goal := _goal
		if is_instance_valid(_path_follower) and bool(_path_follower.call("is_active")):
			final_goal = _path_follower.get("goal")
		if _flies_to(final_goal):
			_goal = final_goal
	var pace := move_speed * speed_factor
	var flat := Vector3(_goal.x - global_position.x, 0.0, _goal.z - global_position.z)
	if pace <= 0.0 or flat.length() <= pace * delta:
		mode = Mode.IDLE
		return
	var direction := flat.normalized()
	_turn_toward(direction, delta)
	velocity.x = direction.x * pace
	velocity.z = direction.z * pace


func _chase(delta: float) -> void:
	if not _is_valid_foe(target) or (not ordered and _flat_distance(target) > _sight_range()):
		target = null
		mode = Mode.IDLE
		return
	var ranged := $RangedAttack
	var shooting := bool(ranged.call("prefers", target))
	if shooting:
		var step: int = ranged.call("aim", target)
		if step != _RANGED.Step.APPROACH:
			_turn_toward(ranged.call("aim_direction", target), delta)
			if step == _RANGED.Step.FIRE:
				shots += 1
				mode = Mode.SHOOT
			return
	var melee := $MeleeAttack
	if not shooting and melee.call("can_start", target):
		melee.call("start", target)
		swings += 1
		mode = Mode.ATTACK
		return
	var heading := target.global_position
	if is_instance_valid(_path_follower):
		heading = _path_follower.call("steer_point", heading)
	var to_foe := heading - global_position
	to_foe.y = 0.0
	if to_foe.length_squared() < 0.000001:
		return
	var direction := to_foe.normalized()
	_turn_toward(direction, delta)
	var pace := move_speed * speed_factor * maxf(0.0, facing_flat().dot(direction))
	velocity.x = direction.x * pace
	velocity.z = direction.z * pace


func _attack(delta: float) -> void:
	if _is_valid_foe(target):
		var to_foe := (target.global_position - global_position) * Vector3(1.0, 0.0, 1.0)
		if to_foe.length_squared() > 0.000001:
			_turn_toward(to_foe.normalized(), delta)
		velocity += $MeleeAttack.call("close_in", target, 0.0 if _afflictions.fixed() else move_speed * speed_factor, delta)
	if not $MeleeAttack.call("advance", delta):
		mode = Mode.CHASE


## sacengine shoot in shooting mode: stands, keeps facing the aim and fires on the shoot tick.
func _shoot(delta: float) -> void:
	var ranged := $RangedAttack
	if _is_valid_foe(target):
		_turn_toward(ranged.call("aim_direction", target), delta)
	if not ranged.call("advance", delta):
		mode = Mode.CHASE


func _cancel_attacks() -> void:
	if mode == Mode.ROCK_FORM and _should_simulate() and _afflictions.breaks_special_modes():
		mode = Mode.IDLE  ## F137: petrified ends Rockform (state.d:11631-11640); Afflictions.held_changed calls here.
	$MeleeAttack.call("cancel")
	$RangedAttack.call("cancel")
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
		($Tilt as Node3D).rotation.x = 0.0


func _turn_toward(direction: Vector3, delta: float) -> void:
	var wanted := atan2(direction.x, direction.z)
	rotation.y = rotate_toward(rotation.y, wanted, turn_rate * delta)


func _sight_range() -> float:
	return type.sight_range if type else 0.0


func _flat_distance(node: Node3D) -> float:
	var d := node.global_position - global_position
	return Vector2(d.x, d.z).length()


func _closest_enemy() -> Node3D:
	return closest_foe(global_position)


## sacengine updateTarget around `center` (state.d:12924): with a TargetPicker child, the visible foe of the
## best score above `threshold` (patrol 0.25; patrolAround min(100, d)*0.01, advance 0.25 with ref 150);
## without it, the closest foe within sight range of `center`. Null for a pacifist (aggressiveness 0).
func closest_foe(center: Vector3, threshold := 0.25, ref_range := 100.0, within := INF) -> Node3D:
	if type == null or type.aggressiveness <= 0:
		return null
	if is_instance_valid(_target_picker):
		return _target_picker.call("pick", center, threshold, ref_range, within)
	var best: Node3D = null
	var best_d := _sight_range()
	for group in target_groups:
		for node in get_tree().get_nodes_in_group(group):
			if not _is_valid_foe(node):
				continue
			var at: Vector3 = node.global_position
			var d := Vector2(at.x - center.x, at.z - center.z).length()
			if d <= best_d:
				best_d = d
				best = node
	return best


## The target this body keeps, by its TargetPolicy (F136); without one, a foe: under an order any body not of the own side
## (isValidAttackTarget), else a stance enemy (isValidEnemyAttackTarget, state.d:12442).
func _is_valid_foe(node: Variant) -> bool:
	return _target_picker.call("accepts", node, ordered) if is_instance_valid(_target_picker) else UnitBody.is_valid_foe_of(owner_slot, node, self, not ordered)


## Whether `node` is a creature, wizard or structure that a body of player `slot` may fight (`me` is that
## body, never its own foe). TargetPicker and SideVision share it, so what is visible and what is
## attackable never drift apart.
## `by_stance`: also ask SideRelations (the SIDS of the map) whether the body's side is an enemy of `slot`.
static func is_valid_foe_of(slot: int, node: Variant, me: Node = null, by_stance := true) -> bool:
	if node == null or not is_instance_valid(node) or node == me or not node is Node3D:
		return false
	var other := node as Node3D
	if not other.is_inside_tree() or other.is_in_group("corpse") or not "owner_slot" in other:
		return false
	if other.has_method("is_summoning") and other.call("is_summoning"):
		return false
	## sacengine isVisibleToAI (state.d:93): a rock is not a target.
	if other.has_method("is_rock_form") and other.call("is_rock_form"):
		return false
	## sacengine isValidAttackTarget (state.d:138): not a dying or ghost wizard.
	if other.has_method("is_targetable") and not other.call("is_targetable"):
		return false
	var other_slot := int(other.get("owner_slot"))
	if other_slot == slot:
		return false
	if by_stance and not SideRelations.is_enemy(slot, other_slot):
		return false
	var health := other.get_node_or_null("Health")
	return health != null and not health.call("is_dead")


func _on_health_changed(current: float, _maximum: float) -> void:
	if current < _last_health:
		_since_damage = 0.0
	_last_health = current


func _on_struck(foe: Node3D, amount: float, hit_chance: float, roll: float) -> void:
	struck.emit(foe, amount, hit_chance, roll)


func _on_died(_from_slot: int) -> void:
	mode = Mode.DEAD
	died.emit.call_deferred(creature_tag, owner_slot, global_position)


## sacengine soulPosition: the body center (of the laid corpse once it has fallen).
func soul_anchor() -> Vector3:
	var pivot := get_node_or_null("Tilt") as Node3D
	var visual := get_node_or_null("Tilt/Mesh")
	if pivot == null or visual == null:
		return global_position
	# A clip lays the body down (the pivot stays upright): the soul sits where the Tween would have left the center.
	var lie := $Corpse.call("lying_pose", float(visual.call("body_radius"))) as Transform3D
	return pivot.global_transform * lie * Vector3(0.0, float(visual.call("body_height")) * 0.5, 0.0)


## `animate` false: a peer that joins after the death gets the corpse already on the ground.
func _show_corpse(animate := true) -> void:
	target = null
	_cancel_attacks()
	$HealthBar.visible = false
	if _pose_tween:
		_pose_tween.kill()
	var visual := get_node_or_null("Tilt/Mesh")
	var radius := float(visual.call("body_radius")) if visual else 0.3
	var role := _death_role()
	if not role.is_empty():
		_clip_pose.call("play", role, true) if animate else _clip_pose.call("play_ended", role)
	$Corpse.call("lay_down", self, radius, animate, not role.is_empty())


## RFC-023f: the clip that lays the body down ("" = a Tween does: baked meshes, dedicated server, no dying clip).
func _death_role() -> String:
	for role: String in ["fly_death" if is_flying() else "death", "death"]:
		if bool(_clip_pose.call("is_skeletal")) and _has_clip(role):
			return role
	return ""


## Server and clients: the creature left DEAD (a Convert doctor pumped it back to life): the corpse stands up.
func _hide_corpse() -> void:
	$HealthBar.visible = true
	$Corpse.call("stand_up", self)


func _apply_rock_form() -> void:
	if not is_node_ready():
		return
	var on := mode == Mode.ROCK_FORM
	$ActiveAbility.call("show_rock_form", on)
	_health().set("damage_factor", ROCK_FORM_DAMAGE if on else 1.0)


func _apply_summon_look() -> void:
	var visual := get_node_or_null("Tilt/Mesh") as BodyVisual
	if visual:
		visual.set_fade(1.0 - SUMMONING_ALPHA if mode == Mode.SUMMONING else 0.0)


func _update_clip_state() -> void:
	if mode != Mode.COWER:
		_cower_role = "cower"
	if mode != Mode.IDLE:
		_gesturing = false
	_apply_cower_look()
	if _clip_pose == null or (mode == Mode.DEAD and bool($Corpse.get("clip_driven"))):
		return
	if not _debug_clip_role.is_empty():
		_clip_pose.call("play", _debug_clip_role)
		return
	var held_role := "idle" if _playing_dead else _afflictions.pose_role(_clip_pose as ClipPlayback)
	if not held_role.is_empty():
		_clip_pose.call("play", held_role)
		return
	if not captive_role.is_empty() and _has_clip(captive_role):
		_clip_pose.call("play", captive_role)
		return
	var flight_role := _flight_role()
	if not flight_role.is_empty() and _has_clip(flight_role):
		_clip_pose.call("play", flight_role)
		return
	if mode == Mode.ATTACK:
		_clip_pose.call("play", "attack")
		return
	if mode == Mode.COWER and _has_clip(_cower_role):
		_clip_pose.call("play", _cower_role)
		return
	if mode == Mode.IDLE and _idle_role != "idle" and _has_clip(_idle_role):
		_clip_pose.call("play", _idle_role)
		return
	if _gesturing and mode == Mode.IDLE and _has_clip("gesture"):
		_clip_pose.call("play", "gesture")
		return
	var moving := mode == Mode.MOVE or mode == Mode.CHASE
	_clip_pose.call("play", "run" if moving else "idle")


## F116: the clip of the Flight state ("" on the ground).
func _flight_role() -> String:
	if _flight == null or mode == Mode.DEAD:
		return ""
	match _flight.state:
		Flight.State.TAKEOFF:
			return "takeoff"
		Flight.State.FLYING:
			return "hover" if mode == Mode.IDLE and _has_clip("hover") else "fly"
		Flight.State.LANDING:
			return "land"
	return ""


## F116: on every peer (Flight:state is replicated): the pace of the air or the ground, and the clip.
func _on_flight_changed(_state: Flight.State) -> void:
	if type:
		move_speed = type.flying_speed if is_flying() else type.running_speed
	_update_clip_state()


## RFC-028c: the clip role this body plays when it stands in IDLE ("idle" = the CRE8 idle0). A role this model
## has no clip for falls back to idle.
func set_idle_role(role: String) -> void:
	_idle_role = role if not role.is_empty() else "idle"
	if is_node_ready():
		_update_clip_state()


func idle_role() -> String:
	return _idle_role


func _has_clip(role: String) -> bool:
	return _clip_pose != null and bool(_clip_pose.call("has_role", role))


## A cower (or talk-cower) loop ended: sacengine picks talk-cower 1 time in 5 (state.d:8164-8171); here the pick
## is (hash(name) + loops) % 5, the same on every peer and every run.
func _on_clip_looped(role: String) -> void:
	if mode == Mode.IDLE and (role == "idle" or role == "gesture"):
		# sacengine rolls a gesture after each stance loop (state.d:7957-7992); here (hash(name) + loops) % 5, the same on every peer.
		_idle_loops += 1
		_gesturing = role == "idle" and posmod(hash(String(name)) + _idle_loops, GESTURE_EVERY) == 0 and _has_clip("gesture")
		_update_clip_state()
		return
	if mode != Mode.COWER or (role != "cower" and role != "talk_cower"):
		return
	_cower_loops += 1
	var talk := posmod(hash(String(name)) + _cower_loops, TALK_COWER_EVERY) == 0 and _has_clip("talk_cower")
	_cower_role = "talk_cower" if talk else "cower"
	_update_clip_state()


func _apply_cower_look() -> void:
	var pivot := get_node_or_null("Tilt") as Node3D
	if pivot == null:
		return
	# The squash is only the fallback of a model with no cower clip in the cache.
	var squash := mode == Mode.COWER and not _has_clip("cower")
	var want := COWER_SCALE if squash else Vector3.ONE
	if pivot.scale != want:
		pivot.scale = want


func _lunge() -> void:
	var pivot := get_node_or_null("Tilt") as Node3D
	if pivot == null or mode == Mode.DEAD:
		return
	if _pose_tween:
		_pose_tween.kill()
	pivot.rotation.x = 0.0
	_pose_tween = pivot.create_tween()
	_pose_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_pose_tween.tween_property(pivot, "rotation:x", -deg_to_rad(lunge_back_deg), lunge_back_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(pivot, "rotation:x", deg_to_rad(lunge_forward_deg), lunge_forward_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose_tween.tween_property(pivot, "rotation:x", 0.0, lunge_recover_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func debug_set_clip_state(role: String) -> void:
	_debug_clip_role = role
	_update_clip_state()


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
