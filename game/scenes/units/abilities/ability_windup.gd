class_name AbilityWindup
extends Node

## The preparation of an ability that is not instant (Firewalk, Breath of life, Quake...): the body is held (UsingAbility) and the
## effect fires at `now + windup`. If something cuts it (stunned, frozen) the preparation is over at that tick; the mana is spent
## when the effect fires, even if it did nothing, unless the effect pays upfront (the Jabberocky's Quake), which pays at the start.
## Not: the checks, the mana and the cooldown (AbilitySlot) nor what the effect does (AbilityEffect).
## Server (or solo) only.

@export var slot: AbilitySlot

## MatchClock tick at which the effect fires (-1 = none), where it was ordered and the target it was ordered on.
var _fire_at := -1
var _fire_pos := Vector3.ZERO
var _fire_target: Node3D


## Only the server begins a preparation (`_fire_at` stays -1 on a client), so a client's step does nothing.
func _physics_process(_delta: float) -> void:
	var now := MatchClock.now()
	if _fire_at >= 0:
		# A preparation that something cut (stunned, frozen…) is over at that tick, not at the shoot tick.
		var using := slot.using_ability()
		if using == null or not using.is_on():
			_cut()
		elif now >= _fire_at:
			_finish()


## The body is held until the effect's tick. Nothing is spent yet, unless the effect pays upfront.
func begin(target_pos: Vector3, target: Node3D) -> String:
	var using := slot.using_ability()
	var afflictions := slot.body.afflictions
	if using == null or not afflictions.admit(using):
		return Refusal.BAD_TARGET
	afflictions.mark(using, true)
	var ticks := slot.effect.windup()
	_fire_at = MatchClock.now() + ticks
	_fire_pos = target_pos
	_fire_target = target
	if DebugLog.on(&"ability"):
		print(
			(
				"using ability %s %s %d ticks (tick %d)"
				% [slot.ability.display_name, str(slot.body.name), ticks, MatchClock.now()]
			)
		)
	if slot.effect.pays_upfront:
		var before := slot.mana_left()
		slot.pay()
		slot.log_spent(before)
	return ""


## The preparation was cut: nothing fires. A mana paid at the start stays spent; no cooldown.
func _cut() -> void:
	_fire_at = -1
	if DebugLog.on(&"ability"):
		print(
			(
				"windup cut %s %s (tick %d)"
				% [slot.ability.display_name, str(slot.body.name), MatchClock.now()]
			)
		)


## The effect's tick: if the preparation survived, it fires and the mana is spent even when fire() did nothing.
func _finish() -> void:
	_fire_at = -1
	var using := slot.using_ability()
	var afflictions := slot.body.afflictions
	var target := _fire_target if is_instance_valid(_fire_target) else null
	if slot.effect.pays_upfront:
		# Paid at the start: no mana check here; fire(), then the cooldown if it was 0.
		slot.effect.fire(_fire_pos, target)
		slot.start_cooldown(false)
		if DebugLog.on(&"ability"):
			print(
				(
					"ability %s cooldown %d ticks (tick %d)"
					% [slot.ability.display_name, slot.cooldown_ticks_left(), MatchClock.now()]
				)
			)
		if using.is_on():
			afflictions.mark(using, false)
		return
	var before := slot.mana_left()
	if slot.cost() > before + AbilitySlot.MANA_EPSILON:
		# Mana >= cost at the load tick: short of it, nothing happens and nothing is spent.
		if DebugLog.on(&"ability"):
			print(
				(
					"windup without mana %s %s (tick %d)"
					% [slot.ability.display_name, str(slot.body.name), MatchClock.now()]
				)
			)
		afflictions.mark(using, false)
		return
	slot.effect.fire(_fire_pos, target)
	slot.pay()
	slot.start_cooldown(false)
	slot.log_spent(before)
	if using.is_on():
		afflictions.mark(using, false)
