class_name IdleState
extends UnitState

## IDLE (idle + patrol): regenerates and, with no order, scans for the closest enemy every `scan_interval_s`
## (sacengine patrol, state.d:13029). The rest loop ends in the idle gesture 1 time in GESTURE_EVERY (RFC-023,
## sacengine's 1/5, state.d:7957-7992), picked as (hash(name) + loops) % 5: the same on every peer, no randi().

const GESTURE_EVERY := 5

var _scan_left := 0.0
var _loops := 0
var _gesturing := false


func exit() -> void:
	_gesturing = false
	super.exit()


func physics_update(delta: float) -> void:
	body.regenerate(delta)
	if body.ordered or not body.idle_aggro:
		return
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = body.scan_interval_s
	var foe := body.closest_foe(body.global_position)
	if foe:
		body.target = foe
		transition(&"Chase")


## "work" for a calm peasant (PeasantBehavior), then the gesture, else the CRE8 idle0.
func clip_role() -> String:
	var role := body.idle_role()
	if role != "idle" and body.has_clip(role):
		return role
	if _gesturing and body.has_clip("gesture"):
		return "gesture"
	return "idle"


func on_clip_looped(role: String) -> bool:
	if role != "idle" and role != "gesture":
		return false
	_loops += 1
	_gesturing = role == "idle" and posmod(hash(String(body.name)) + _loops, GESTURE_EVERY) == 0 and body.has_clip("gesture")
	return true
