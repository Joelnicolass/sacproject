@tool
class_name Altar
extends StaticBody3D

## An altar and what happens to it. PlayerStart places it and gives it a slot; MatchState decides
## its state (the server runs the clock, every peer applies the state locally).
## STANDING: model, collision and mana. COLLAPSING: the 11 s destruction plays (AltarCollapse);
## the altar still stands for mana and collision, but ghost_form and ritual sites no longer count
## it as an altar in play (sacengine updateAltarDestruction, state.d:25999-26062).
## DESTROYED: no model, no collision, no mana, out of the "altar" group. No manafount is left
## where it stood (RFC-020, decision 4).

enum State { STANDING, COLLAPSING, DESTROYED }

signal state_changed(state: State)

## In the group while STANDING or COLLAPSING: what the rest of the game calls "an altar".
const GROUP := &"altar"
## Always in the group, whatever its state: how MatchState lists every altar of the map.
const ANY_GROUP := &"altar_node"
const MANA_GROUP := &"mana_source"

## Player slot that owns it (PlayerStart sets it). Its ManaSource follows.
@export var owner_slot := 0:
	set(value):
		owner_slot = value
		_pass_owner_to_mana()
@export var state := State.STANDING:
	set(value):
		if state == value:
			return
		state = value
		if is_node_ready():
			_apply()
			state_changed.emit(state)
## Models of the altar (base, pillars, top). Hidden when destroyed, moved by AltarCollapse.
@export var visuals: Node3D
@export var mana_source: ManaSource
## Where a ritual can be held on this altar.
@export var site: RitualSite
@export var collapse: AltarCollapse

var _standing_layer := 1
var _collapse_total := 0.0
var _collapse_elapsed := 0.0


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(ANY_GROUP)
	if state != State.DESTROYED:
		add_to_group(GROUP)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_standing_layer = collision_layer
	_pass_owner_to_mana()
	_apply()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if visuals == null:
		warnings.append("Asigná en `visuals` el nodo que agrupa los modelos del altar.")
	if mana_source == null:
		warnings.append("Asigná en `mana_source` el ManaSource del altar.")
	if site == null:
		warnings.append("Asigná en `site` el RitualSite del altar.")
	if collapse == null:
		warnings.append("Asigná en `collapse` el AltarCollapse del altar.")
	return warnings


func is_standing() -> bool:
	return state == State.STANDING


func is_destroyed() -> bool:
	return state == State.DESTROYED


## Starts the destruction. `total_s` 0 uses the duration of AltarCollapse; `elapsed_s` is how much of
## it already passed (a peer that joins halfway).
func start_collapse(total_s := 0.0, elapsed_s := 0.0) -> void:
	_collapse_total = total_s
	_collapse_elapsed = elapsed_s
	state = State.COLLAPSING


func _pass_owner_to_mana() -> void:
	if mana_source:
		mana_source.owner_slot = owner_slot


func _apply() -> void:
	if Engine.is_editor_hint():
		return
	var alive := state != State.DESTROYED
	collision_layer = _standing_layer if alive else 0
	if visuals:
		visuals.visible = alive
	_set_group(self, GROUP, alive)
	if mana_source:
		mana_source.process_mode = Node.PROCESS_MODE_INHERIT if alive else Node.PROCESS_MODE_DISABLED
		_set_group(mana_source, MANA_GROUP, alive)
	if collapse:
		if state == State.COLLAPSING:
			collapse.play(_collapse_total, _collapse_elapsed)
		else:
			collapse.reset()
			if state == State.DESTROYED and visuals:
				visuals.visible = false


static func _set_group(node: Node, group: StringName, member: bool) -> void:
	if member and not node.is_in_group(group):
		node.add_to_group(group)
	elif not member and node.is_in_group(group):
		node.remove_from_group(group)
