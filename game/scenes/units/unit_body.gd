# gdlint: disable=max-public-methods
# max-public-methods: the commands other systems give a creature are its public API (27 methods);
# split it by responsibility later, not by count.
class_name UnitBody
extends GameBody

## A creature on the map: the physics body, the ids that travel on the network (`creature_tag`,
## `model`, `mode`), the commands other systems give it and the explicit order of its physics step.
## What it is and does lives in its children: Creature, Locomotion, Engagement, Weapons, Abilities,
## SpecialForms, Regeneration, Clips and States (one per mode). Clients only present what the
## synchronizer brings.

signal died(tag: String, owner_slot: int, at: Vector3)
signal struck(target: Node3D, amount: float, hit_chance: float, roll: float)
signal summoned  ## The summon cast ended; it acts now and joins its owner's selection.
signal held_changed(held: bool)  ## A Sac Doctor holds it (true) or lets go (false).
## Held or being revived by a Sac Doctor (true) or neither (false).
signal taken_changed(taken: bool)
signal mode_changed(was: Mode, now: Mode)

## Each mode is a UnitState child of States with the same `mode`. Replicated as an integer: a new
## mode goes last.
enum Mode { IDLE, MOVE, CHASE, ATTACK, DEAD, SUMMONING, SHOOT, ROCK_FORM, HELD, REVIVING, COWER }

## Every creature body in play (corpses leave it).
const GROUP := &"unit"

## The creature this body is (data/catalog/creatures/). Whoever makes the body sets it before it
## enters the tree: the spawner on every peer, the .tscn of a test scene. It never looks the type up
## by text.
@export var type: CreatureType:
	set(value):
		type = value
		creature_tag = value.id() if value != null else ""
		if creature != null:
			creature.adopt()
## The model id on the network: the one of the body scene `type` wears (BodyFrame.model_id). Derived
## from `type`: set the type, not this.
@export var model := "":
	set(value):
		model = value
		if creature != null:
			creature.adopt_model()
@export var mode: Mode = Mode.IDLE:
	set(value):
		var was := mode
		mode = value
		if is_node_ready():
			states.follow(mode)
		if _is_taken(mode) != _is_taken(was):
			taken_changed.emit(_is_taken(mode))
		if (mode == Mode.HELD) != (was == Mode.HELD):
			held_changed.emit(mode == Mode.HELD)
		if is_node_ready():
			clips.update()
		if mode != was:
			mode_changed.emit(was, mode)

@export var mount: BodyMount
@export var vision: Vision
@export var weapons: Weapons
@export var abilities: Abilities
@export var health: Health
@export var creature: CreatureLink
@export var locomotion: Locomotion
@export var engagement: Engagement
@export var special_forms: SpecialForms
@export var regeneration: Regeneration
@export var clips: UnitClips
@export var states: UnitStates
@export var health_bar: UnitHealthBar
@export_flags_3d_physics var unit_layer := 2
@export_flags_3d_physics var ground_mask := 1
@export
var target_groups: PackedStringArray = PackedStringArray(["unit", "wizard", "structure", "doctor"])
## 0 = random. Fixed seeds make a duel repeatable.
@export var rng_seed := 0
## Off: an idle creature without an order never picks a fight (debug scenes hold still).
@export var idle_aggro := true
@export var rules: MatchRules

## The id of `type` on the network (it travels in the synchronizer). Derived from `type`: set the
## type, not this.
var creature_tag := ""

## Speedup sets it on the server (or solo); the pace is multiplied by it. GuardianBond writes
## `attack_factor`.
var speed_factor := 1.0
var attack_factor := 1.0
var move_speed := 0.0
## Gib sets it right before the body dies: it bursts, so it leaves no corpse and its soul stays free
## (SoulSystem).
var gibbed := false
## Set by the Orders child while an RTS order steers the body: no idle aggro, and a chase does not
## give up at sight range.
var ordered := false
## Owned by Engagement; every state reads and writes it here.
var target: Node3D:
	get:
		return engagement.target
	set(value):
		engagement.target = value

@onready var afflictions: Afflictions = $Afflictions
@onready var air: UnitAir = $Air
@onready var flight: Flight = get_node_or_null("Flight")
@onready var path_follower: PathFollower = get_node_or_null("PathFollower")
@onready var clip_pose: ClipPlayback = $ClipPose


func _ready() -> void:
	add_to_group(GROUP)
	floor_snap_length = 0.5
	collision_layer = unit_layer
	collision_mask = ground_mask
	creature.adopt()
	creature.adopt_model()
	creature.equip()
	states.start(states.state_of(mode), UnitState.JOINED)
	if special_forms.stealth:
		special_forms.present()
	clips.update()
	if simulates():
		health.died.connect(_on_died)
		creature.start_simulation()


## One simulated step, in this order and no other (no child processes by itself): vertical motion,
## time since the last hit, the state of the mode (unless playing dead or held), regeneration, then
## Locomotion steers, avoids and slides.
func _physics_process(delta: float) -> void:
	if not simulates() or is_taken():  # A client presents; a held creature is carried by Captive.
		clips.update()
		return
	if air.seat():
		return
	locomotion.begin(delta, mode == Mode.MOVE)
	regeneration.age(delta)
	var resting := special_forms.playing_dead
	if not (resting or afflictions.holds()):
		var state := current_state()
		if (
			state.rests_on_floor()
			and (is_dead() or (not locomotion.airborne_step and is_on_floor()))
		):
			return
		# asked before the update: a mode it leaves this tick does not regenerate in it
		resting = state.regenerates()
		state.physics_update(delta)
	regeneration.step(delta, resting)
	locomotion.finish(delta, not special_forms.playing_dead, is_obstacle)


## `owner_slot` is the player slot that summoned it; its health bar takes the side colour.
func _owner_slot_changed() -> void:
	if health_bar != null:
		health_bar.set_owner_slot(owner_slot)


func _on_died(_from_slot: int) -> void:
	mode = Mode.DEAD
	died.emit.call_deferred(creature_tag, owner_slot, global_position)


## Commands (Engagement does them) and the abilities (the Port of Abilities). The summon cast begins
## before the body enters the tree.
func engage(foe: Node3D) -> void:
	engagement.engage(foe)


func halt() -> void:
	engagement.halt()


func begin_walk(goal: Vector3) -> void:
	engagement.walk(goal)


func walk_to(point: Vector3) -> void:
	engagement.walk_to(point)


func warp_to(point: Vector3) -> void:
	engagement.warp(point)


func use_ability(target_pos: Vector3, foe: Node3D = null) -> String:
	return abilities.port.use(target_pos, foe)


func begin_summon() -> void:
	mode = Mode.SUMMONING


func finish_summon() -> void:
	if mode == Mode.SUMMONING:
		mode = Mode.IDLE


## Questions. A body held or revived by a Sac Doctor is not a creature of the match meanwhile; an
## obstacle is not dead, not summoning, not taken and not hidden by an affliction; flying is a
## creature that must fly or a hybrid with its Flight up. Mana does not regenerate while dead or
## still being summoned.
func is_dead() -> bool:
	return mode == Mode.DEAD


func is_summoning() -> bool:
	return mode == Mode.SUMMONING


func is_held() -> bool:
	return mode == Mode.HELD


func is_reviving() -> bool:
	return mode == Mode.REVIVING


func is_walking() -> bool:
	return mode == Mode.MOVE


func is_cowering() -> bool:
	return mode == Mode.COWER


func is_rock_form() -> bool:
	return mode == Mode.ROCK_FORM


func is_taken() -> bool:
	return _is_taken(mode)


static func _is_taken(value: Mode) -> bool:
	return value == Mode.HELD or value == Mode.REVIVING


func is_obstacle() -> bool:
	return (
		mode != Mode.DEAD and mode != Mode.SUMMONING and not is_taken() and not afflictions.hides()
	)


func is_targetable() -> bool:
	return is_obstacle() and not special_forms.playing_dead and not special_forms.stealth


func is_flying() -> bool:
	return (type != null and type.is_flying()) or (flight != null and flight.is_airborne())


func can_take_mana() -> bool:
	return mode != Mode.DEAD and mode != Mode.SUMMONING


func simulates() -> bool:
	return is_multiplayer_authority()


## Small doors to the children, for the callers that hold a body and nothing else.
func display_name() -> String:
	return type.display_name if type else creature_tag


func has_clip(role: String) -> bool:
	return clips.has_clip(role)


func current_state() -> UnitState:
	return states.current as UnitState if states != null else null


func corpse() -> Corpse:
	return $Corpse as Corpse


func melee_profile() -> Dictionary:
	return {
		"evasion": float(type.melee_evasion_milli()) if type else 0.0,
		"resistance": type.melee_resistance if type else 1.0,
		"reach": mount.facts.reach_m,
		"height": mount.facts.height_m
	}


## The body center (of the laid corpse once it has fallen: a clip lays it down and the pivot stays
## upright).
func soul_anchor() -> Vector3:
	var pivot := get_node_or_null("Tilt") as Node3D
	var visual := get_node_or_null("Tilt/Mesh") as BodyVisual
	if pivot == null or visual == null:
		return global_position
	return pivot.global_transform * corpse().lying_pose(mount.facts.radius_m) * mount.facts.center
