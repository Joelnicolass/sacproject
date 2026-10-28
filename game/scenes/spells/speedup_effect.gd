class_name SpeedupEffect
extends Node

## Speed boost: on a wizard it lasts duration * 0.2 + 0.5 s, on a creature
## duration * 1000 / max health + 0.5 s. The factor is 1 + 0.75 * min(1, frames_left / 60):
## ×1.75, easing back to ×1 in the last second. Gives its factor to the body's PaceFactors (the one owner of speed_factor); a body without it (the Sac Doctor) gets speed_factor written directly.
## Server (or solo) only: the body is simulated there.

const NODE_NAME := "SpeedupEffect"
## The PaceFactors source of this effect.
const SOURCE := &"speedup"
const BONUS := 0.75
const WIZARD_DURATION_FACTOR := 0.2
const EXTRA_S := 0.5

## Played on the target every `fx_interval_s`. Empty = no bursts.
@export var speedup_fx: ParticleType
## Where on the target's body the burst plays.
@export var speedup_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER
## Seconds between `speedup_fx` bursts on the target.
@export var fx_interval_s := 1.0

var frames_left := 0
var _fx_left := 0.0


## Seconds of Speedup on `body`, or -1 when it cannot take it (already sped up: the
## spell's exclusion).
static func duration_s(body: Node, spell: SpellType) -> float:
	if not "speed_factor" in body or body.get_node_or_null(NODE_NAME) != null:
		return -1.0
	if body.is_in_group(WizardBody.GROUP):
		return spell.duration_s * WIZARD_DURATION_FACTOR + EXTRA_S
	var health := body.get_node_or_null("Health")
	if health == null or float(health.get("maximum")) <= 0.0:
		return -1.0
	return spell.duration_s * 1000.0 / float(health.get("maximum")) + EXTRA_S


func start(seconds: float) -> void:
	frames_left = int(seconds * MatchClock.TICKS_PER_SECOND_F)


func _physics_process(delta: float) -> void:
	var body := get_parent()
	frames_left -= 1
	if frames_left <= 0:
		queue_free()
		return
	_give(body, 1.0 + BONUS * minf(1.0, float(frames_left) / MatchClock.TICKS_PER_SECOND_F))
	_fx_left -= delta
	if _fx_left <= 0.0:
		_fx_left = fx_interval_s
		FxBus.broadcast(speedup_fx, BodyFacts.point(body as Node3D, speedup_socket))


func _exit_tree() -> void:
	_give(get_parent(), 1.0)


## The pace goes through PaceFactors when the body has it; else (the doctor) it is written as it always was.
func _give(body: Node, factor: float) -> void:
	var pace := PaceFactors.of(body)
	if pace != null:
		pace.set_factor(SOURCE, factor)
	else:
		body.set("speed_factor", factor)
