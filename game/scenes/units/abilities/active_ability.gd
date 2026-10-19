class_name ActiveAbility
extends Node

## A creature's active ability, used on command (Ctrl+Q / Shift+B). sacengine `ability`
## (sacobject.d:444): abilities[1] for a ranged creature, else abilities[0].
## F152 (030o-b): time is MatchClock's ticks, not the render delta (RFC-032): the cooldown (and the timers of Stealth and Play Dead, in
## their effects) is «until tick N». An effect with windup() > 0 (Firewalk) prepares first: use() turns on UsingAbility (the body is held,
## sacengine startUsingAbility) and the effect fires at `now + windup`, where the mana is spent even if fire() did
## nothing (state.d:12746-12748) and the cooldown is set if it was 0. If the state was cut before (stunned, frozen…)
## nothing is spent.
## Checks follow abilityStatus (state.d:29582-29604): cooldown → mana → target → range → the
## ability's own rule. `useAbility` (state.d:13463-13561) drains manaCost and sets the ability
## cooldown (cooldown·60 frames, counted down every frame, state.d:13937) when it applies.
## Implemented from the active book roster: every ability has an AbilityEffect scene of its own (ability_catalog.tres). F133 (030v-b):
## the last three, Rockform (dihk), Play Dead (dedp) and Stealth (ivni), left the `match` that lived here; this node only checks and pays.

const COOLING := "Enfriando"
const NO_MANA := "Sin maná"
const OUT_OF_RANGE := "Fuera de alcance"
const BAD_TARGET := "Blanco inválido"
const NOT_IMPLEMENTED := "No implementado"
const NO_ABILITY := "Sin habilidad"

## sacengine manaEpsilon (abilityStatus).
const MANA_EPSILON := 0.01


@export_group("Active effects")
## F126: which tag has an AbilityEffect scene of its own; a tag that is not there is «No implementado».
@export var catalog: AbilityCatalog

var ability: AbilityType
## A guardian has no active ability (activeAbility, state.d:1414). GuardianBond sets it.
var locked := false

var _body: Node3D
var _mana: Node
## MatchClock tick at which the cooldown ends (0 = ready).
var _ready_at := 0
## F152: the preparation. MatchClock tick at which the effect fires (-1 = none) and the target it was ordered on.
var _fire_at := -1
var _fire_pos := Vector3.ZERO
var _fire_target: Node3D
## F126: the AbilityEffect of this ability (instanced from the catalog), or null.
var _effect: AbilityEffect


func setup(body: Node3D, creature: CreatureType, mana: Node) -> void:
	_body = body
	_mana = mana
	ability = GameData.ability(creature.active_ability_tag) if creature and not creature.active_ability_tag.is_empty() else null
	var scene := catalog.scene_for(ability.tag) if catalog and ability else null
	if scene:
		_effect = scene.instantiate() as AbilityEffect
		_effect.name = "Effect"
		_effect.setup(body, ability)
		add_child(_effect)


func _ready() -> void:
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var now := MatchClock.now()
	if _fire_at >= 0:
		## F132: a preparation that something cut (stunned, frozen…) is over at that tick, not at the shoot tick.
		var using := _using()
		if using == null or not using.is_on():
			_cut_windup()
		elif now >= _fire_at:
			_finish_windup()


func display_name() -> String:
	return ability.display_name if ability else ""


func cooldown_left() -> float:
	return float(maxi(0, _ready_at - MatchClock.now())) / float(MatchClock.TICKS_PER_SECOND)


func _cooling() -> bool:
	return MatchClock.now() < _ready_at


## "" = ready. Clients see the replicated mana, not the cooldown: the server checks again.
func status(target_pos: Vector3, target: Node3D) -> String:
	if ability == null or locked:
		return NO_ABILITY
	if _effect == null:
		return NOT_IMPLEMENTED
	if _cooling():
		return COOLING
	if _cost() > _mana_left() + MANA_EPSILON:
		return NO_MANA
	var using := _using()
	if using and using.is_on():
		return BAD_TARGET
	return _effect.status(target_pos, target)


## Server or solo. Returns "" when used, else the reason.
func use(target_pos: Vector3, target: Node3D) -> String:
	var reason := status(target_pos, target)
	if not reason.is_empty():
		return reason
	if _effect.windup() > 0:
		return _begin_windup(target_pos, target)
	var before := _mana_left()
	if not _effect.fire(target_pos, target):
		return BAD_TARGET
	_pay()
	_start_cooldown(true)
	_log_spent(before)
	return ""


## Charges the mana.
func _pay() -> void:
	_mana.call("spend", _cost())


## Starts the cooldown (`force`, or only if it was 0: state.d:12746-12748).
func _start_cooldown(force: bool) -> void:
	if _effect.starts_cooldown and (force or not _cooling()):
		_ready_at = MatchClock.now() + roundi(ability.cooldown_s * MatchClock.TICKS_PER_SECOND)


func _log_spent(before: float) -> void:
	if DebugLog.on(&"ability"):
		print("habilidad %s mana %d->%d enfriamiento %d ticks" % [ability.display_name, roundi(before), roundi(_mana_left()), maxi(0, _ready_at - MatchClock.now())])


## The mana an ability costs: exactly the SPEL's (abilityStatus, useAbility: state.d:29584, 13468). 0 (Devour, Play Dead) spends
## nothing; before F131 a cost was at least 1.
func _cost() -> float:
	return float(ability.mana_cost) if ability else 0.0


func _using() -> Affliction:
	return _body.get_node_or_null("Afflictions/UsingAbility") as Affliction if _body else null


## sacengine startUsingAbility: the body is held until the effect's tick. Nothing is spent yet.
func _begin_windup(target_pos: Vector3, target: Node3D) -> String:
	var using := _using()
	var owner_node := _body.get_node("Afflictions") as Afflictions
	if using == null or not owner_node.admit(using):
		return BAD_TARGET
	owner_node.mark(using, true)
	var ticks := _effect.windup()
	_fire_at = MatchClock.now() + ticks
	_fire_pos = target_pos
	_fire_target = target
	if DebugLog.on(&"ability"):
		print("usando habilidad %s %s %d ticks (tick %d)" % [ability.display_name, str(_body.name), ticks, MatchClock.now()])
	if _effect.pays_upfront:
		var before := _mana_left()
		_pay()
		_log_spent(before)
	return ""


## The preparation was cut: nothing fires. A mana paid at the start (pays_upfront) stays spent; no cooldown.
func _cut_windup() -> void:
	_fire_at = -1
	if DebugLog.on(&"ability"):
		print("preparación cortada %s %s (tick %d)" % [ability.display_name, str(_body.name), MatchClock.now()])


## The effect's tick: if the preparation survived, it fires and the mana is spent even when fire() did nothing.
func _finish_windup() -> void:
	_fire_at = -1
	var using := _using()
	var target := _fire_target if is_instance_valid(_fire_target) else null
	if _effect.pays_upfront:
		## Paid at the start (act(), 13495-13510): no mana check here; fire(), then the cooldown if it was 0.
		_effect.fire(_fire_pos, target)
		_start_cooldown(false)
		if DebugLog.on(&"ability"):
			print("habilidad %s enfriamiento %d ticks (tick %d)" % [ability.display_name, maxi(0, _ready_at - MatchClock.now()), MatchClock.now()])
		if using.is_on():
			(_body.get_node("Afflictions") as Afflictions).mark(using, false)
		return
	var before := _mana_left()
	if _cost() > before + MANA_EPSILON:
		## sacengine loadOnTick asks mana >= cost at the load tick (12592-12605): short of it, nothing happens and nothing is spent.
		if DebugLog.on(&"ability"):
			print("preparación sin maná %s %s (tick %d)" % [ability.display_name, str(_body.name), MatchClock.now()])
		(_body.get_node("Afflictions") as Afflictions).mark(using, false)
		return
	_effect.fire(_fire_pos, target)
	_pay()
	_start_cooldown(false)
	_log_spent(before)
	if using.is_on():
		(_body.get_node("Afflictions") as Afflictions).mark(using, false)


## Every peer, from UnitBody's mode setter: the Rockform effect draws the shell (any other creature has none).
func show_rock_form(on: bool) -> void:
	var rock := _effect as Rockform
	if rock:
		rock.show_rock_form(on)


func _mana_left() -> float:
	return float(_mana.get("current")) if _mana else 0.0
