class_name MpBootMenu
extends Control

## Drop-in lobby. Prefers an MpFlow autoload if present.
## Otherwise assign `world_scene` and `drive_kit` for a zero-glue loop.
## Does not decide match rules. Copy is @export so each title localizes it.

signal play_solo_pressed
signal hosted
signal joining(ip: String)
signal status_changed(text: String)

@export var world_scene: PackedScene
@export var world_id: StringName = &""
@export var drive_kit: bool = true
@export var max_players: int = 4
@export var room_name: String = "MpKit"
@export var advertise_lan: bool = true

@export var title_text: String = "MpKit"
@export var play_solo_text: String = "Play solo"
@export var host_text: String = "Host LAN"
@export var join_text: String = "Join"
@export var ip_hint: String = "127.0.0.1"
@export var rooms_header: String = "LAN rooms"
@export var idle_status: String = "Pick a mode."
@export var host_fail_status: String = "Could not host (port busy?)"
@export var join_fail_status: String = "Could not join"
@export var bad_ip_status: String = "Invalid IPv4"
@export var joining_status: String = "Connecting to %s…"

var _lan: Label
var _ip: LineEdit
var _status: Label
var _rooms: ItemList
var _beacon: MpLanBeacon
var _room_rows: Array[Dictionary] = []
var _flow: MpFlow


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build()
	_flow = MpFlow.find_in_tree(self)
	if _flow:
		_bind_flow()
	else:
		_bind_local()
	_beacon = MpLan.browse(self)
	_beacon.rooms_changed.connect(_on_rooms)
	if MpBoot.is_dedicated_process():
		visible = false


func _bind_flow() -> void:
	_flow.status_changed.connect(_set_status)
	if world_scene != null:
		_flow.world_scene = world_scene
	if world_id != &"":
		_flow.select_world(world_id)
	if not room_name.is_empty():
		_flow.room_name = room_name
	_flow.advertise_lan = advertise_lan
	_flow.max_players = max_players


func _bind_local() -> void:
	var port := int(MpBoot.user_value("mp-port", "7777"))
	if drive_kit:
		MpKit.configure(port, max_players, 1)
	MpKit.join_failed.connect(_on_join_failed)
	MpKit.load_world.connect(_go_world)
	if MpBoot.is_dedicated_process() and drive_kit:
		var err := MpKit.host_dedicated()
		if err != OK:
			push_error("MpKit.host_dedicated failed: %s" % err)
			get_tree().quit(1)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 1)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	_add_button(box, play_solo_text, _on_play_solo)
	_add_button(box, host_text, _on_host)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	box.add_child(join_row)
	_ip = LineEdit.new()
	_ip.placeholder_text = ip_hint
	_ip.text = ip_hint
	_ip.custom_minimum_size = Vector2(180, 0)
	join_row.add_child(_ip)
	var join_btn := Button.new()
	join_btn.text = join_text
	join_btn.pressed.connect(_on_join)
	join_row.add_child(join_btn)
	var rooms_label := Label.new()
	rooms_label.text = rooms_header
	rooms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rooms_label)
	_rooms = ItemList.new()
	_rooms.custom_minimum_size = Vector2(320, 88)
	_rooms.item_selected.connect(_on_room_selected)
	box.add_child(_rooms)
	_lan = Label.new()
	_lan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var local := MpLan.get_local_ipv4()
	_lan.text = local if not local.is_empty() else "—"
	box.add_child(_lan)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(360, 0)
	_status.text = idle_status
	box.add_child(_status)


func _add_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(cb)
	box.add_child(btn)


func _on_play_solo() -> void:
	play_solo_pressed.emit()
	if _flow:
		_apply_world_to_flow()
		_flow.play_solo()
		return
	if drive_kit:
		MpKit.leave()
	_go_world()


func _on_host() -> void:
	hosted.emit()
	if _flow:
		_apply_world_to_flow()
		_flow.host_lan()
		return
	if drive_kit:
		var err := MpKit.host()
		if err != OK:
			_set_status(host_fail_status)
			return
		if advertise_lan:
			MpLan.advertise(MpKit, room_name, MpKit.port)
		if world_scene != null:
			MpKit.broadcast_load_world()
			_ensure_late_join()
	_go_world()


func _on_join() -> void:
	var ip := _ip.text.strip_edges()
	if not MpLan.is_valid_ipv4(ip):
		_set_status(bad_ip_status)
		return
	joining.emit(ip)
	if _flow:
		_flow.join_lan(ip)
		return
	if drive_kit:
		var err := MpKit.join(ip)
		if err != OK:
			_set_status(join_fail_status)
			return
	_set_status(joining_status % ip)


func _on_join_failed() -> void:
	_set_status(join_fail_status)


func _on_rooms(found: Array) -> void:
	_room_rows.clear()
	_rooms.clear()
	for item in found:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = item
		_room_rows.append(row)
		_rooms.add_item("%s  %s:%d  (%d/%d)" % [
			str(row.get("name", "MpKit")),
			str(row.get("address", "")),
			int(row.get("port", 0)),
			int(row.get("players", 0)),
			int(row.get("max_players", 0)),
		])


func _on_room_selected(index: int) -> void:
	if index < 0 or index >= _room_rows.size():
		return
	var row: Dictionary = _room_rows[index]
	_ip.text = str(row.get("address", ""))


func _apply_world_to_flow() -> void:
	if _flow == null:
		return
	if world_scene != null:
		_flow.world_scene = world_scene
	if world_id != &"":
		_flow.select_world(world_id)


func _go_world() -> void:
	if world_scene == null:
		return
	get_tree().change_scene_to_packed(world_scene)


func _set_status(text: String) -> void:
	_status.text = text
	status_changed.emit(text)


func _ensure_late_join() -> void:
	if MpKit.has_node("MpBootLateJoin"):
		return
	var bridge := LateJoin.new()
	bridge.name = "MpBootLateJoin"
	MpKit.add_child(bridge)


class LateJoin extends Node:
	func _ready() -> void:
		MpKit.peer_joined.connect(_on_peer)

	func _on_peer(peer_id: int, _slot: int) -> void:
		if MpKit.is_server():
			MpKit.load_world_to(peer_id)
