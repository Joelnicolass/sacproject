class_name AbilitySlot
extends Node

## A creature's active ability, used on command (Ctrl+Q / Shift+B). It checks that the ability can be used (cooldown, mana, a target,
## range, the effect's own rule), then pays the mana and starts the cooldown. What the ability does is the AbilityEffect scene of its
## AbilityType (`effect`); an ability whose type has none is «No implementado».
## Not: the preparation before the effect fires (AbilityWindup) nor who may order it (AbilityPort).
## Time is MatchClock ticks, not the render delta: the cooldown is «until tick N».

## The mana slack of the cost check.
const MANA_EPSILON := 0.01

## The preparation of an effect that is not instant.
@export var windup: AbilityWindup

var ability: AbilityType
## The AbilityEffect of `ability` (instanced from its AbilityType.effect), or null.
var effect: AbilityEffect
## A guardian has no active ability. GuardianBond sets it.
var locked := false
var body: UnitBody

var _mana: ManaPool
## MatchClock tick at which the cooldown ends (0 = ready).
var _ready_at := 0


func setup(unit: UnitBody, creature: CreatureType, mana: ManaPool) -> void:
	body = unit
	_mana = mana
	ability = creature.active_ability if creature else null
	var scene := ability.effect if ability else null
	if scene:
		effect = scene.instantiate() as AbilityEffect
		effect.name = "Effect"
		effect.setup(unit, ability)
		add_child(effect)


func display_name() -> String:
	return ability.display_name if ability else ""


func cooldown_left() -> float:
	return float(cooldown_ticks_left()) / float(MatchClock.TICKS_PER_SECOND)


func cooldown_ticks_left() -> int:
	return maxi(0, _ready_at - MatchClock.now())


## "" = ready. Clients see the replicated mana, not the cooldown: the server checks again.
func status(target_pos: Vector3, target: Node3D) -> String:
	if ability == null or locked:
		return Refusal.NO_ABILITY
	if effect == null:
		return Refusal.NOT_IMPLEMENTED
	if MatchClock.now() < _ready_at:
		return Refusal.COOLING
	if cost() > mana_left() + MANA_EPSILON:
		return Refusal.NO_MANA
	var using := using_ability()
	if using and using.is_on():
		return Refusal.BAD_TARGET
	return effect.status(target_pos, target)


## Server or solo. Returns "" when used, else the reason.
func use(target_pos: Vector3, target: Node3D) -> String:
	var reason := status(target_pos, target)
	if not reason.is_empty():
		return reason
	if effect.windup() > 0:
		return windup.begin(target_pos, target)
	var before := mana_left()
	if not effect.fire(target_pos, target):
		return Refusal.BAD_TARGET
	pay()
	start_cooldown(true)
	log_spent(before)
	return ""


## The mana an ability costs: exactly the spell's. 0 (Devour, Play Dead) spends nothing.
func cost() -> float:
	return float(ability.mana_cost) if ability else 0.0


func mana_left() -> float:
	return _mana.current if _mana else 0.0


func pay() -> void:
	_mana.spend(cost())


## Starts the cooldown (`force`, or only if it was 0).
func start_cooldown(force: bool) -> void:
	if effect.starts_cooldown and (force or MatchClock.now() >= _ready_at):
		_ready_at = MatchClock.now() + roundi(ability.cooldown_s * MatchClock.TICKS_PER_SECOND)


func log_spent(before: float) -> void:
	if DebugLog.on(&"ability"):
		print(
			(
				"ability %s mana %d->%d cooldown %d ticks"
				% [ability.display_name, roundi(before), roundi(mana_left()), cooldown_ticks_left()]
			)
		)


## The UsingAbility affliction: while it is on, the body is held for the preparation.
func using_ability() -> Affliction:
	return body.get_node_or_null("Afflictions/UsingAbility") as Affliction if body else null


## Every peer, from UnitBody's mode setter: the Rockform effect draws the shell (any other creature has none).
func show_rock_form(on: bool) -> void:
	var rock := effect as Rockform
	if rock:
		rock.show_rock_form(on)
