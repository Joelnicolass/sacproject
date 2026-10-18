extends Node

## RFC-034 034f playtest (agent/run_pt034f.sh): the second player, headless. It is the main scene of that process
## and hands itself over at once: a copy of this script stays as a child of root (it survives the scene changes)
## and the real room screen (`lobby_screen.tscn`) becomes the current scene. The screen does everything a person
## sees: it reacts to `match_ready` by joining the match, loads High Noon, and comes back to the room when the match
## ends. This node plays the person's part through the same client the buttons use: connect, find the room by name,
## join it, send one chat line, get ready. It never builds the world.
## Flags: --pt-name --pt-room --pt-wizard --pt-god --pt-chat --lobby=host:port.
## Prints `PT034F_PEER <step>` lines, `PASS …` / `FAIL …` per check and `PT034F PEER <name> PASS|FAIL`; exit 0 / 1.

const LOBBY_SCREEN := "res://scenes/ui/lobby/lobby_screen.tscn"
const ENDPOINT := "res://data/net/lobby_endpoint.tres"
const GLOBAL_TIMEOUT_S := 150.0
const STEP_S := 40.0
const BACK_TO_ROOM_S := 90.0
const POLL_S := 0.1
const ROOM_POLL_S := 0.5

var _name: String = "Rival"
var _fails: int = 0
var _finished: bool = false


func _ready() -> void:
	var tree := get_tree()
	if tree.current_scene == self:
		var driver := Node.new()
		driver.set_script(get_script())
		driver.name = "Pt034fPeer"
		tree.root.add_child.call_deferred(driver)
		tree.change_scene_to_file.call_deferred(LOBBY_SCREEN)
		return
	_name = MpBoot.user_value("pt-name", "Rival")
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = GLOBAL_TIMEOUT_S
	timer.timeout.connect(func() -> void:
		print("PT034F PEER %s FAIL: global timeout" % _name)
		tree.quit(1))
	add_child(timer)
	timer.start()
	_run()


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
	print("PT034F PEER %s %s" % [_name, "PASS" if _fails == 0 else "FAIL: %d" % _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _until(cond: Callable, timeout_s: float = STEP_S) -> bool:
	var end := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().create_timer(POLL_S).timeout
	return cond.call()


func _scene_is_screen() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == LOBBY_SCREEN


func _my_seat() -> Dictionary:
	for seat: Dictionary in MpLobby.client.room.get("seats", []):
		if bool(seat.get("you", false)):
			return seat
	return {}


func _run() -> void:
	var client := MpLobby.client
	var room_name := MpBoot.user_value("pt-room", "Duelo")
	SacrificeFlow.set_pick(MpBoot.user_value("pt-wizard", "cwa1"), MpBoot.user_value("pt-god", "pyro"))
	_check(await _until(_scene_is_screen), "%s: the room screen is the current scene" % _name)
	var endpoint := (load(ENDPOINT) as MpLobbyEndpoint).resolved()
	_check(MpLobby.connect_to(endpoint.host, endpoint.port, _name) == OK, "%s connects to the lobby" % _name)
	_check(await _until(client.is_online), "%s is welcomed" % _name)

	# --- the room: find it by name and sit in it --------------------------------------------
	var room_id := ""
	var end_ms := Time.get_ticks_msec() + int(STEP_S * 1000.0)
	while room_id.is_empty() and Time.get_ticks_msec() < end_ms:
		client.refresh_rooms()
		await get_tree().create_timer(ROOM_POLL_S).timeout
		for row: Dictionary in client.rooms:
			if str(row["name"]) == room_name and int(row["state"]) == MpLobbyRooms.State.OPEN:
				room_id = str(row["id"])
	_check(not room_id.is_empty(), "%s finds the room %s" % [_name, room_name])
	if room_id.is_empty():
		_finish()
		return
	client.join_room(room_id)
	_check(await _until(func() -> bool: return not _my_seat().is_empty()), "%s sits in the room" % _name)
	print("PT034F_PEER in_room seat=%d" % client.my_seat())
	# the screen sends the pick of SacrificeFlow by itself; ready needs it
	_check(await _until(func() -> bool: return not (_my_seat().get("meta", {}) as Dictionary).is_empty()), "%s has a pick in the room" % _name)
	client.send_chat(MpBoot.user_value("pt-chat", "Listo para jugar"))
	await get_tree().create_timer(ROOM_POLL_S).timeout
	client.set_ready(true)

	# --- the match: the screen takes the player in; then it brings the player back -------------
	_check(await _until(func() -> bool: return not _scene_is_screen() and MpKit.local_slot() > 0), "%s is in the match (slot %d)" % [_name, MpKit.local_slot()])
	print("PT034F_PEER in_match slot=%d" % MpKit.local_slot())
	_check(await _until(_scene_is_screen, BACK_TO_ROOM_S), "%s is back in the room screen after the match" % _name)
	_check(await _until(func() -> bool: return not (client.room.get("last_result", {}) as Dictionary).is_empty()), "%s sees the result of the match in the room" % _name)
	var result: Dictionary = client.room.get("last_result", {})
	print("PT034F_PEER result winner=%d reason=%s" % [int(result.get("winner_slot", -1)), str(result.get("reason", ""))])
	# a few frames for the room view to draw before the process ends
	await get_tree().create_timer(1.0).timeout
	MpLobby.client.close_connection()
	_finish()
