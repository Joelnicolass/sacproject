class_name MpLanBeacon
extends Node

## UDP broadcast rooms. Advertise from the host; browse from the join screen.

signal rooms_changed(rooms: Array)

const MAGIC := "MPKIT1"

@export var discover_port: int = 7778
@export var broadcast_hz: float = 1.0

var rooms: Array[Dictionary] = []

var _udp: PacketPeerUDP
var _advertising: bool = false
var _browsing: bool = false
var _room_name: String = "MpKit"
var _game_port: int = 7777
var _accum: float = 0.0
var _by_key: Dictionary = {}


func _ready() -> void:
	set_process(false)


func start_advertise(room_name: String = "MpKit", game_port: int = -1) -> Error:
	stop()
	_room_name = room_name
	_game_port = game_port if game_port > 0 else MpKit.port
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	var err := _udp.bind(0)
	if err != OK:
		_udp = null
		return err
	_udp.set_dest_address("255.255.255.255", discover_port)
	_advertising = true
	_accum = 0.0
	set_process(true)
	_send_advert()
	return OK


func start_browse() -> Error:
	stop()
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(discover_port)
	if err != OK:
		_udp = null
		return err
	_browsing = true
	set_process(true)
	return OK


func stop() -> void:
	_advertising = false
	_browsing = false
	set_process(false)
	if _udp:
		_udp.close()
		_udp = null
	_by_key.clear()
	rooms.clear()


func _exit_tree() -> void:
	stop()


func _process(delta: float) -> void:
	if _advertising:
		_accum += delta
		if _accum >= 1.0 / maxf(broadcast_hz, 0.2):
			_accum = 0.0
			_send_advert()
		return
	if not _browsing or _udp == null:
		return
	var dirty := false
	while _udp.get_available_packet_count() > 0:
		var bytes := _udp.get_packet()
		var from := _udp.get_packet_ip()
		if _ingest(bytes, from):
			dirty = true
	_prune()
	if dirty:
		rooms_changed.emit(rooms)


func _send_advert() -> void:
	if _udp == null:
		return
	var payload := {
		"v": MAGIC,
		"n": _room_name,
		"p": _game_port,
		"c": MpKit.occupied_slots().size() if MpKit.is_networked() else 1,
		"m": MpKit.max_players,
	}
	_udp.put_packet(JSON.stringify(payload).to_utf8_buffer())


func _ingest(bytes: PackedByteArray, from: String) -> bool:
	if from.is_empty() or from.begins_with("127."):
		# Still accept loopback so two local instances find each other.
		pass
	var text := bytes.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	if str(data.get("v", "")) != MAGIC:
		return false
	var port := int(data.get("p", 0))
	if port <= 0:
		return false
	var address := from
	if address.is_empty():
		address = "127.0.0.1"
	var key := "%s:%d" % [address, port]
	_by_key[key] = {
		"name": str(data.get("n", "MpKit")),
		"address": address,
		"port": port,
		"players": int(data.get("c", 0)),
		"max_players": int(data.get("m", 0)),
		"seen": Time.get_ticks_msec(),
	}
	_rebuild()
	return true


func _prune() -> void:
	var now := Time.get_ticks_msec()
	var drop: Array[String] = []
	for key in _by_key.keys():
		var row: Dictionary = _by_key[key]
		if now - int(row.get("seen", 0)) > 4000:
			drop.append(str(key))
	if drop.is_empty():
		return
	for key in drop:
		_by_key.erase(key)
	_rebuild()
	rooms_changed.emit(rooms)


func _rebuild() -> void:
	rooms.clear()
	for key in _by_key.keys():
		var row: Dictionary = _by_key[key].duplicate()
		row.erase("seen")
		rooms.append(row)
