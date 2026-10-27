class_name BreathOfLifeAbility
extends AbilityEffect

## F153 (RFC-030 030p-b): the Dragon's Breath of life (filb, flags targetSouls | targetCorpses | onlyAlly = 4106). sacengine
## useAbility → shoot (state.d:13470-13493): the body prepares (startUsingAbility, shoot2) and at the shoot tick shootOnTick
## calls breathOfLifeShoot (13238-13248), which drains the mana (12746-12748) and adds the BreathOfLife effect; the cooldown
## (4 s) is set if it was 0. The preparation is AbilityWindup's (UsingAbility + windup()), the flight is BreathOfLife's and
## the revival is FastRevive's: this effect only judges the target and launches the breath.
##
## Target (abilityStatus, 29582-29604: applicable → range): a soul is resolved to its corpse (13241-13244). It must be dead,
## of the caster's slot (the original decides `onlyAlly` by side; here by slot), with its soul NORMAL or EMERGING (revive,
## 8651-8664) and within the SPEL's range of the caster's feet (40 m, 3D: obj.position to target.position).

## BreathOfLife scene (breath_of_life.tscn): the coordinator the shot container holds while the breath flies.
@export var breath_scene: PackedScene


func status(_target_pos: Vector3, target: Node3D) -> String:
	if ability == null or user == null:
		return Refusal.BAD_TARGET
	var corpse := corpse_of(target)
	if corpse == null or not corpse.is_dead() or _slot_of(corpse) != _slot_of(user):
		return Refusal.BAD_TARGET
	var soul := soul_of(corpse)
	if soul == null or not (soul.state == Soul.State.NORMAL or soul.state == Soul.State.EMERGING):
		return Refusal.BAD_TARGET
	if user.global_position.distance_to(corpse.global_position) > ability.cast_range_m:
		return Refusal.OUT_OF_RANGE
	return ""


## breathOfLifeShoot: the breath leaves the shot origin toward the corpse. False = nothing launched (the target is gone by the
## shoot tick): AbilitySlot spends the mana all the same, like the original.
func fire(target_pos: Vector3, target: Node3D) -> bool:
	if not is_multiplayer_authority() or breath_scene == null:
		return false
	if not status(target_pos, target).is_empty():
		if DebugLog.on(&"effects"):
			print("aliento %s sin blanco válido (tick %d)" % [who(user), MatchClock.now()])
		return false
	var spawner := get_tree().get_first_node_in_group(&"shot_spawner")
	var container := spawner.get_node_or_null(spawner.get("spawn_path")) if spawner != null else null
	if container == null:
		push_warning("BreathOfLifeAbility: no hay contenedor de disparos (grupo shot_spawner).")
		return false
	var breath := breath_scene.instantiate() as BreathOfLife
	if breath == null:
		push_warning("BreathOfLifeAbility: breath_scene no es un BreathOfLife.")
		return false
	breath.setup(user, ability, spawner as ShotSpawner, corpse_of(target))
	container.add_child(breath)
	return true


## A soul's corpse, or the corpse itself. Null when the node is neither (a free soul has no creature).
static func corpse_of(target: Node3D) -> UnitBody:
	if target == null or not is_instance_valid(target):
		return null
	if target is Soul:
		return (target as Soul).corpse as UnitBody if is_instance_valid((target as Soul).corpse) else null
	return target as UnitBody


## The soul that waits on `corpse` (Soul.corpse), or null.
static func soul_of(corpse: Node3D) -> Soul:
	return Soul.on_corpse(corpse)


static func _slot_of(body: Node) -> int:
	return int(body.get("owner_slot")) if "owner_slot" in body else 0
