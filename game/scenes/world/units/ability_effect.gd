class_name AbilityEffect
extends Node

## F126 (RFC-030 030o-a): the own part of one active ability (sacengine useAbility, state.d:13463-13561: the function each
## SpellTag calls). ActiveAbility checks cooldown → mana (abilityStatus, state.d:29582-29604), then asks status() for the
## ability's own rule, calls fire() and, when it returns true, spends the mana and starts the cooldown (`apply()`,
## 13467-13470). The effect never touches mana or cooldown. AbilityCatalog says which tag has which scene.
## Server (or solo): on a client ActiveAbility does not call it and its _physics_process stays off.

## Ticks the body prepares before fire() (sacengine startUsingAbility … shoot tick). 0 = at once (Protector, Life Shield).
## 030o-b (Firewalk) overrides windup() from the shoot animation.
@export var windup_ticks := 0

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


## Ticks from the order to fire(). 0 = fire() in the same tick.
func windup() -> int:
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
