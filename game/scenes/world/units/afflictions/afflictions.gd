@tool
class_name Afflictions
extends Node

## F120 (RFC-030i): the one owner of «can this creature act?». Its Affliction children are the states (Stunned; later
## Petrified, Frozen), each with its AfflictionType. The body and the rest ask here, never a child:
## holds() (no AI, attack, turn or ability), immobilized() (not even pushed), damage_factor(), cc_protected() and
## clip_role(). Who wins between two states is the data's (`AfflictionType.cancels`), not the order of the children.
##
## The server (or solo) decides; `shown` (one bit per type) is replicated, so on a client a state is on exactly when
## its bit is, and the children draw it from there.

## The state that holds the body started (true) or the last one ended (false). Every peer.
signal held_changed(held: bool)

@export var body: Node3D
## On its death every state ends (sacengine: a dying creature leaves stunned).
@export var health: Health
## The bits of the states that are on (AfflictionType.bit). Replicated by the unit's MultiplayerSynchronizer.
@export var shown := 0:
	set(value):
		if value == shown:
			return
		var was := shown
		shown = value
		if is_node_ready() and not Engine.is_editor_hint():
			_show(was)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if health and (not MpKit.is_networked() or MpKit.is_server()):
		health.died.connect(_on_died)
	if shown != 0:
		_show(0)


func is_on(type: AfflictionType) -> bool:
	return type != null and shown & (1 << type.bit) != 0


func holds() -> bool:
	if shown == 0:
		return false
	for affliction in _on():
		if affliction.type.holds:
			return true
	return false


func immobilized() -> bool:
	for affliction in _on():
		if affliction.type.immobilizes:
			return true
	return false


## Product of the factors of the states that are on (1 with none). Health does not read it yet: Stunned is 1.
## 030i-b (Petrified ×0.2, state.d:8965) makes Health.damage_typed AND Health.damage (melee, which today applies no
## body factor at all, REVIEW-F139 N5) multiply by it.
func damage_factor() -> float:
	var factor := 1.0
	for affliction in _on():
		factor *= affliction.type.damage_factor
	return factor


func cc_protected() -> bool:
	for affliction in _on():
		if affliction.type.cc_protects:
			return true
	return false


## The clip role of the first state that is on and says one; "" when none.
func clip_role() -> String:
	if shown == 0:
		return ""
	for affliction in _on():
		var role := affliction.clip_role()
		if not role.is_empty():
			return role
	return ""


## Server: may `affliction` start? Every state that is on must be one it cancels (so a stunned body refuses a second
## stun, sacengine canStun state.d:8546-8553). The ones it cancels end here.
func admit(affliction: Affliction) -> bool:
	if affliction.type == null or (body and not body.is_inside_tree()):
		return false
	var cancelled: Array[Affliction] = []
	for other in _on():
		if not affliction.type.cancels.has(other.type.id):
			return false
		cancelled.append(other)
	for other in cancelled:
		mark(other, false)
	return true


## Server: puts the bit of `affliction` on or off.
func mark(affliction: Affliction, on: bool) -> void:
	var bit := 1 << affliction.type.bit
	shown = (shown | bit) if on else (shown & ~bit)


func _on() -> Array[Affliction]:
	var found: Array[Affliction] = []
	for child in get_children():
		var affliction := child as Affliction
		if affliction and affliction.type and is_on(affliction.type):
			found.append(affliction)
	return found


func _show(was: int) -> void:
	var was_held := false
	for child in get_children():
		var affliction := child as Affliction
		if affliction == null or affliction.type == null:
			continue
		var bit := 1 << affliction.type.bit
		if was & bit != 0 and affliction.type.holds:
			was_held = true
		if (was & bit) != (shown & bit):
			affliction._shown(shown & bit != 0)
	var held := holds()
	if held != was_held:
		held_changed.emit(held)


func _on_died(_from_slot: int) -> void:
	shown = 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null:
		warnings.append("Falta body: el cuerpo que los estados detienen.")
	if health == null:
		warnings.append("Falta health: sin ella los estados no terminan al morir.")
	return warnings
