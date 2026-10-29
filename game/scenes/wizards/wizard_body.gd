class_name WizardBody
extends GameBody

## One per player slot (WizardSpawner). The server (or solo) simulates the body. The player's keys
## travel as the values `forward` and `yaw` of the MpInput child; `mp_move` (the kit runs it on the
## server, on the owner and when the owner reconciles) hands them to `Drive`, the one writer of the
## movement. An AI seat has no predict: `_physics_process` steps `Drive` with no keys. Its children
## seat it on the land (Seat), heal it at rest (Regeneration) and pick its clip (Clips).

signal walk_changed(walking: bool)
signal pick_changed
## The book override changed: the Spellbook builds again.
signal book_changed

## Every wizard body in play.
const GROUP := &"wizard"
## The wizard of this process's player (none on a dedicated server).
const LOCAL_GROUP := &"local_wizard"

const TURN_RATE := PI
## The yaw is sent again when the camera turned this much (radians, about 0.25 degrees): a value per
## frame would cost three times the bytes.
const YAW_STEP := 0.0044

@export var step: WalkStep
## The wizard the player picked (wizards/). Every peer takes it from `seat_pick` (the
## pick is typed on each of them); a test scene without a flow sets it in its .tscn. It never looks
## the type up by text.
@export var wizard_type: WizardType:
	set(value):
		wizard_type = value
		_apply_type()
		if value != null and wizard_tag != value.id():
			wizard_tag = value.id()
## Wears the body scene of `wizard_type` (BodyFrame): its size and sockets. It is the one place that
## says which body this is.
@export var mount: BodyMount
## What he sees (Vision): its range comes from `wizard_type.vision_m`; the side's sight is the union
## of these (VisionSides).
@export var vision: Vision
## Seats the body on the land after it spawns (server or solo).
@export var seat: GroundSeat
## Heals it at rest: its rate comes from `wizard_type`.
@export var regeneration: Regeneration
## Picks the clip it shows, on every peer.
@export var clips: WizardClips
## The id of `wizard_type` on the network (it travels in the synchronizer). Derived from the type:
## set the type, not this.
@export var wizard_tag := "":
	set(value):
		wizard_tag = value
		pick_changed.emit()
## The model id on the network: the one of the body scene `wizard_type` wears. Derived from the
## type.
@export var model := "":
	set(value):
		model = value
		pick_changed.emit()
## The god whose book the wizard casts (gods/). Taken from `seat_pick` on every peer (it does
## not travel in the synchronizer); a test scene without a flow sets it by hand.
@export var god_type: GodType:
	set(value):
		if value == god_type:
			return
		god_type = value
		pick_changed.emit()
## Book of THIS wizard (a test scene, a solo game, the server). Empty: the book of `god_type`. It
## does not travel on the network.
@export var book: GodBook:
	set(value):
		if value == book:
			return
		book = value
		book_changed.emit()
## Wizard level: the Spellbook keeps the entries up to it. The server sets it from
## MatchRules.wizard_level (WizardSpawner) and replicates it like `model`.
@export_range(1, 9) var level := 1:
	set(value):
		if value == level:
			return
		level = value
		pick_changed.emit()
## Added to the WIZD health and mana when the server sets the stats up.
## WizardSpawner fills them from MatchRules (wizard_level_stats); 0 keeps the WIZD numbers.
@export var level_health_bonus := 0.0
@export var level_mana_bonus := 0.0

## The pick of this wizard's seat (wizard and god). WizardSpawner sets it on every peer when the
## wizard spawns and when the picks change; the body wears it once it is ready. Null (a test scene):
## the types of the .tscn stay.
var seat_pick: WizardPick:
	set(value):
		seat_pick = value
		if is_node_ready():
			_wear_pick()

var move_speed: float = 0.0
## Speedup sets it on the server (or solo); the pace is multiplied by it.
var speed_factor := 1.0
var look_yaw := 0.0

## How wide this body bends the grass (GrassKit reads it on the field's trample group): none once
## it lies as a corpse.
var grass_trample_radius: float:
	get:
		return 0.0 if is_in_group(Corpse.GROUP) else maxf(BodyBox.half_size(self), 0.25) * 1.5
var _sent_yaw := NAN
var _stats_ready := false

@onready var health: Health = $Health
@onready var mana: ManaPool = $ManaPool
@onready var souls: SoulPurse = $SoulPurse
@onready var ghost: GhostForm = $GhostForm
@onready var drive: WizardDrive = $Drive

## The cast in progress: the wizard does not heal while it casts.
@onready var _caster: Caster = $Caster
## The one owner of «held» (stunned, petrified); walking, turning, casting and summoning ask it.
@onready var _afflictions: Afflictions = $Afflictions
@onready var _net: MpActor = $MpActor
@onready var _keys: MpInput = $MpInput
@onready var _follower: PathFollower = $PathFollower
@onready var _warp_snap: WarpSnap = $WarpSnap


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(GrassLayer.TRAMPLE_GROUP)
	_refresh_owner()
	floor_snap_length = 0.5
	look_yaw = rotation.y
	# A body placed in a scene (a test scene) has the slot here and not in its MpActor: the keys are
	# read where the owner is.
	if _net.owner_slot != owner_slot:
		_net.owner_slot = owner_slot
	_wear_body()
	if _is_remote_copy():
		vision.watching = false
		_wear_pick()
		return
	seat.begin()
	_wear_pick()


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
func is_obstacle() -> bool:
	return ghost.is_obstacle()


## Idle or moving; a stunned or petrified wizard is neither (Caster cuts a cast in progress).
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


func _owner_slot_changed() -> void:
	_refresh_owner()


func _refresh_owner() -> void:
	if not is_inside_tree():
		return
	if is_local():
		add_to_group(LOCAL_GROUP)
	elif is_in_group(LOCAL_GROUP):
		remove_from_group(LOCAL_GROUP)


## Wears `seat_pick`: the wizard and god types on every peer. The one who simulates also writes the
## replicated `model`; a client gets it (and `wizard_tag`) from the server by replication.
func _wear_pick() -> void:
	var chosen := seat_pick
	var complete := chosen != null and chosen.is_complete()
	if complete:
		if chosen.wizard != wizard_type:
			wizard_type = chosen.wizard
		if chosen.god != god_type:
			god_type = chosen.god
	if _is_remote_copy():
		return
	if complete and chosen.wizard.model_id() != model:
		model = chosen.wizard.model_id()
	_apply_type()


## A networked client: it draws the server's wizard and does not simulate it.
func _is_remote_copy() -> bool:
	return MpKit.is_networked() and not MpKit.is_server()


func _apply_type() -> void:
	if wizard_type == null:
		return
	_wear_body()
	if vision != null:
		vision.adopt_range(wizard_type.vision_m)
	if wizard_type.run_speed_m_s > 0.0:
		move_speed = wizard_type.run_speed_m_s
	if regeneration != null:
		regeneration.rate_per_s = wizard_type.regeneration_per_s
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


## How far the soles of the feet are below the origin of the body (the Feet marker of its body
## scene).
func feet_drop() -> float:
	return mount.facts.feet.y


func _process(delta: float) -> void:
	if not _should_simulate():
		clips.present(delta)
	if is_local():
		_send_keys()


## The owner's keys, as the values of its MpInput (they travel exactly): the stride every frame, the
## heading when it changed.
func _send_keys() -> void:
	_keys.set_value(&"forward", _read_forward())
	if is_nan(_sent_yaw) or absf(angle_difference(_sent_yaw, look_yaw)) > YAW_STEP:
		_sent_yaw = look_yaw
		_keys.set_value(&"yaw", look_yaw)


## Exact match: Shift+W is creature_3 and must not walk. A modal UI (WorldInput) stops it.
func _read_forward() -> float:
	var forward := 0.0
	if WorldInput.blocked(self):
		return forward
	if Input.is_action_pressed("move_forward", true):
		forward += 1.0
	if Input.is_action_pressed("move_backward", true):
		forward -= 1.0
	return clampf(forward, -1.0, 1.0)


## The kit's movement hook: the server runs it for each frame of the owner's keys, the owner right
## away and again when it reconciles.
func mp_move(keys: MpInput, delta: float) -> void:
	# A test scene that freezes the body (set_physics_process(false)) freezes it here too.
	if is_physics_processing():
		drive.step(keys, delta)


func request_walk(goal: Vector3) -> void:
	if MpAuthority.should_send_command():
		submit_walk.rpc_id(MpAuthority.SERVER_PEER, {"x": goal.x, "y": goal.y, "z": goal.z})
		return
	walk_to(goal)


## An order-level walk by the waypoints of the PathFollower child. request_walk and the server side
## of submit_walk call this.
func walk_to(goal: Vector3) -> void:
	_follower.go_to(goal)


func is_walking() -> bool:
	return drive.walking


## The player's link dropped. The wizard keeps its place, health and creatures but takes no step:
## the kit simulates the seat with no keys held, and no walk order goes on without a player. It
## answers to the player again when he comes back.
func stand_still() -> void:
	drive.cancel_orders()


func begin_walk(goal: Vector3) -> void:
	drive.begin_walk(goal)


## Teleport. The server puts the wizard at `point`, a spot on the land (its Y is the land's), in
## one step: no walk goal, no velocity. A wizard
## stands on the land. The clients are told not to glide.
func warp_to(point: Vector3) -> void:
	drive.stop_walk()
	velocity = Vector3.ZERO
	global_position = Vector3(point.x, point.y - feet_drop(), point.z)
	_announce_jump()


## Tells the clients the body jumped, so their copy of it jumps too instead of sliding there. On a
## client the pose is drawn by the MpActor child; this body never writes it there.
func _announce_jump() -> void:
	_warp_snap.announce()


@rpc("any_peer", "call_remote", "reliable")
func submit_walk(payload: Dictionary) -> void:
	if not MpAuthority.accept_command(self, owner_slot):
		return
	walk_to(Vector3(float(payload["x"]), float(payload["y"]), float(payload["z"])))


func _should_simulate() -> bool:
	if not MpKit.is_networked():
		return true
	return MpKit.is_server()


func _physics_process(delta: float) -> void:
	if not _should_simulate():
		return
	# The seating tick does nothing else; Drive comes after this body in the same tick and waits
	# too (GroundSeat.is_seating).
	if seat.step():
		return
	# A seat that predicts is stepped by the kit (mp_move), with its player's keys or with none; an
	# AI seat is stepped here.
	if not _net.predict:
		drive.step(null, delta)
	regeneration.age(delta)
	# At rest: free to cast (not held, not a ghost that cannot), standing still and not casting.
	regeneration.step(delta, can_cast() and not drive.moving and not _caster.is_casting())


## Server or solo: the step ended. A client (the owner predicts, and replays) draws its pose from
## `clips.present`.
func _on_moved() -> void:
	if _should_simulate():
		clips.update(Vector2(velocity.x, velocity.z).length())


## A wizard that fell through the map is sent to its closest altar.
func _return_to_altar() -> void:
	if not is_multiplayer_authority():
		return
	var best: Node3D = null
	for source in get_tree().get_nodes_in_group(ManaSource.GROUP):
		if (
			int(source.get("kind")) != ManaSource.Kind.ALTAR
			or int(source.get("owner_slot")) != owner_slot
		):
			continue
		var altar := source as Node3D
		if (
			best == null
			or (
				altar.global_position.distance_squared_to(global_position)
				< best.global_position.distance_squared_to(global_position)
			)
		):
			best = altar
	if best == null:
		return
	drive.stop_walk()
	velocity = Vector3.ZERO
	global_position = (
		FallCheck.altar_return_spot(self, best.global_position) - Vector3.UP * feet_drop()
	)
	_announce_jump()
	print("wizard %d returned to the altar" % owner_slot)
