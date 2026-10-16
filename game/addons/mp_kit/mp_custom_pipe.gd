class_name MpCustomPipe
extends Node

## One channel of the Dictionary tunnel. Drop one node per manual/low-level feature.
## Does not interpret `data`. Server does not auto-reflect client packets.

@export var channel: StringName = &"custom"

signal packet(data: Dictionary, from_peer: int)


func _ready() -> void:
	MpKit.custom_received.connect(_on_custom_received)


func _exit_tree() -> void:
	if MpKit.custom_received.is_connected(_on_custom_received):
		MpKit.custom_received.disconnect(_on_custom_received)


func send(data: Dictionary) -> void:
	MpKit.send_custom(channel, data)


func broadcast(data: Dictionary) -> void:
	MpKit.broadcast_custom(channel, data)


func push_to(peer_id: int, data: Dictionary) -> void:
	MpKit.push_custom_to(peer_id, channel, data)


func _on_custom_received(name: StringName, data: Dictionary, from_peer: int) -> void:
	if name != channel:
		return
	packet.emit(data, from_peer)
