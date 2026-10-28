class_name TargetFutility
extends Node

## The futile targets of a creature: a target it fights that does not lose at least `futile_min_loss` of
## its maximum health within `futile_window_s` is banned for `futile_forget_s`, and TargetPicker passes over it. A Shrike that
## stuns a Farmer misses the next shot at the lying body and the Farmer regenerates in between: without this the creature
## stays on it for good (the user's «mis criaturas no atacan»).
## The window is a rolling one: it starts at the first swing or shot on the target (ATTACK or SHOOT), runs while the body
## keeps it and is read every `sample_s` (the health `futile_window_s` ago against now); a new target starts it again.
## The target of an explicit ATTACK order is never measured (the player's order ignores the ban). Bench log: `targets`.
## Server (or solo) only; counts MatchClock ticks. Removing this child turns the rule off.

## The body that fights (a UnitBody).
@export var body: UnitBody
## Fraction of the target's maximum health it must lose in each window.
@export_range(0.0, 1.0, 0.005) var futile_min_loss := 0.05
@export var futile_window_s := 6.0
@export var futile_forget_s := 15.0
## The targets measured: creatures and wizards. Buildings are not (their guardians take the hits for them).
@export var groups: Array[StringName] = [&"unit", &"wizard"]
## How often the target's health is sampled for the rolling window.
@export var sample_s := 0.25

## instance id -> MatchClock tick when the ban ends.
var _bans: Dictionary = {}
var _target_id := 0
## [tick, health] of the current target since its window started, oldest first (empty: not started).
var _samples: Array[Vector2] = []
var _next_sample := 0


func _ready() -> void:
	if body == null:
		body = get_parent() as UnitBody


func _get_configuration_warnings() -> PackedStringArray:
	if body == null and not get_parent() is UnitBody:
		return PackedStringArray(["Missing the body (body)."])
	return PackedStringArray()


## Whether `node` is banned now (TargetPicker skips it).
func is_banned(node: Variant) -> bool:
	if _bans.is_empty() or node == null or not is_instance_valid(node):
		return false
	var id := (node as Object).get_instance_id()
	if not _bans.has(id):
		return false
	if MatchClock.now() >= int(_bans[id]):
		_bans.erase(id)
		return false
	return true


## Bans `node` for `futile_forget_s` from now.
func ban(node: Node) -> void:
	_bans[node.get_instance_id()] = MatchClock.now() + MatchClock.ticks_for(futile_forget_s)


func _physics_process(_delta: float) -> void:
	if body == null or not body.simulates():
		return
	var target := body.target
	if target == null or not is_instance_valid(target) or not _measured(target) or body.engagement.is_attack_order_on(target):
		_forget()
		return
	var health := target.get_node_or_null("Health") as Health
	if health == null or health.maximum <= 0.0:
		_forget()
		return
	var now := MatchClock.now()
	if target.get_instance_id() != _target_id:
		_forget()
		_target_id = target.get_instance_id()
	if _samples.is_empty():
		if body.mode != UnitBody.Mode.ATTACK and body.mode != UnitBody.Mode.SHOOT:
			return
		_samples.append(Vector2(now, health.current))
		_next_sample = now + maxi(1, MatchClock.ticks_for(sample_s))
		return
	if now < _next_sample:
		return
	_next_sample = now + maxi(1, MatchClock.ticks_for(sample_s))
	_samples.append(Vector2(now, health.current))
	var window := MatchClock.ticks_for(futile_window_s)
	# The newest sample at least a window old is the anchor; older ones are dropped.
	while _samples.size() > 1 and now - int(_samples[1].x) >= window:
		_samples.pop_front()
	if now - int(_samples[0].x) < window:
		return
	var lost := _samples[0].y - health.current
	if lost < futile_min_loss * health.maximum:
		ban(target)
		if DebugLog.on(&"targets"):
			print("%s leaves %s: it lost %.0f of %.0f in %.0f s (futile for %.0f s)" % [
				body.display_name(), target.name, maxf(0.0, lost), health.maximum, futile_window_s, futile_forget_s])
		_forget()


func _forget() -> void:
	_target_id = 0
	_samples.clear()


func _measured(node: Node) -> bool:
	for group in groups:
		if node.is_in_group(group):
			return true
	return false
