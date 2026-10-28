class_name AbilityPort
extends Node

## The door of a creature's active ability: the owner's click (`request`) is checked here and sent
## to the server, which uses the ability (`use`) after checking again. A creature that is dead,
## being summoned, taken or held refuses at once.
## Not: the cost, the cooldown and the effect (AbilitySlot).

@export var body: UnitBody
@export var slot: AbilitySlot


## The input calls this for Ctrl+Q / Shift+B on the owner's peer. Returns the local refusal (mana,
## no ability, «No implementado»), or "" once sent. The server checks the cooldown again.
func request(target_pos: Vector3, foe: Node3D = null) -> String:
	var reason := status(target_pos, foe)
	if not reason.is_empty() or not MpAuthority.should_send_command():
		return reason if not reason.is_empty() else use(target_pos, foe)
	(
		submit_ability
		. rpc_id(
			MpAuthority.SERVER_PEER,
			{
				"x": target_pos.x,
				"y": target_pos.y,
				"z": target_pos.z,
				"target": str(foe.get_path()) if foe else "",
			}
		)
	)
	return ""


func status(target_pos: Vector3, foe: Node3D = null) -> String:
	if _refused():
		return Refusal.BAD_TARGET
	return slot.status(target_pos, foe)


## Server or solo: uses the ability. "" = used.
func use(target_pos: Vector3, foe: Node3D = null) -> String:
	if _refused():
		return Refusal.BAD_TARGET
	return slot.use(target_pos, foe)


@rpc("any_peer", "call_remote", "reliable")
func submit_ability(payload: Dictionary) -> void:
	if not MpAuthority.accept_command(body, body.owner_slot):
		return
	var path := str(payload.get("target", ""))
	var foe := get_node_or_null(path) as Node3D if not path.is_empty() else null
	use(Vector3(float(payload["x"]), float(payload["y"]), float(payload["z"])), foe)


func _refused() -> bool:
	return body.is_dead() or body.is_summoning() or body.is_taken() or body.afflictions.holds()
