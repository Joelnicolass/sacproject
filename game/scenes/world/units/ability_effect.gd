class_name AbilityEffect
extends Node

## F126 (RFC-030 030o-a): the own part of one active ability (sacengine useAbility, state.d:13463-13561: the function each
## SpellTag calls). ActiveAbility checks cooldown → mana (abilityStatus, state.d:29582-29604), then asks status() for the
## ability's own rule, calls fire() and, when it returns true, spends the mana and starts the cooldown (`apply()`,
## 13467-13470). The effect never touches mana or cooldown. AbilityCatalog says which tag has which scene.
## Server (or solo): on a client ActiveAbility does not call it and its _physics_process stays off.

## Ticks the body prepares before fire() (sacengine startUsingAbility … shoot tick). 0 = at once (Protector, Life Shield).
@export var windup_ticks := 0
## Starts the cooldown when it fires. Off = none (the pull: sacengine returns before setting it, state.d:12738-12739).
@export var starts_cooldown := true
## The preparation comes from the creature's ability clip (see windup()). Off = windup_ticks as is (Protector, Halo: none).
@export var windup_from_clip := false

## Ticks one animation frame lasts (sacengine updates 60 times a second, the clips run at 30).
const FRAME_TICKS := 2

## Bench log (`ai_match` turns it on; off in the product).
static var log_effects := false

## The body that has the ability and its SPEL. Set by setup() before the node enters the tree.
var user: Node3D
var ability: AbilityType


func setup(body: Node3D, type: AbilityType) -> void:
	user = body
	ability = type


func _ready() -> void:
	set_physics_process(false)


## Ticks from the order to fire(). 0 = fire() in the same tick. With `windup_from_clip` the creature prepares until the shoot
## tick of its ability clip (shoot_animations[1]: shoot_ticks[0] at framerate → 60 ticks/s, or its last frame if it has none); windup_ticks is the fallback when
## it has no such clip (or the flag is off). The one owner of the lookup: Firewalk (shoot1) and Breath of life (shoot2).
func windup() -> int:
	if windup_from_clip:
		var type: CreatureType = user.get("type") if user else null
		if type and type.shoot_animations.size() > 1:
			var ticks: Array = type.shoot_animations[1].get("shoot_ticks", [])
			var rate := float(type.shoot_animations[1].get("framerate", 0))
			if not ticks.is_empty() and rate > 0.0:
				return roundi(float(MatchClock.TICKS_PER_SECOND) * float(ticks[0]) / rate)
			## A clip without `lrba` shoots on its last frame (sacengine: Sticky bomb, 47 x 2 = 94 ticks).
			var frames := int(type.shoot_animations[1].get("frames", 0))
			if frames > 0:
				return FRAME_TICKS * (frames - 1)
	return windup_ticks


## The ability's own rule: "" = it can be used now, else the reason (ActiveAbility's constants).
func status(_target_pos: Vector3, _target: Node3D) -> String:
	return ""


## Does it. True = applied: ActiveAbility spends the mana and starts the cooldown. False = nothing happened, nothing spent.
func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	return false


func _has_authority() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()


## The node's name (Ent1, Druid2…): the log must tell apart bodies of the same kind.
static func who(node: Node) -> String:
	return str(node.name) if node else "?"
