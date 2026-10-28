class_name CowerState
extends UnitState

## COWER: a peasant far from any shelter crouches and waits, regenerating. When the cower clip ends,
## 1 time in TALK_COWER_EVERY the peasant talks while cowering; the pick is (hash(name) + loops) %
## 5, the same on every peer and every run.

const TALK_COWER_EVERY := 5
## The pose of a cowering creature with no cower clip in the cache: the model crouches (presentation
## only, on every peer). With the clip the clip plays instead.
const COWER_SCALE := Vector3(1.08, 0.6, 1.08)

var _role := "cower"
var _loops := 0


func exit() -> void:
	_role = "cower"
	super.exit()


func regenerates() -> bool:
	return true


func clip_role() -> String:
	return _role if body.has_clip(_role) else "idle"


func pose_scale() -> Vector3:
	return Vector3.ONE if body.has_clip("cower") else COWER_SCALE


func on_clip_looped(role: String) -> bool:
	if role != "cower" and role != "talk_cower":
		return false
	_loops += 1
	var talk := (
		posmod(hash(String(body.name)) + _loops, TALK_COWER_EVERY) == 0
		and body.has_clip("talk_cower")
	)
	_role = "talk_cower" if talk else "cower"
	return true
