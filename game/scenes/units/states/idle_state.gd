class_name IdleState
extends UnitState

## IDLE (idle + patrol): regenerates. The scan for an enemy with no order is
## TargetRefresh's, which also runs while the body fights. The rest loop ends in the idle gesture 1 time in GESTURE_EVERY (1/5),
## picked as (hash(name) + loops) % 5: the same on every peer, no randi().

const GESTURE_EVERY := 5

var _loops := 0
var _gesturing := false


func exit() -> void:
	_gesturing = false
	super.exit()


func regenerates() -> bool:
	return true


## "work" for a calm villager (VillagerBrain), then the gesture, else the CRE8 idle0.
func clip_role() -> String:
	var role := body.clips.idle_role
	if role != "idle" and body.has_clip(role):
		return role
	if _gesturing and body.has_clip("gesture"):
		return "gesture"
	return "idle"


func on_clip_looped(role: String) -> bool:
	if role != "idle" and role != "gesture":
		return false
	_loops += 1
	_gesturing = (
		role == "idle"
		and posmod(hash(String(body.name)) + _loops, GESTURE_EVERY) == 0
		and body.has_clip("gesture")
	)
	return true
