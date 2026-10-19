extends Node

## F32: the server (or solo) draws one god theme per match and sends theme.god to each
## client on the MpKit custom channel once that client's world is ready. Every peer with
## a screen applies it with ThemeApplier after the world's _ready (sky and environment exist).

signal applied(god: StringName)

const ThemeApplier := preload("res://scenes/world/theme_applier.gd")
const CHANNEL := &"biome"

@export var world: Node3D

var god: StringName = &""
var _world_ready := false


func _ready() -> void:
	MpKit.custom_received.connect(_on_custom_received)
	if _is_authority():
		_draw()
		if MpKit.is_networked():
			MpKit.client_world_ready.connect(_send_to)
			for peer in multiplayer.get_peers():
				if MpKit.is_peer_world_ready(peer):
					_send_to(peer)
	call_deferred("_on_world_ready")


func _exit_tree() -> void:
	if MpKit.custom_received.is_connected(_on_custom_received):
		MpKit.custom_received.disconnect(_on_custom_received)
	if MpKit.client_world_ready.is_connected(_send_to):
		MpKit.client_world_ready.disconnect(_send_to)


func _is_authority() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()


func _draw() -> void:
	var rules: Variant = world.get("rules") if world else null
	var forced: StringName = &""
	var match_seed := 0
	if rules is MatchRules:
		forced = (rules as MatchRules).biome_god
		match_seed = (rules as MatchRules).biome_seed
	if match_seed == 0:
		match_seed = MatchSeed.rng(["biome"]).seed  # the biome stream of the match (randomized without one)
	var picked: StringName = forced if forced != &"" and ThemeApplier.has_theme(forced) else ThemeApplier.pick_god(match_seed)
	if not ThemeApplier.has_theme(picked):
		print("bioma sin tema")
		return
	god = picked
	print("bioma %s semilla %d" % [god, match_seed])


func _send_to(peer_id: int) -> void:
	if god == &"":
		return
	MpKit.push_custom_to(peer_id, CHANNEL, {"god": String(god)})


func _on_custom_received(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel != CHANNEL or _is_authority() or from_peer != MpAuthority.SERVER_PEER:
		return
	var received := StringName(str(data.get("god", "")))
	if not ThemeApplier.has_theme(received):
		return
	god = received
	print("bioma %s" % god)
	_apply()


func _on_world_ready() -> void:
	_world_ready = true
	_apply()


func _apply() -> void:
	if not _world_ready or god == &"" or world == null or MpKit.is_dedicated():
		return
	var theme := ThemeApplier.theme_for(god)
	if theme == null:
		return
	ThemeApplier.apply(theme, world)
	applied.emit(god)
