class_name AiShotCheck
extends RefCounted

## Whether the wizard may release an attack spell on a body now. It goes only with a clear line; without one the wizard walks
## `los_retry_factor` of the way to the target and tries again. A splash spell (Wrath, Fireball, Swarm) is held back when its
## burst, where it would really burst (the blocker if any, else the target), takes more than `own_splash_max_ratio` of the
## health of an own body. It does not rate and it does not cast: Casting asks it before every cast. RFC-053 053b (F371).
## Ref: shiny.d:3254-3270, 3262.

enum Shot { OK, WALKED, VETOED }

var eval: AiSpellEval
var port: AiCommandPort
var tactics: AiTactics
## Diagnostic: casts held back for want of a clear line (he walked closer) and for the burst they would take from his own bodies.
var line_walks := 0
var splash_vetoes := 0
## The walk toward a target he has no clear line to (its track id and where he was sent), kept while he walks to it.
var _line_target := 0
var _line_goal := Vector3.ZERO


func _init(p_eval: AiSpellEval, p_port: AiCommandPort, p_tactics: AiTactics) -> void:
	eval = p_eval
	port = p_port
	tactics = p_tactics


## OK (cast), WALKED (no clear line: sent closer, but not when `check_only`) or VETOED (skip the entry).
func check(wizard: AiTrack, target: AiTrack, spell: Resource, check_only: bool) -> Shot:
	if not (spell is SpellType) or target == null or not target.is_valid() or target.node == wizard.node:
		return Shot.OK
	var type := spell as SpellType
	if type.is_structure or not AiSpellEval.casts_in(type, SpellType.AiPhase.ATTACK):
		return Shot.OK
	var body := wizard.node as WizardBody
	var splash := AiLineOfFire.is_splash(body, type)
	if not tactics.los_check and not splash:
		return Shot.OK
	var line := AiLineOfFire.trace(body, target.node, type)
	var blocker: Node3D = line["blocker"]
	if tactics.los_check and blocker != null:
		if not check_only:
			_walk_for_line(wizard, target)
		return Shot.WALKED
	_line_target = 0
	if splash and AiAreaRating.own_splash(line["point"], type, blocker if blocker != null else target.node, eval.perception, eval.tactics) \
			> tactics.own_splash_max_ratio:
		splash_vetoes += 1
		return Shot.VETOED
	return Shot.OK


## Walks `los_retry_factor` of the distance to where the side knows the target; while he walks to that spot it is not moved.
func _walk_for_line(wizard: AiTrack, target: AiTrack) -> void:
	var walking := (wizard.node as WizardBody).is_walking()
	if _line_target != target.id or not walking or wizard.cur_pos.distance_squared_to(_line_goal) <= 4.0:
		_line_goal = wizard.cur_pos.lerp(target.cur_pos, tactics.los_retry_factor)
		_line_target = target.id
	line_walks += 1
	port.orders.order_go_to(wizard, AiCommandPort.AiOrder.MOVE_NEAR, _line_goal)
