@tool
class_name AfflictAction
extends SpellAction

## A spell that lays one state on one body (Freeze, Grasping Vines, Rings of Fire, Slime): the click names the body, `target` says who is
## valid, and when the casting time ends the body's Affliction of `affliction` takes it with the spell's numbers. One script for all of
## them; the state's behaviour is the Affliction's and what a hit does is Health's. It does not time the state nor draw it (the
## Affliction and its look do), and it does not scale the duration: the Affliction says how long it lasts.

## The state laid on the body (the child of its Afflictions that has this type).
@export var affliction: AfflictionType
## Who the spell may land on.
@export var target: SpellTarget
## Played on every peer on the target while the wizard casts (the Slime ball that falls on it). Its root answers play(params): `ticks` the
## casting lasts, `target` the body's path. Optional: empty = nothing is drawn on the target.
@export var cast_scene: PackedScene


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if affliction == null:
		warnings.append("`affliction` is missing: the state the spell puts on the target.")
	if target == null:
		warnings.append("`target` is missing: who is a valid target.")
	return warnings


## Funds first (cooldown, mana), then a valid body that can take the state, then the range: the order every spell of the book answers in.
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var body := target.pick(wizard, picked) if target != null else null
	return aim_at_body(wizard, spell, point, funds, body if body != null and _state_of(body) != null else null)


func started(_wizard: WizardBody, _spell: SpellType, aim: Aim, frames: int) -> void:
	if cast_scene != null and aim.target != null:
		FxBus.broadcast_scene(cast_scene, aim.target.global_position, {"ticks": frames, "target": str(aim.target.get_path())})


## The casting time ended: the state goes on the body if it is still a valid one (dead or already protected = nothing).
func finish(wizard: WizardBody, spell: SpellType, picked: Node3D) -> String:
	var body := picked if picked != null and ProjectileTargets.is_live_body(picked) else null
	var state := _state_of(body) if body != null else null
	if state != null:
		state.lay(spell, wizard.owner_slot)
	return ""


## How long the state would last on `body` under `spell`, in seconds (0 = it would not take). The AI rates the spell with it.
func expected_seconds(spell: SpellType, body: Node3D) -> float:
	var state := _state_of(body)
	return float(state.lay_ticks(spell)) / MatchClock.TICKS_PER_SECOND_F if state != null else 0.0


func _state_of(body: Node3D) -> Affliction:
	var afflictions := Afflictions.of(body)
	return afflictions.child_for(affliction) if afflictions != null and affliction != null else null
