class_name UnitState
extends FsmState

## One mode of a UnitBody. `mode` is the replicated value this state stands for and the node name is the
## transition key: a state asks for another with transition(&"Chase"). UnitBody.mode stays the only writer (it is replicated
## and many callers set it); its setter moves the machine, so enter/exit run on every peer (presentation only) while
## physics_update runs where the sim runs, called by UnitBody at the point of its physics step that used to be the `match`.
## Ref: RFC-036 036j.

@export var mode: UnitBody.Mode = UnitBody.Mode.IDLE

var body: UnitBody:
	get:
		return actor as UnitBody


func enter() -> void:
	super.enter()
	present(true)


## The look this mode leaves on the body. `animate` false: a peer that joins in this mode (UnitBody._ready).
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


func transition(state_name: StringName) -> void:
	var next := machine.get_node_or_null(NodePath(state_name)) as UnitState if machine != null else null
	if next == null:
		push_warning("UnitState '%s': no state '%s'" % [name, state_name])
		return
	body.mode = next.mode
