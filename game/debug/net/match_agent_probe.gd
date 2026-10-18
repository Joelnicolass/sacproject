extends Node

## Dedicated of the launcher probe (RFC-034 034b): hosts on `--mp-port` and reports a result
## one second after the first admitted player. Nothing of the game.

const REPORT_DELAY_S := 1.0
const PROBE_MAX_PLAYERS := 2

@onready var agent: MpMatchAgent = %Agent


func _ready() -> void:
	MpKit.configure(int(MpBoot.user_value("mp-port", "7777")), PROBE_MAX_PLAYERS, 1)
	if MpKit.host_dedicated() != OK:
		get_tree().quit(1)
		return
	MpKit.peer_joined.connect(_on_peer_joined)
	print("probe dedicated listening on ", MpKit.port)


func _on_peer_joined(_peer_id: int, slot: int) -> void:
	await get_tree().create_timer(REPORT_DELAY_S).timeout
	agent.report_result({"winner_slot": slot, "reason": "probe"})
