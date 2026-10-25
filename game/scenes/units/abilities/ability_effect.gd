class_name AbilityEffect
extends Node

## The own part of one active ability (sacengine useAbility, state.d:13463-13561: the function each SpellTag calls). AbilitySlot
## checks cooldown → mana (abilityStatus, state.d:29582-29604), then asks status() for the ability's own rule, calls fire() and, when
## it returns true, spends the mana and starts the cooldown (`apply()`, 13467-13470). The effect never touches mana or cooldown.
## The AbilityType says which scene is its effect (`AbilityType.effect`).
## Server (or solo): on a client AbilitySlot does not call it and its _physics_process stays off.

## How long the body prepares before fire(). 0 = at once (Protector, Life Shield).
## Ref: sacengine startUsingAbility … shoot tick.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var windup_s := 0.0
## Starts the cooldown when it fires. Off = none (the pull: sacengine returns before setting it, state.d:12738-12739).
@export var starts_cooldown := true
## The preparation comes from the creature's ability clip (see windup()). Off = windup_s as is (Protector, Halo: none).
@export var windup_from_clip := false
## F157: which of the creature's two ability clips the preparation reads (SHOOT_ROLES[windup_clip]). 1 = `shoot2` (Firewalk, Breath
## of life, Pull, Sticky bomb: they must not change); 0 = `shoot` (the Styx's Rend Soul prepares its attack clip, 100 ticks).
@export_range(0, 1) var windup_clip := 1
## F132: the mana is paid when the preparation starts, not at the shoot tick (sacengine act(), state.d:13495-13510: the Jabberocky's
## Quake). At the shoot tick AbilitySlot does not check the mana again: fire() and, if it was 0, the cooldown. If the preparation is cut the mana
## is gone and there is no cooldown. Off = the mana is paid at the shoot tick (Firewalk, Breath, Pull, Sticky, Oil, Mites, Devour, Rend).
@export var pays_upfront := false

## Ticks one animation frame lasts (sacengine updates 60 times a second, the clips run at 30).
const FRAME_TICKS := 2
## The clip of each ability: the first and the second shoot clip of the creature's model.
const SHOOT_ROLES: Array[StringName] = [&"shoot", &"shoot2"]


## The body that has the ability and its SPEL. Set by setup() before the node enters the tree.
var user: UnitBody
var ability: AbilityType


func setup(body: UnitBody, type: AbilityType) -> void:
	user = body
	ability = type


func _ready() -> void:
	set_physics_process(false)


## Ticks from the order to fire(). 0 = fire() in the same tick. With `windup_from_clip` the creature prepares until the shoot
## tick of its ability clip (SHOOT_ROLES[windup_clip]: its first `shoot` marker at the clip's rate → 60 ticks/s, or its last frame if it has none); windup_s is the fallback when
## it has no such clip (or the flag is off). The one owner of the lookup: Firewalk (shoot1) and Breath of life (shoot2).
func windup() -> int:
	if windup_from_clip:
		var type: CreatureType = user.type if user else null
		var facts := type.clip_facts() if type else ClipFacts.of(null)
		var role := SHOOT_ROLES[windup_clip]
		var shots := facts.shots(role)
		var rate := float(facts.fps(role))
		if not shots.is_empty() and rate > 0.0:
			return roundi(float(MatchClock.TICKS_PER_SECOND) * float(shots[0]) / rate)
		## A clip without `lrba` shoots on its last frame (sacengine: Sticky bomb, 47 x 2 = 94 ticks).
		var frames := facts.frames(role)
		if frames > 0:
			return FRAME_TICKS * (frames - 1)
	return MatchClock.ticks_for(windup_s)


## The ability's own rule: "" = it can be used now, else the reason (AbilitySlot's constants).
func status(_target_pos: Vector3, _target: Node3D) -> String:
	return ""


## Does it. True = applied: AbilitySlot spends the mana and starts the cooldown. False = nothing happened, nothing spent.
func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	return false


func _has_authority() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()


## The node's name (Ent1, Druid2…): the log must tell apart bodies of the same kind.
static func who(node: Node) -> String:
	return str(node.name) if node else "?"
