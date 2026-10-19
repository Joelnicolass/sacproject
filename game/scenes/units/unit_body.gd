class_name UnitBody
extends CharacterBody3D

## A creature with CRE8 stats from GameData. The server (or solo) runs movement, aggro and
## melee; clients get position, rotation, mode and Health through the MultiplayerSynchronizer
## of units/unit.tscn and only present them.
##
## Modes follow sacengine CreatureMode loosely. RFC-036 036j: each mode is a UnitState child of the States
## machine (units/states/): Idle, Move, Chase, Attack, Shoot, Cower, RockForm, Summoning, Dead, Held, Reviving.
## The body stays the actor: it holds the physics body, the avoidance, the replication and the public API; the
## states hold what a mode does each physics step and the look it leaves. `mode` is the one writer of the machine.
## Aggro is sacengine `patrol` (state.d:13029): with no order, a creature whose CRE8 aggressiveness is not 0
## (`isPacifist`, sacobject.d:84) attacks the closest enemy within sightRange*0.1 (sacobject.d:88).

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
## (RFC-020e, sacengine convertReviving). COWER: a peasant far from any shelter crouches (sacengine cower, RFC-024
## addendum 1). Last in the enum: `mode` is replicated as an integer. The `mode` of each UnitState node says which it is.
enum Mode { IDLE, MOVE, CHASE, ATTACK, DEAD, SUMMONING, SHOOT, ROCK_FORM, HELD, REVIVING, COWER }

const REST_FACING := Vector3(0.0, 0.0, 1.0)

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
		if is_node_ready():
			var next: UnitState = _by_mode.get(mode)
			if next != null:
				_states.transition_to(next)
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
			_clips.lunge()
## Bumped when a shot starts (shoot0), for the same cue on clients.
@export var shots := 0:
	set(value):
		shots = value
		if is_node_ready():
			_clips.lunge()

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
var _since_damage := INF
## Whether the body flew when this physics step began (the avoidance ends the step later in it).
var _airborne_step := false
var _stats_ready := false
var _last_health := 0.0
var _rng := RandomNumberGenerator.new()
## Clip role played in IDLE (RFC-028c): a calm peasant digs ("work", PeasantBehavior sets it). Presentation only.
var _idle_role := "idle"
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

@onready var clip_pose: Node = $ClipPose
## RFC-036 036j: the machine of the modes; `_by_mode` finds the state of a `mode` value.
@onready var _states: FsmMachine = $States
var _by_mode := {}
## Optional children (RFC-024 024b): without them the body walks and picks as it did before.
@onready var path_follower: Node = get_node_or_null("PathFollower")
@onready var _target_picker: Node = get_node_or_null("TargetPicker")
## F116 (RFC-030e): takes off, flies and lands a hybrid flier. Without it every hybrid walks.
@onready var flight: Flight = get_node_or_null("Flight")
## F120 (RFC-030i): the one owner of «can it act?» (stunned, petrified). Held, the body neither thinks nor turns.
@onready var afflictions: Afflictions = $Afflictions
@onready var _avoidance: BodyAvoidance = $Avoidance
## RFC-036 036j follow-ups: the vertical motion and the clips, each its own child.
@onready var air: UnitAir = $Air
@onready var _clips: UnitClips = $Clips


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
	for state: UnitState in _states.get_children():
		_by_mode[state.mode] = state
	_states.set_physics_process(false)  ## The body calls the state in its own physics step (order of the old `match`).
	_states.set_process(false)
	_states.set_process_unhandled_input(false)
	floor_snap_length = 0.5
	collision_layer = unit_layer
	collision_mask = ground_mask
	_apply_type()
	_apply_model()
	if get_node_or_null("Tilt/Mesh"):
		clip_pose.call("setup", model)
	if clip_pose and clip_pose.has_signal("clip_looped"):
		clip_pose.connect("clip_looped", _on_clip_looped)
	if flight:
		flight.state_changed.connect(_on_flight_changed)
	var health := _health()
	health.changed.connect(_on_health_changed)
	$HealthBar.call("bind", health, owner_slot)
	$MeleeAttack.struck.connect(_on_struck)
	afflictions.held_changed.connect(cancel_attacks.unbind(1))
	$RangedAttack.call("setup", self, type, $ManaPool, $MeleeAttack, _rng)
	$ActiveAbility.call("setup", self, type, $ManaPool)
	var mana_support := get_node_or_null("ManaSupport")
	if mana_support and mana_support.has_method("setup"):
		mana_support.call("setup", self, type, owner_slot, rules)
	## The machine began in Idle; a body born in another mode (a late join, a summon) takes its state without the enter.
	if _by_mode.has(mode):
		_states.current = _by_mode[mode]
		current_state().present(false)
	if _stealth:
		_apply_stealth_look()
	_update_clip_state()
	if MpKit.is_networked() and not MpKit.is_server():
		return
	health.died.connect(_on_died)
	_init_stats()
	MatchSeed.seed_rng(_rng, ["body", String(name)], rng_seed)
	if type and not is_flying():
		air.seat_left = seat_attempts
	_setup_melee()


func display_name() -> String:
	return type.display_name if type else creature_tag


func is_dead() -> bool:
	return mode == Mode.DEAD


## sacengine isObstacle / isReactingToObstacles (state.d:112-126): not dead, not preSpawning.
func is_obstacle() -> bool:
	return mode != Mode.DEAD and mode != Mode.SUMMONING and not is_taken() and not afflictions.hides()


func facing_flat() -> Vector3:
	var ahead := REST_FACING.rotated(Vector3.UP, rotation.y)
	ahead.y = 0.0
	if ahead.length_squared() < 0.000001:
		return REST_FACING
	return ahead.normalized()


func melee_profile() -> Dictionary:
	var info := BodyCatalog.info(model)
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
	cancel_attacks()
	mode = Mode.MOVE


## An order-level walk (RFC-024 024b): to `point` by the waypoints of the PathFollower child, or straight
## (begin_walk) when the body has none. UnitOrders and the AI call this; begin_walk stays the one leg.
func walk_to(point: Vector3) -> void:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken():
		return
	if air.flies_to(point):
		begin_walk(point)
		return
	if is_instance_valid(path_follower):
		path_follower.call("go_to", point)
	else:
		begin_walk(point)


func is_walking() -> bool:
	return mode == Mode.MOVE


## In the air: a creature that must fly, or a hybrid the Flight child has up (F116).
func is_flying() -> bool:
	if type and type.is_flying():
		return true
	return flight != null and flight.is_airborne()


## Teleport (RFC-021c). The server puts the body at `point` (a spot on the land) in one step: it keeps the
## height it had over the ground (a flier), has no goal, target or velocity, and keeps its order only if it is
## guard or retreat (sacengine teleport, state.d:10260-10261, 10269). The clients are told not to glide.
func warp_to(point: Vector3) -> void:
	var above := maxf(0.0, global_position.y - air.ground_height(global_position)) if is_flying() else 0.0
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
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken() or not accepts_target(foe):
		return
	if target != foe:
		cancel_attacks()
		target = foe
	if mode != Mode.ATTACK and mode != Mode.SHOOT:
		mode = Mode.CHASE


func halt() -> void:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken():
		return
	target = null
	cancel_attacks()
	mode = Mode.IDLE


## sacengine startCowering (state.d:13760): stops where it is and crouches until something else moves it.
func start_cower() -> void:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken() or mode == Mode.COWER:
		return
	target = null
	cancel_attacks()
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
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken() or afflictions.holds():
		return ActiveAbility.BAD_TARGET
	return str($ActiveAbility.call("status", target_pos, foe))


## Server or solo: sacengine useAbility. "" = used.
func use_ability(target_pos: Vector3, foe: Node3D = null) -> String:
	if mode == Mode.DEAD or mode == Mode.SUMMONING or is_taken() or afflictions.holds():
		return ActiveAbility.BAD_TARGET
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
	cancel_attacks()
	mode = Mode.ROCK_FORM


func is_rock_form() -> bool:
	return mode == Mode.ROCK_FORM


func is_targetable() -> bool:
	return mode != Mode.DEAD and mode != Mode.SUMMONING and not is_taken() and not _playing_dead and not _stealth and not afflictions.hides()


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


## A foe by the rules of orders (Orders retarget, UnitOrders); not the target this body keeps (accepts_target, its TargetPolicy).
func is_foe(node: Variant) -> bool:
	return TargetRules.is_valid_foe_of(owner_slot, node, self, not ordered)


func _health() -> Node:
	return $Health


func _sync_clip_pose() -> void:
	if not is_inside_tree() or clip_pose == null or not clip_pose.has_method("setup"):
		return
	if model.is_empty():
		return
	clip_pose.call("setup", model)

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
	var info := BodyCatalog.info(model)
	$MeleeAttack.call("setup", self, type, float(info.get("reach", 0.35)), float(info.get("height", 1.8)), _rng)


func _physics_process(delta: float) -> void:
	if not simulates():
		_update_clip_state()
		return
	if is_taken():
		## The Captive child moves it (a Sac Doctor carries it): no AI, no gravity, no collision.
		_update_clip_state()
		return
	if air.seat():
		return
	var must_fly := type != null and type.is_flying()
	var airborne := is_flying()
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if must_fly and not (flight != null and flight.is_dropped()):
		air.hold_height(delta)
	elif flight != null and (must_fly or flight.is_capable()):
		var above := global_position.y - air.ground_height(global_position) if airborne else 0.0
		var lift := flight.advance(delta, mode == Mode.MOVE, above, is_on_floor())
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
	if _playing_dead or afflictions.holds():
		if _playing_dead:
			regenerate(delta)
	else:
		var state := current_state()
		if state.rests_on_floor() and not airborne and is_on_floor():
			return
		state.physics_update(delta)
	if flight != null and flight.holds_still():
		velocity.x = 0.0
		velocity.z = 0.0
	velocity = afflictions.steer(velocity, delta)  ## F121: a thrown body (Tumbling) flies its own ballistic path.
	_airborne_step = airborne
	## RFC-036 036f: the engine's avoidance steers the body around the others; the step ends in _on_avoided, this same
	## physics step, with the velocity it gives back.
	if is_obstacle() and _avoidance.steer(velocity, afflictions.fixed()):
		return
	_finish_step()


## The velocity (x, z) the avoidance gave back: the second half of the physics step of the body.
func _on_avoided(flat_velocity: Vector3) -> void:
	velocity.x = flat_velocity.x
	velocity.z = flat_velocity.z
	_finish_step()


func _finish_step() -> void:
	var airborne := _airborne_step
	if flight != null and flight.is_airborne():
		air.cap_pace()
	if not airborne:
		velocity = EdgeClamp.clamp_velocity(self, velocity, get_physics_process_delta_time())
	move_and_slide()
	if not airborne and FallCheck.has_fallen(self):
		_gib_fallen()
	_update_clip_state()


func simulates() -> bool:
	if not MpKit.is_networked():
		return true
	return MpKit.is_server()


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
func regenerate(delta: float) -> void:
	var health := _health()
	if type == null or _since_damage < regen_pause_s or health.call("is_full"):
		return
	var mana := $ManaPool
	var full := float(mana.get("maximum"))
	var factor := 1.0 if full <= 0.0 else float(mana.get("current")) / full
	health.call("regenerate", (type.regeneration_per_s + DevourGrowth.extra_regeneration_of(self)) * factor * delta)
	_last_health = float(health.get("current"))


## The goal of begin_walk, which the Move state steers to.
func walk_goal() -> Vector3:
	return _goal


func set_walk_goal(goal: Vector3) -> void:
	_goal = goal


func cancel_attacks() -> void:
	if mode == Mode.ROCK_FORM and simulates() and afflictions.breaks_special_modes():
		mode = Mode.IDLE  ## F137: petrified ends Rockform (state.d:11631-11640); Afflictions.held_changed calls here.
	$MeleeAttack.call("cancel")
	$RangedAttack.call("cancel")
	_clips.cancel_lunge()


func turn_toward(direction: Vector3, delta: float) -> void:
	var wanted := atan2(direction.x, direction.z)
	rotation.y = rotate_toward(rotation.y, wanted, turn_rate * delta)


func sight_range() -> float:
	return type.sight_range if type else 0.0


func flat_distance(node: Node3D) -> float:
	var d := node.global_position - global_position
	return Vector2(d.x, d.z).length()


## sacengine updateTarget around `center` (state.d:12924): with a TargetPicker child, the visible foe of the
## best score above `threshold` (patrol 0.25; patrolAround min(100, d)*0.01, advance 0.25 with ref 150);
## without it, the closest foe within sight range of `center`. Null for a pacifist (aggressiveness 0).
func closest_foe(center: Vector3, threshold := 0.25, ref_range := 100.0, within := INF) -> Node3D:
	if type == null or type.aggressiveness <= 0:
		return null
	if is_instance_valid(_target_picker):
		return _target_picker.call("pick", center, threshold, ref_range, within)
	return TargetRules.closest_in_sight(self, center)


## The target this body keeps, by its TargetPolicy (F136); without one, a foe: under an order any body not of the own side
## (isValidAttackTarget), else a stance enemy (isValidEnemyAttackTarget, state.d:12442).
func accepts_target(node: Variant) -> bool:
	return _target_picker.call("accepts", node, ordered) if is_instance_valid(_target_picker) else TargetRules.is_valid_foe_of(owner_slot, node, self, not ordered)


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


func _update_clip_state() -> void:
	if _clips != null:
		_clips.update()


func current_state() -> UnitState:
	return _states.current as UnitState if _states != null else null


func is_playing_dead() -> bool:
	return _playing_dead


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


func has_clip(role: String) -> bool:
	return clip_pose != null and bool(clip_pose.call("has_role", role))


## A clip looped: the state of the mode decides what plays next (the idle gesture, the talk-cower).
func _on_clip_looped(role: String) -> void:
	_clips.looped(role)


func debug_set_clip_state(role: String) -> void:
	_clips.set_debug_role(role)
	_update_clip_state()


func debug_clear_clip_state() -> void:
	_clips.set_debug_role("")


func debug_clip_info() -> Dictionary:
	return _clips.info()
