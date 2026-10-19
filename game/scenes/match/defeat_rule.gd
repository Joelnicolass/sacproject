@tool
class_name DefeatRule
extends Node

## The server's rule for losing. A side is defeated when its last altar is destroyed (sacengine
## updateAltarDestruction ends in defeat(side), state.d:26062). A wizard that vanishes (GhostForm GONE:
## it died with no altar in play, or under ritual) takes its side down: its altars fall and its
## creatures die (lose(side) = destroyAltars + killAll, state.d:13404-13407, 8298-8304; run when the
## disappearance ends, state.d:25998). When one side is left, it wins (getNewVictories, state.d:30470-30490).
## Other ways to win or lose are other children of Match; taking this one out turns it off.

@export var match_state: MatchState

## Wizards that vanished, waiting to finish disappearing: {slot, left}.
var _vanishing: Array[Dictionary] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if match_state == null:
		push_error("DefeatRule: falta match_state.")
		return
	set_physics_process(match_state.is_authority())
	if not match_state.is_authority():
		return
	match_state.altar_state_changed.connect(_on_altar_state_changed)
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().get_nodes_in_group(GhostForm.GROUP):
		_watch(node as GhostForm)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if match_state == null:
		warnings.append("Asigná en `match_state` el MatchState.")
	return warnings


## Advances the vanishing wizards by `delta` seconds (the physics step; a test may call it).
func tick(delta: float) -> void:
	var done: Array[int] = []
	var waiting: Array[Dictionary] = []
	for entry in _vanishing:
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) <= 0.0:
			done.append(int(entry["slot"]))
		else:
			waiting.append(entry)
	_vanishing = waiting
	for slot in done:
		_lose(slot)


## A side that lost its last altar, or whose wizard vanished.
func defeat(slot: int) -> void:
	if match_state.is_defeated(slot):
		return
	kill_creatures(slot)
	match_state.defeat_side(slot)
	_decide_winner()


## Every living creature of that side in this world dies.
func kill_creatures(slot: int) -> void:
	for node in get_tree().get_nodes_in_group("unit"):
		var unit := node as UnitBody
		if unit == null or unit.owner_slot != slot or unit.is_dead():
			continue
		if match_state.world and not match_state.world.is_ancestor_of(unit):
			continue
		var health: Variant = unit.get_node_or_null("Health")
		if health == null:
			continue
		health.current = 0.0
		health.died.emit(0)


func _physics_process(delta: float) -> void:
	## No match runs in the editor, and the MpKit autoload does not exist there.
	if Engine.is_editor_hint():
		return
	tick(delta)


func _on_node_added(node: Node) -> void:
	if node is GhostForm:
		_watch(node as GhostForm)


func _watch(ghost: GhostForm) -> void:
	if ghost == null or ghost.stage_changed.is_connected(_on_stage_changed):
		return
	ghost.stage_changed.connect(_on_stage_changed.bind(ghost))


func _on_stage_changed(stage: GhostForm.Stage, ghost: GhostForm) -> void:
	if stage != GhostForm.Stage.GONE:
		return
	_vanishing.append({"slot": ghost.owner_slot(), "left": ghost.vanish_seconds()})


## lose(side): its altars fall and its creatures die; with no altar left there is nothing to wait for.
func _lose(slot: int) -> void:
	kill_creatures(slot)
	match_state.begin_altar_collapse(slot, 0)
	if not match_state.has_live_altar(slot):
		defeat(slot)


func _on_altar_state_changed(altar: Altar, state: Altar.State) -> void:
	if state == Altar.State.DESTROYED and not match_state.has_live_altar(altar.owner_slot):
		defeat(altar.owner_slot)


## One team left among the seated sides that own an altar wins (RFC-049 049b: sacengine getNewVictories, state.d:30483-30492:
## no enemy side alive in altarSides); none left, a match with no winner. The winners are the whole team, also the ally that
## fell earlier (P3). With every slot its own team (1v1) this is the old «one side left wins».
func _decide_winner() -> void:
	if match_state.has_result():
		return
	var sides := match_state.sides()
	var alive: Array[int] = []
	var teams: Dictionary = {}
	for slot in sides:
		if not match_state.is_defeated(slot):
			alive.append(slot)
			teams[SideRelations.team_of(slot)] = true
	if alive.is_empty():
		match_state.end_match(0)
	elif teams.size() == 1:
		var winners: Array[int] = []
		var team: int = teams.keys()[0]
		for slot in sides:
			if SideRelations.team_of(slot) == team:
				winners.append(slot)
		match_state.end_match_team(winners)
