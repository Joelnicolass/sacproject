# meta-name: MpKit replicated
# meta-description: submit_*/apply_* host-authoritative (LAN and dedicated)
# meta-default: false
extends _BASE_


@export var player_slot: int = 0


func try_action(payload: Dictionary) -> void:
	if MpAuthority.should_send_command():
		submit_action.rpc_id(1, payload)
	else:
		apply_action(payload)


@rpc("any_peer", "call_remote", "reliable")
func submit_action(payload: Dictionary) -> void:
	if not MpAuthority.accept_command(self, player_slot):
		return
	apply_action(payload)


func apply_action(payload: Dictionary) -> void:
	pass
