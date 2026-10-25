class_name MpLobbyScreen
extends Control

## Drop-in online lobby: connect with a name, see the public rooms, create one (public or with a code), take a seat,
## say ready and chat. When every seat is ready the room server starts the match and this screen joins it through
## MpFlow; when the match ends the flow comes back here and the last result shows. Texts are @export (translate them);
## the look comes from the Theme. Each button calls a public method, so a game can build its own screen on them.
## Not: the rules of a room (MpRoomRules on the server), the player's pick (call `set_pick` from your own UI).

@export var lobby_address: String = "127.0.0.1:7700"
@export var player_name: String = "Player"
## The pick every seat starts with (character, team...). The lobby needs one before "ready"; a game without
## choices can keep this one. Change it with set_pick() (and check it in MpRoomRules.accept_pick).
@export var default_pick: Dictionary = {"pick": "default"}
## Join the match as soon as the room server starts it. Off = `match_found` is emitted and your UI calls join_found().
@export var auto_join_match: bool = true
## Scene of the "Back" button (usually the boot menu).
@export_file("*.tscn") var back_path: String = ""

@export_group("Texts")
@export var title_text: String = "Online rooms"
@export var connect_text: String = "Connect"
@export var back_text: String = "Back"
@export var refresh_text: String = "Refresh"
@export var create_text: String = "Create room"
@export var private_text: String = "Private (code)"
@export var join_text: String = "Join"
@export var join_code_text: String = "Join with code"
@export var ready_text: String = "Ready"
@export var leave_text: String = "Leave room"
@export var send_text: String = "Send"
@export var connecting_status: String = "Connecting…"
@export var online_status: String = "Online. Pick a room or create one."
@export var lost_status: String = "Lost the lobby (%s)"
@export var error_status: String = "Error: %s"
@export var countdown_status: String = "Starting in %d…"
@export var joining_status: String = "Joining the match…"
@export var result_status: String = "Last match: %s"

## The room server started this player's match (only with auto_join_match off; call join_found() to go).
signal match_found(host: String, port: int, token: String)

var _ui: MpLobbyUi
var _found: Array = []
var _client: MpLobbyClient
var _room_ids: PackedStringArray = PackedStringArray()
var _picked: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_ui = MpLobbyUi.new(self)
	_bind.call_deferred()


func _bind() -> void:
	_client = MpLobbyLink.client(get_tree())
	## The lobby talks like the matches: the flow's MpNetConfig says whether that is wss:// (and with which CA).
	var flow := MpFlow.find_in_tree(self)
	if flow and flow.net_config and flow.net_config.client_tls():
		_client.tls = flow.net_config.client_tls()
	_client.lobby_joined.connect(_on_joined)
	_client.lobby_lost.connect(_on_lost)
	_client.room_list_received.connect(_on_rooms)
	_client.room_updated.connect(_on_room)
	_client.room_left.connect(_on_room_left)
	_client.chat_received.connect(_on_chat)
	_client.countdown_started.connect(_on_countdown)
	_client.match_ready.connect(_on_match_ready)
	_client.error_received.connect(_on_error)
	_client.rejected.connect(_on_error)
	if _client.is_online():
		_ui.show_page(&"room" if not _client.room.is_empty() else &"rooms")
		if not _client.room.is_empty():
			_on_room(_client.room)
		_client.refresh_rooms()
	else:
		_ui.show_page(&"connect")


## "host:port" (or the default lobby address) and a display name.
func connect_lobby(address: String = "", display_name: String = "") -> Error:
	var text := address.strip_edges() if not address.is_empty() else lobby_address
	var host := text.get_slice(":", 0)
	var port := int(text.get_slice(":", 1)) if text.count(":") == 1 else 7700
	_status(connecting_status)
	return _client.connect_to(host, port, display_name if not display_name.is_empty() else player_name)


func refresh() -> void:
	_client.refresh_rooms()


func create_room(room_name: String, is_private: bool = false, options: Dictionary = {}) -> void:
	_client.create_room(room_name, is_private, options)


func join_room(room_id: String) -> void:
	_client.join_room(room_id)


## The room at `index` of the visible list.
func join_listed(index: int) -> void:
	if index >= 0 and index < _room_ids.size():
		join_room(_room_ids[index])


func join_code(code: String) -> void:
	_client.join_code(code.strip_edges().to_upper())


func set_ready(on: bool) -> void:
	if on and not _picked and not default_pick.is_empty():
		_picked = true
		set_pick(default_pick)
	_client.set_ready(on)


func set_pick(pick: Dictionary) -> void:
	_client.set_pick(pick)


func leave_room() -> void:
	_client.leave_room()


func send_chat(text: String) -> void:
	if not text.strip_edges().is_empty():
		_client.send_chat(text)


func go_back() -> void:
	_client.close_connection()
	if not back_path.is_empty():
		get_tree().change_scene_to_file(back_path)


## Room ids of the visible list, in order.
func listed_rooms() -> PackedStringArray:
	return _room_ids


func _exit_tree() -> void:
	if _client == null:
		return
	for pair in [[_client.lobby_joined, _on_joined], [_client.lobby_lost, _on_lost], [_client.room_list_received, _on_rooms],
			[_client.room_updated, _on_room], [_client.room_left, _on_room_left], [_client.chat_received, _on_chat],
			[_client.countdown_started, _on_countdown], [_client.match_ready, _on_match_ready],
			[_client.error_received, _on_error], [_client.rejected, _on_error]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


func _on_joined(_session_id: String) -> void:
	_status(online_status)
	_client.refresh_rooms()


func _on_lost(reason: String) -> void:
	_status(lost_status % reason)
	_ui.show_page(&"connect")


func _on_room_left() -> void:
	_picked = false
	_ui.show_page(&"rooms")
	_client.refresh_rooms()


func _on_chat(seat: int, who: String, text: String) -> void:
	_ui.add_chat("%d %s: %s" % [seat + 1, who, text])


func _on_countdown(seconds: float) -> void:
	_status(countdown_status % ceili(seconds))


func _on_error(code: String) -> void:
	_status(error_status % code)


func _on_rooms(rows: Array) -> void:
	_room_ids.clear()
	var lines := PackedStringArray()
	for row: Dictionary in rows:
		_room_ids.append(str(row["id"]))
		lines.append("%s  %d/%d" % [row["name"], int(row["seats_used"]), int(row["seats"])])
	_ui.set_rooms(lines)


func _on_room(view: Dictionary) -> void:
	if view.is_empty():
		return
	_ui.show_page(&"room")
	if not _picked and not default_pick.is_empty():
		_picked = true
		set_pick(default_pick)
	var lines := PackedStringArray()
	for seat: Dictionary in view["seats"]:
		if bool(seat["free"]):
			lines.append("%d  —" % (int(seat["seat"]) + 1))
			continue
		var who := "bot" if bool(seat.get("bot", false)) else str(seat["name"])
		var marks := ("  ★" if bool(seat.get("host", false)) else "") + ("  ✓" if bool(seat["ready"]) else "")
		lines.append("%d  %s%s%s" % [int(seat["seat"]) + 1, who, marks, "  ←" if bool(seat.get("you", false)) else ""])
	var code := "  [%s]" % view["code"] if view.has("code") else ""
	_ui.set_room(str(view["name"]) + code, lines)
	if view.get("last_result", {}) is Dictionary and not (view["last_result"] as Dictionary).is_empty():
		_status(result_status % JSON.stringify(view["last_result"]))


func _on_match_ready(host: String, port: int, token: String) -> void:
	_found = [host, port, token]
	if not auto_join_match:
		match_found.emit(host, port, token)
		return
	join_found()


## Joins the match the room server started for this player (after match_found).
func join_found() -> void:
	if _found.is_empty():
		return
	var host: String = _found[0]
	var port: int = _found[1]
	var token: String = _found[2]
	_status(joining_status)
	var flow := MpFlow.find_in_tree(self)
	if flow == null:
		push_error("MpLobbyScreen: no MpFlow in the tree to join the match")
		return
	flow.join_match(host, port, token)


func _status(text: String) -> void:
	_ui.set_status(text)
