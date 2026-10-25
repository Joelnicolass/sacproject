class_name MpFlow
extends Node

## Optional session flow. Not gameplay: scenes, host/join/1P, when the world loads.
## Add as autoload (after MpKit) or instance in the boot scene.
## Override `snapshot_for_joiner()` in a subclass for game state.

signal status_changed(text: String)
signal world_loading
signal world_changed(id: StringName)

enum StartWhen {
	LISTEN_IMMEDIATE, ## host_lan() enters the world now
	DEDICATED_FIRST_CLIENT, ## dedicated enters when the first client joins
	MANUAL, ## the flow never loads the world by itself; glue calls start_match()/goto_world()
}

@export var boot_scene: PackedScene
@export var world_scene: PackedScene
@export var boot_path: String = ""
@export var world_path: String = ""
## Several maps: fill this and call `select_world(&"2d")`. Empty = single world_path/world_scene.
@export var worlds: Array[MpWorldRef] = []
@export var world_id: StringName = &""
@export var max_players: int = 4
@export var host_slot: int = 1
@export var room_name: String = "MpKit"
@export var advertise_lan: bool = true
@export var custom_channels: PackedStringArray = PackedStringArray()
@export var start_when: StartWhen = StartWhen.LISTEN_IMMEDIATE

@export var host_fail_status: String = "Could not host (port busy?)"
@export var join_fail_status: String = "Could not join"
@export var bad_ip_status: String = "Invalid IPv4"
@export var joining_status: String = "Connecting to %s…"
@export var server_lost_status: String = "Lost the server"
@export var dedicated_status: String = "Dedicated on port %d"

const PORT_MIN := 1
const PORT_MAX := 65535

## Group every flow joins, so a lobby finds one dropped in its own scene.
const GROUP := &"mp_flow"

var match_running: bool = false

var _lan: MpLanBeacon


static func find_in_tree(from: Node) -> MpFlow:
	if from == null or from.get_tree() == null:
		return null
	for child in from.get_tree().root.get_children():
		if child is MpFlow:
			return child as MpFlow
	## A flow dropped in the boot scene, before it moves itself under the root.
	return from.get_tree().get_first_node_in_group(GROUP) as MpFlow


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	## Dropped in a scene instead of being an autoload: live under the root so a scene change keeps it.
	## A second one (the boot scene loaded again) gives way to the first.
	if get_parent() != get_tree().root:
		_adopt.call_deferred()
		return
	## `--no-flow`: tools and probes that use MpKit directly; the flow never reacts to it.
	if MpBoot.user_flag("no-flow"):
		return
	_pick_world_from_args()
	var port := int(MpBoot.user_value("mp-port", "7777"))
	MpKit.configure(port, max_players, host_slot, custom_channels)
	MpKit.load_world.connect(goto_world)
	MpKit.peer_joined.connect(_on_peer_joined)
	MpKit.join_failed.connect(_on_join_failed)
	MpKit.server_lost.connect(_on_server_lost)
	MpKit.snapshot_received.connect(_on_flow_snapshot)
	var role := MpBoot.role()
	if role == "server":
		var err := MpKit.host_dedicated()
		if err != OK:
			push_error("MpKit.host_dedicated failed: %s" % err)
			get_tree().quit(1)
			return
		match_running = true
		_set_status(dedicated_status % MpKit.port)
		call_deferred("goto_world")
		return
	if role == "listen":
		if host_lan() != OK:
			get_tree().quit(1)
		return
	if role == "client1" or role == "client2":
		var ip := MpBoot.user_value("join-ip", "127.0.0.1")
		var err := join_lan(ip)
		if err != OK:
			get_tree().quit(1)
			return
		return
	if MpBoot.is_dedicated_process():
		var err := MpKit.host_dedicated()
		if err != OK:
			push_error("MpKit.host_dedicated failed: %s" % err)
			get_tree().quit(1)
			return
		_set_status(dedicated_status % MpKit.port)


func _adopt() -> void:
	if not is_inside_tree() or get_parent() == get_tree().root:
		return
	var root := get_tree().root
	for child in root.get_children():
		if child is MpFlow and child != self:
			queue_free()
			return
	get_parent().remove_child(self)
	request_ready()
	root.add_child(self)


func _exit_tree() -> void:
	if MpKit.load_world.is_connected(goto_world):
		MpKit.load_world.disconnect(goto_world)
	if MpKit.peer_joined.is_connected(_on_peer_joined):
		MpKit.peer_joined.disconnect(_on_peer_joined)
	if MpKit.join_failed.is_connected(_on_join_failed):
		MpKit.join_failed.disconnect(_on_join_failed)
	if MpKit.server_lost.is_connected(_on_server_lost):
		MpKit.server_lost.disconnect(_on_server_lost)
	if MpKit.snapshot_received.is_connected(_on_flow_snapshot):
		MpKit.snapshot_received.disconnect(_on_flow_snapshot)


func play_solo() -> void:
	_stop_lan()
	MpKit.leave()
	match_running = true
	goto_world()


func host_lan() -> Error:
	var err := MpKit.host()
	if err != OK:
		_set_status(host_fail_status)
		return err
	_begin_match()
	return OK


func join_lan(ip: String) -> Error:
	var trimmed := ip.strip_edges()
	if not MpLan.is_valid_ipv4(trimmed):
		_set_status(bad_ip_status)
		return ERR_INVALID_PARAMETER
	var err := MpKit.join(trimmed)
	if err != OK:
		_set_status(join_fail_status)
		return err
	_set_status(joining_status % trimmed)
	return OK


## Join a dedicated by host (IPv4 or name) and port; `ticket` is presented for admission.
func join_endpoint(host: String, p_port: int, ticket: String = "") -> Error:
	var trimmed := host.strip_edges()
	if not MpLan.is_valid_ipv4(trimmed) and not MpLan.is_valid_hostname(trimmed):
		_set_status(bad_ip_status)
		return ERR_INVALID_PARAMETER
	if p_port < PORT_MIN or p_port > PORT_MAX:
		_set_status(bad_ip_status)
		return ERR_INVALID_PARAMETER
	var err := MpKit.join(trimmed, p_port, ticket)
	if err != OK:
		_set_status(join_fail_status)
		return err
	_set_status(joining_status % trimmed)
	return OK


func start_match() -> void:
	if match_running:
		return
	if not MpKit.is_server():
		return
	_begin_match()


func return_to_boot() -> void:
	match_running = false
	_stop_lan()
	MpKit.leave()
	_go_boot()


func goto_world() -> void:
	_adopt()
	world_loading.emit()
	var entry := _resolved_world()
	if entry != null:
		var entry_path := entry.resolve_path()
		if not entry_path.is_empty():
			get_tree().change_scene_to_file(entry_path)
			return
		if entry.scene != null:
			get_tree().change_scene_to_packed(entry.scene)
			return
	var path := world_path.strip_edges()
	if not path.is_empty():
		get_tree().change_scene_to_file(path)
		return
	if world_scene != null:
		get_tree().change_scene_to_packed(world_scene)


func add_world(id: StringName, path: String, scene: PackedScene = null) -> MpWorldRef:
	var entry := MpWorldRef.new()
	entry.id = id
	entry.path = path
	entry.scene = scene
	worlds.append(entry)
	if world_id == &"":
		world_id = id
	return entry


func select_world(id: StringName) -> bool:
	if id == &"":
		return false
	if not worlds.is_empty() and _world_entry(id) == null:
		return false
	if world_id == id:
		return true
	world_id = id
	world_changed.emit(world_id)
	return true


func world_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in worlds:
		if entry == null or entry.id == &"":
			continue
		out.append(String(entry.id))
	return out


## Override in a subclass to send extra game state to a late joiner.
func snapshot_for_joiner() -> Dictionary:
	var snap := {}
	var id := _snapshot_world_id()
	if not id.is_empty():
		snap["world_id"] = id
	return snap


func _begin_match() -> void:
	match_running = true
	# Peers already connected (dedicated first client) need the world id too.
	var snap := snapshot_for_joiner()
	if not snap.is_empty():
		MpKit.push_snapshot(snap)
	MpKit.broadcast_load_world()
	_start_advertise()
	goto_world()


func _on_peer_joined(peer_id: int, _slot: int) -> void:
	if match_running:
		var snap := snapshot_for_joiner()
		if not snap.is_empty():
			MpKit.push_snapshot_to(peer_id, snap)
		MpKit.load_world_to(peer_id)
		return
	if MpKit.is_dedicated() and start_when == StartWhen.DEDICATED_FIRST_CLIENT:
		_begin_match()


func _on_join_failed() -> void:
	match_running = false
	_set_status(join_fail_status)


func _on_server_lost() -> void:
	match_running = false
	_stop_lan()
	_set_status(server_lost_status)
	_go_boot()


func _go_boot() -> void:
	_adopt()
	var path := boot_path.strip_edges()
	if not path.is_empty():
		get_tree().change_scene_to_file(path)
		return
	if boot_scene != null:
		get_tree().change_scene_to_packed(boot_scene)


func _start_advertise() -> void:
	if not advertise_lan or not MpKit.is_listen_host():
		return
	_stop_lan()
	_lan = MpLan.advertise(self, room_name, MpKit.port)


func _stop_lan() -> void:
	if _lan == null:
		return
	if is_instance_valid(_lan):
		_lan.stop()
		_lan.queue_free()
	_lan = null


func _set_status(text: String) -> void:
	status_changed.emit(text)


func _pick_world_from_args() -> void:
	var arg := MpBoot.user_value("world", "")
	if not arg.is_empty():
		var named := StringName(arg)
		if worlds.is_empty() or _world_entry(named) != null:
			world_id = named
			return
	if world_id == &"" and not worlds.is_empty() and worlds[0] != null:
		world_id = worlds[0].id


func _on_flow_snapshot(data: Dictionary) -> void:
	var raw := str(data.get("world_id", data.get("world_kind", "")))
	if raw.is_empty():
		return
	select_world(StringName(raw))


func _snapshot_world_id() -> String:
	if world_id != &"":
		return String(world_id)
	var entry := _resolved_world()
	if entry != null:
		return String(entry.id)
	return ""


func _resolved_world() -> MpWorldRef:
	if worlds.is_empty():
		return null
	var match := _world_entry(world_id)
	if match != null:
		return match
	return worlds[0]


func _world_entry(id: StringName) -> MpWorldRef:
	if id == &"":
		return null
	for entry in worlds:
		if entry != null and entry.id == id:
			return entry
	return null
