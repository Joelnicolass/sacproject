extends Node

## sacengine heal(): `amount` health at healSpeed per second, spread over
## ceil(amount / healSpeed * 60) frames. Stops early when the bar is full. A second Heal
## adds its frames and keeps the higher rate. Server (or solo) only; Health is replicated.

const NODE_NAME := "HealEffect"
## sacengine healSpeed.
const HEAL_SPEED := 240.0
const FPS := 60.0

## Seconds between `heal` bursts on the target (sacengine spawns particles every frame).
@export var fx_interval_s := 0.5

var frames_left := 0
var per_frame := 0.0
var _health: Node
var _fx_left := 0.0


## sacengine canHeal: alive and not full.
static func can_heal(body: Node) -> bool:
	var health := body.get_node_or_null("Health")
	return health != null and not health.call("is_dead") and not health.call("is_full")


func add(amount: float) -> void:
	var frames := ceili(amount / HEAL_SPEED * FPS)
	frames_left += frames
	per_frame = maxf(per_frame, amount / float(frames))


func _ready() -> void:
	_health = get_parent().get_node_or_null("Health")


func _physics_process(delta: float) -> void:
	frames_left -= 1
	if _health == null or frames_left < 0 or _health.call("is_dead"):
		queue_free()
		return
	_health.call("heal", per_frame)
	_fx_left -= delta
	if _fx_left <= 0.0:
		_fx_left = fx_interval_s
		FxBus.broadcast("heal", (get_parent() as Node3D).global_position + Vector3.UP)
	if _health.call("is_full"):
		queue_free()
