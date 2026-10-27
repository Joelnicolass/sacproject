class_name TargetRefresh
extends Node

## The target refresh of a creature (patrol → updateTarget), also while it fights:
## every `interval_s`, a body with no order that is idle, chasing, swinging or shooting asks its picker again
## (UnitBody.closest_foe). The current target weighs x1.3 there and the last attacker x1.2, so a creature hit by a real enemy
## while it beats a Farmer turns to the enemy. A target the picker no longer takes (TargetFutility banned it) and nothing
## else: the body stops. The one owner of the scan without orders (IdleState used to do it, only while idle); under an order
## UnitOrders thinks instead. Server (or solo) only; counts MatchClock ticks. Removing this child: no aggro without orders.
## Ref: RFC-053 053a (F370), sacengine patrol state.d:13029, 13674.

## The body that fights (a UnitBody).
@export var body: UnitBody
@export var interval_s := 0.25

var _next_tick := 0


func _ready() -> void:
	if body == null:
		body = get_parent() as UnitBody


func _get_configuration_warnings() -> PackedStringArray:
	if body == null and not get_parent() is UnitBody:
		return PackedStringArray(["Falta el cuerpo (body)."])
	return PackedStringArray()


func _physics_process(_delta: float) -> void:
	if body == null or not body.simulates():
		return
	var now := MatchClock.now()
	if now < _next_tick:
		return
	_next_tick = now + maxi(1, MatchClock.ticks_for(interval_s))
	refresh()


func refresh() -> void:
	if body.ordered or not body.idle_aggro or body.is_taken() or body.special_forms.playing_dead or body.afflictions.holds():
		return
	var mode := body.mode
	if mode != UnitBody.Mode.IDLE and mode != UnitBody.Mode.CHASE and mode != UnitBody.Mode.ATTACK and mode != UnitBody.Mode.SHOOT:
		return
	var foe := body.engagement.closest_foe(body.global_position)
	if foe == null:
		if mode != UnitBody.Mode.IDLE and body.engagement.is_futile(body.target):
			body.halt()
		return
	if foe != body.target or mode == UnitBody.Mode.IDLE:
		body.engage(foe)
