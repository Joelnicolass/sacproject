extends Node

## sacengine heal(): `amount` health at healSpeed per second, spread over
## ceil(amount / healSpeed * 60) frames. Stops early when the bar is full. A second Heal
## adds its frames and keeps the higher rate. Server (or solo) only; Health is replicated.

const NODE_NAME := "HealEffect"
## sacengine healSpeed.
const HEAL_SPEED := 240.0
const FPS := 60.0
## sacengine int.max (32 bits): satAdd caps the frames of heals that add up there (state.d:10455).
const FRAMES_CAP := 2147483647

## Seconds between `heal` bursts on the target (sacengine spawns particles every frame).
@export var fx_interval_s := 0.5

## Prints «cura <who> total N vida V» when it ends (the Healing Shower's log, F118). Off for the Heal spell.
var report_end := false
var frames_left := 0
var _healed := 0.0
var per_frame := 0.0
var _health: Node
var _fx_left := 0.0


## sacengine canHeal: alive and not full.
static func can_heal(body: Node) -> bool:
	var health := body.get_node_or_null("Health")
	return health != null and not health.call("is_dead") and not health.call("is_full")


## The HealEffect of `target`, made if it has none (one per body; a second heal adds to it).
static func on(target: Node) -> Node:
	var effect: Node = target.get_node_or_null(NODE_NAME)
	if effect == null:
		effect = load("res://scenes/world/spells/heal_effect.gd").new()
		effect.name = NODE_NAME
		target.add_child(effect)
	return effect


## sacengine heal() with an infinite amount (Healing Shower tum@, Scarab slba; sacspell.d:211, state.d:10446-10449): the body's
## maxHealth in total. Skips a body that cannot heal (canHeal) and returns null; else the HealEffect it added to.
## `report_end` prints «cura <who> total N vida V» when that heal ends.
static func heal_full(body: Node, report_end := false) -> Node:
	if not can_heal(body):
		return null
	var effect := on(body)
	effect.call("add", float(body.get_node("Health").get("maximum")))
	if report_end:
		effect.set("report_end", true)
	return effect


func add(amount: float) -> void:
	var frames := ceili(amount / HEAL_SPEED * FPS)
	## A heal already running gets the new frames on top, saturated (satAdd, state.d:10455).
	frames_left = mini(frames_left + frames, FRAMES_CAP)
	per_frame = maxf(per_frame, amount / float(frames))


func _ready() -> void:
	_health = get_parent().get_node_or_null("Health")


func _physics_process(delta: float) -> void:
	frames_left -= 1
	if _health == null or frames_left < 0 or _health.call("is_dead"):
		_end()
		return
	var before := float(_health.get("current"))
	_health.call("heal", per_frame)
	_healed += float(_health.get("current")) - before
	_fx_left -= delta
	if _fx_left <= 0.0:
		_fx_left = fx_interval_s
		FxBus.broadcast("heal", (get_parent() as Node3D).global_position + Vector3.UP)
	if _health.call("is_full"):
		_end()


func _end() -> void:
	if report_end and _health != null:
		var body := get_parent()
		var who := str(body.call("display_name")) if body.has_method("display_name") else str(body.name)
		print("cura %s total %d vida %d" % [who, roundi(_healed), roundi(float(_health.get("current")))])
	queue_free()
