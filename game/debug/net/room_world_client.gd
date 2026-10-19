extends Node

## RFC-049 049a (F290). One headless player of `agent/runs/run_049a.sh` that, unlike `room_e2e_client`, LOADS THE WORLD: it
## goes through the room server like a person would, joins the dedicated with the real flow (`SacrificeFlow.join_from_lobby`),
## waits until the match scene is up and checks that it is the map the room chose. That is the measure of the order risk
## (snapshot `{map}` before the order to load the world): a wrong order loads High Noon.
## The main scene only starts a twin of this script under `root`, because loading the world frees the main scene.
## Flags: --e2e-name --e2e-room --e2e-peer --e2e-create --e2e-world (the room's map) --e2e-expect-map (default: the world)
## --e2e-wizard --e2e-god --e2e-expect-winner --lobby-port --e2e-bad-world (only create a room with a map that does not exist
## and expect `bad_options`).
## Prints `PASS …` / `FAIL …` per check and `E2E CLIENT <name> PASS|FAIL`; exit 0 / 1.

const LOCAL_HOST := "127.0.0.1"
const GLOBAL_TIMEOUT_S := 150.0
const STEP_S := 60.0
const RUNNER_META := "world_client_runner"

var _name := ""
var _fails := 0
var _finished := false
var _rejected := ""
var _slot := 0
var _error := ""
var _match: Dictionary = {}
var _session_ended: Dictionary = {}


func _ready() -> void:
	if not has_meta(RUNNER_META):
		var twin := (get_script() as GDScript).new() as Node
		twin.set_meta(RUNNER_META, true)
		twin.name = "WorldClientRunner"
		get_tree().root.add_child.call_deferred(twin)
		return
	_name = MpBoot.user_value("e2e-name", "?")
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = GLOBAL_TIMEOUT_S
	timer.timeout.connect(func() -> void:
		print("E2E CLIENT %s FAIL: global timeout" % _name)
		get_tree().quit(1))
	add_child(timer)
	timer.start()
	MpKit.slot_assigned.connect(func(slot: int) -> void: _slot = slot)
	MpKit.admission_rejected.connect(func(reason: String) -> void: _rejected = reason)
	MpKit.session_ended.connect(func(data: Dictionary) -> void: _session_ended = data)
	MpLobby.client.error_received.connect(func(code: String) -> void: _error = code)
	MpLobby.client.match_ready.connect(func(host: String, port: int, token: String) -> void:
		_match = {"host": host, "port": port, "token": token})
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS ", what)
	else:
		_fails += 1
		print("FAIL ", what)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("E2E CLIENT %s %s" % [_name, "PASS" if _fails == 0 else "FAIL: %d" % _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _until(cond: Callable, timeout_s: float = STEP_S) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return cond.call()


func _seat_names() -> PackedStringArray:
	var out := PackedStringArray()
	for seat: Dictionary in MpLobby.client.room.get("seats", []):
		if not bool(seat["free"]):
			out.append(str(seat["name"]))
	out.sort()
	return out


func _my_meta() -> Dictionary:
	for seat: Dictionary in MpLobby.client.room.get("seats", []):
		if bool(seat.get("you", false)):
			return seat.get("meta", {})
	return {}


func _run() -> void:
	var client := MpLobby.client
	var room_name := MpBoot.user_value("e2e-room", "")
	var peer_name := MpBoot.user_value("e2e-peer", "")
	var world := MpBoot.user_value("e2e-world", "")
	var lobby_port := int(MpBoot.user_value("lobby-port", "7700"))
	_check(MpLobby.connect_to(LOCAL_HOST, lobby_port, _name) == OK, "%s connects to the lobby" % _name)
	_check(await _until(func() -> bool: return client.is_online()), "%s is welcomed" % _name)

	# --- a map that does not exist is refused by the room server -------------------------------------------------------
	if MpBoot.user_flag("e2e-bad-world"):
		client.create_room(room_name, false, {"world": "foo"})
		_check(await _until(func() -> bool: return _error == "bad_options", 10.0), "%s: a room with world=foo is refused (bad_options, got '%s')" % [_name, _error])
		_check(client.room.is_empty(), "%s: no room was created" % _name)
		MpLobby.client.close_connection()
		_finish()
		return

	# --- lobby: room with the chosen map, pick, ready -------------------------------------------------------------------
	if MpBoot.user_flag("e2e-create"):
		client.create_room(room_name, false, {"world": world} if not world.is_empty() else {})
	else:
		var joined := false
		for _i in 80:
			client.refresh_rooms()
			await get_tree().create_timer(0.5).timeout
			for row: Dictionary in client.rooms:
				if str(row["name"]) == room_name and not joined:
					joined = true
					client.join_room(str(row["id"]))
			if joined:
				break
		_check(joined, "%s finds the room %s" % [_name, room_name])
	var names := PackedStringArray([_name, peer_name])
	names.sort()
	_check(await _until(func() -> bool: return _seat_names() == names), "%s sees its room: %s" % [_name, ", ".join(names)])
	var want_slot := client.my_seat() + 1
	client.set_pick({
		"wizard": MpBoot.user_value("e2e-wizard", "cwa0"), "model": MpBoot.user_value("e2e-model", "jnwr"),
		"god": MpBoot.user_value("e2e-god", "james"),
	})
	_check(await _until(func() -> bool: return not _my_meta().is_empty()), "%s pick is in the room" % _name)
	client.set_ready(true)
	_check(await _until(func() -> bool: return not _match.is_empty()), "%s gets match_ready" % _name)
	if _match.is_empty():
		_finish()
		return

	# --- the dedicated: the real flow joins it and loads the world it is told to ----------------------------------------
	_check(SacrificeFlow.join_from_lobby(str(_match["host"]), int(_match["port"]), str(_match["token"])) == OK, "%s joins its dedicated" % _name)
	_check(await _until(func() -> bool: return _slot != 0 or not _rejected.is_empty()), "%s gets a slot" % _name)
	_check(_rejected.is_empty() and _slot == want_slot, "%s has the slot of its seat (%d, got %d)" % [_name, want_slot, _slot])
	var expect := MpBoot.user_value("e2e-expect-map", world if not world.is_empty() else "high_noon")
	var loaded := await _until(func() -> bool: return _map_scene_of_world() != "")
	_check(loaded, "%s loaded the match world" % _name)
	var definition := MapCatalog.shared().find(StringName(expect))
	var scene_path := _map_scene_of_world()
	print("E2E_MAP %s tag=%s scene=%s" % [_name, MapCatalog.current_tag(), scene_path])
	_check(MapCatalog.current_tag() == StringName(expect), "%s plays the map %s (got %s)" % [_name, expect, MapCatalog.current_tag()])
	_check(definition != null and scene_path == definition.map_scene_path, "%s world holds the scene of %s (%s)" % [_name, expect, scene_path])

	# --- the end: the dedicated forces a defeat, both clients hear the result ----------------------------------------------
	_check(await _until(func() -> bool: return not _session_ended.is_empty()), "%s gets session_ended" % _name)
	var winner := int(MpBoot.user_value("e2e-expect-winner", "-1"))
	if winner >= 0:
		_check(int(_session_ended.get("winner_slot", -2)) == winner, "%s result winner is slot %d (got %s)" % [_name, winner, str(_session_ended.get("winner_slot"))])
	MpKit.leave()
	MpLobby.client.close_connection()
	_finish()


## The scene file of the map the match scene holds, or "" while the match scene is not up.
func _map_scene_of_world() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var map: Variant = scene.get("map")
	return (map as Node).scene_file_path if map is Node else ""
