class_name Poisoned
extends Node

## F118 (RFC-030g): one dose of poison on a body (creature or wizard), as a child of it. sacengine poison() (state.d:11601-
## 11614) adds a Poison effect per dose; updatePoison (state.d:23535-23590) deals poisonDamage/60 every frame for `lifetime`
## frames through dealPoisonDamage (state.d:9415-9419): Health.damage_typed as splash spell (the cloud passes splash|spell).
## Doses stack: each is its own node. It ends when the body dies (canBePoisoned) or the frames run out. Server (or solo) only;
## Health is replicated, the puff of poison goes through FxBus.
##
## The dose passes ignoreFriendly (dealPoisonDamage, state.d:9418): with the match's friendly fire on, a body of the poisoner's
## own side takes ×1, not ally_damage_factor; with it off, nothing (Health._side_factor, F139).
##
## Not here (RFC-030k, poison of shots): the dose's debuffs (`ires` resistance, `freg` regeneration, `iacc` accuracy), the
## mana block after 2 s (Poison.manaBlockDelay) and infection.

const _HEALTH := preload("res://scenes/world/components/health.gd")
## sacengine updateFPS: the dose deals damage_per_s / 60 per physics frame.
const FPS := 60.0

## Seconds between `poison_dose` puffs on the body: sacengine adds one relativePoison particle (alpha 0.5) every 2 frames
## (state.d:23565-23575); a puff of 15 every 0.5 s is the same rate.
@export var fx_interval_s := 0.5
@export var fx_name := "poison_dose"

## Health per second and frames left; set by start() before the node enters the tree.
var damage_per_s := 0.0
var frames_left := 0
var from_slot := 0
## Health this dose took so far (for the log).
var taken := 0.0

var _health: Health
var _fx_left := 0.0
var _dealt_since_fx := 0.0


## Doses `body` with `damage_per_s` for `frames` physics frames, on behalf of `slot`. Returns the new node.
static func start(body: Node, per_second: float, frames: int, slot: int) -> Node:
	var dose: Node = load("res://scenes/world/units/poisoned.gd").new()
	dose.set("damage_per_s", per_second)
	dose.set("frames_left", frames)
	dose.set("from_slot", slot)
	body.add_child(dose, true)
	return dose


func _ready() -> void:
	_health = get_parent().get_node_or_null("Health") as Health


func _physics_process(delta: float) -> void:
	frames_left -= 1
	if _health == null or frames_left < 0 or _health.is_dead():
		_end()
		return
	var dealt := _health.damage_typed(damage_per_s / FPS, _HEALTH.SPLASH_SPELL, from_slot, true)
	taken += dealt
	_dealt_since_fx += dealt
	_fx_left -= delta
	if _fx_left <= 0.0:
		_fx_left = fx_interval_s
		# Puff only if Health took the poison: a body it refuses (own side with friendly fire off) must not look poisoned.
		if _dealt_since_fx > 0.0:
			FxBus.broadcast(fx_name, (get_parent() as Node3D).global_position + Vector3.UP)
		_dealt_since_fx = 0.0


func _end() -> void:
	var body := get_parent()
	if _health != null:
		var who := str(body.call("display_name")) if body.has_method("display_name") else str(body.name)
		print("veneno %s total %d vida %d" % [who, roundi(taken), roundi(_health.current)])
	queue_free()
