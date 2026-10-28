class_name UnitState
extends FsmState

## One mode of a UnitBody. `mode` is the replicated value this state stands for and the node name is the
## transition key: a state asks for another with transition(&"Chase"). UnitBody.mode stays the only writer (it is replicated
## and many callers set it); its setter moves the machine, so enter/exit run on every peer (presentation only) while
## physics_update runs where the sim runs, called by UnitBody at its point of the physics step.

## Start payload of a body born in this mode (UnitBody._ready): its look, without the animation.
const JOINED := {"animate": false}

@export var mode: UnitBody.Mode = UnitBody.Mode.IDLE

var body: UnitBody:
	get:
		return actor as UnitBody


func enter() -> void:
	super.enter()
	present(not (machine.payload is Dictionary and machine.payload == JOINED))


## The look this mode leaves on the body. `animate` false: a body born in this mode (started with JOINED).
func present(_animate: bool) -> void:
	pass


## Dead and summoning bodies that stand on the ground skip the rest of the physics step.
func rests_on_floor() -> bool:
	return false


## At rest in this mode the creature regenerates (UnitBody._regenerate_step asks): idle, cower, rock form.
func regenerates() -> bool:
	return false


## The clip role of the mode, after the held / captive / flight roles of UnitBody have been ruled out.
func clip_role() -> String:
	return "idle"


## The scale of the Tilt pivot in this mode.
func pose_scale() -> Vector3:
	return Vector3.ONE


## A clip of this mode looped (BodyAnimator.clip_looped). True when the clip must be chosen again.
func on_clip_looped(_role: String) -> bool:
	return false
