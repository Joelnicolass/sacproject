class_name BiomeLink
extends Node

## The one owner of the network channel "biome". The server sends each client, once that client's world is ready (a seat that
## comes back too), the land of the match (the god MatchBiome drew) and the sky's clock and seed (MatchSky.message()); a client
## turns the text back into a GodType, adopts the sky and hands the god to MatchBiome (`adopt`). It does not draw the god nor
## apply its look. Offline it only tells MatchBiome that this process has a screen.

const CHANNEL := &"biome"

## The land of this match (the MatchBiome of the world; it must be ready first: put it above this node).
@export var biome: MatchBiome


func _ready() -> void:
	if biome == null:
		push_error("BiomeLink: set the `biome` socket")
		return
	biome.shows_look = not MpKit.is_dedicated()
	if not MpKit.is_networked():
		return
	if MpKit.is_server():
		MpKit.client_world_ready.connect(send_to)
		for peer in multiplayer.get_peers():
			if MpKit.is_peer_world_ready(peer):
				send_to(peer)
	else:
		MpKit.custom_received.connect(_on_custom_received)


func _exit_tree() -> void:
	if MpKit.custom_received.is_connected(_on_custom_received):
		MpKit.custom_received.disconnect(_on_custom_received)
	if MpKit.client_world_ready.is_connected(send_to):
		MpKit.client_world_ready.disconnect(send_to)


## The server: sends the land and the sky to one client. Nothing while the match has no land.
func send_to(peer_id: int) -> void:
	if biome == null or biome.god == null:
		return
	var payload := {"god": MatchWire.encode_god(biome.god)}
	payload.merge(MatchSky.message())
	MpKit.push_custom_to(peer_id, CHANNEL, payload)


func _on_custom_received(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel != CHANNEL or from_peer != MpAuthority.SERVER_PEER:
		return
	var god := MatchWire.decode_god(str(data.get("god", "")))
	if god == null or god.look == null:
		return
	MatchSky.adopt(float(data.get("at_s", 0.0)), int(data.get("sky_seed", 0)))
	biome.adopt(god)
