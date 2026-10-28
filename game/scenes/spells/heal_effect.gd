class_name HealEffect
extends Node

## Heal over time: `amount` health at the heal speed per second, spread over
## ceil(amount / speed * 60) frames. Stops early when the bar is full. A second Heal
## adds its frames and keeps the higher rate. Server (or solo) only; Health is replicated.

## Loaded when needed: the scene holds this script, so a preload would be cyclic.
const _SCENE_PATH := "res://scenes/spells/heal_effect.tscn"
const NODE_NAME := "HealEffect"
## Heal speed.
const HEAL_SPEED := 240.0
## A saturated add caps the frames of heals that add up there.
const FRAMES_CAP := 2147483647

## Played on the target every `fx_interval_s`. Empty = no bursts.
@export var heal_fx: ParticleType
## Where on the target's body the burst plays.
@export var heal_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER
## Seconds between `heal_fx` bursts on the target.
@export var fx_interval_s := 0.5

## Prints «heal <who> total N health V» when it ends (the Healing Shower's log). Off for the Heal
## spell.
var report_end := false
## Prints «heal <who> +N health V» each tick it heals (Devour's cure). Off for every other heal.
var report_each := false
var frames_left := 0
var _healed := 0.0
var per_frame := 0.0
var _health: Health
var _fx_left := 0.0


## Alive and not full.
static func can_heal(body: Node) -> bool:
	var health := body.get_node_or_null("Health") as Health
	return health != null and not health.is_dead() and not health.is_full()


## The HealEffect of `target`, made if it has none (one per body; a second heal adds to it).
static func on(target: Node) -> HealEffect:
	var effect := target.get_node_or_null(NODE_NAME) as HealEffect
	if effect == null:
		effect = (load(_SCENE_PATH) as PackedScene).instantiate() as HealEffect
		effect.name = NODE_NAME
		target.add_child(effect)
	return effect


## Heal with an infinite amount (Healing Shower tum@, Scarab slba): the body's the maximum health in
## total. Skips a body that cannot heal and returns null; else the HealEffect it added to.
## `report_end` prints «heal <who> total N health V» when that heal ends.
static func heal_full(body: Node, report_end := false) -> Node:
	if not can_heal(body):
		return null
	var effect := on(body)
	effect.add((body.get_node("Health") as Health).maximum)
	if report_end:
		effect.report_end = true
	return effect


func add(amount: float) -> void:
	var frames := ceili(amount / HEAL_SPEED * MatchClock.TICKS_PER_SECOND_F)
	# A heal already running gets the new frames on top, saturated.
	frames_left = mini(frames_left + frames, FRAMES_CAP)
	per_frame = maxf(per_frame, amount / float(frames))


## The timer goes back to `frames` and the rate to the better of the two; nothing is added. A body
## that is carried by the aura calls it every tick.
func renew(rate_per_frame: float, frames: int) -> void:
	frames_left = maxi(frames_left, frames)
	per_frame = maxf(per_frame, rate_per_frame)


func _ready() -> void:
	_health = get_parent().get_node_or_null("Health") as Health


func _physics_process(delta: float) -> void:
	frames_left -= 1
	if _health == null or frames_left < 0 or _health.is_dead():
		_end()
		return
	var before := _health.current
	_health.heal(per_frame)
	_healed += float(_health.get("current")) - before
	if report_each:
		print(
			(
				"heal %s +%.3f health %.1f (tick %d)"
				% [
					get_parent().name,
					float(_health.get("current")) - before,
					float(_health.get("current")),
					MatchClock.now()
				]
			)
		)
	_fx_left -= delta
	if _fx_left <= 0.0:
		_fx_left = fx_interval_s
		FxBus.broadcast(heal_fx, BodyFacts.point(get_parent() as Node3D, heal_socket))
	if _health.is_full():
		_end()


func _end() -> void:
	if report_end and _health != null:
		var body := get_parent()
		var who := GameBody.name_of(body)
		print(
			(
				"heal %s total %d health %d"
				% [who, roundi(_healed), roundi(float(_health.get("current")))]
			)
		)
	queue_free()
