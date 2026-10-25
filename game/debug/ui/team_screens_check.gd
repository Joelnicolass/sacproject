extends Node

## RFC-049 049h (F297): headless check that the screens of teams and modes build without errors and show what they should. It instances
## the product scenes (boot, room view, seat list, local server host view, match result banner) and feeds them a fake 2v2 room with a
## bot seat and a team win. No network, no world. Run with `--room-test-maps` (2v2 only fits test_flat4, a test map):
##   godot --headless --path game res://debug/ui/team_screens_check.tscn -- --no-flow --room-test-maps
## Prints one PASS/FAIL line per check and TEAM SCREENS PASS / TEAM SCREENS FAIL (exit 0 / 1).

const BOOT_SCENE := preload("res://scenes/core/boot.tscn")
const ROOM_VIEW_SCENE := preload("res://scenes/ui/lobby/room_view.tscn")
const ROOM_CREATE_SCENE := preload("res://scenes/ui/lobby/room_create.tscn")
const SEAT_LIST_SCENE := preload("res://scenes/ui/lobby/seat_list.tscn")
const LOCAL_SERVER_SCENE := preload("res://scenes/ui/local_server/local_server_screen.tscn")
const LOCAL_HOST_SCENE := preload("res://scenes/ui/local_server/local_host_view.tscn")
const RESULT_SCENE := preload("res://scenes/ui/hud/match_result.tscn")
const MATCH_STATE_SCENE := preload("res://scenes/match/match_state.tscn")

## Every key the 049h screens name (a missing one would show the key itself).
const KEYS: PackedStringArray = [
	"MODE_1V1", "MODE_2V2", "MODE_FFA3", "MODE_FFA4", "UI_MODE_PICKER_ITEM", "UI_AI_GOD_RANDOM", "UI_AI_GOD_ITEM",
	"UI_AI_DIFFICULTY_ITEM", "UI_AI_DIFFICULTY_EASY", "UI_AI_DIFFICULTY_NORMAL", "UI_AI_DIFFICULTY_HARD", "UI_AI_SEAT_HUMAN",
	"UI_ROOM_VIEW_MODE", "UI_ROOM_VIEW_MAP", "UI_ROOM_VIEW_TEAM", "UI_ROOM_VIEW_BOT_OPTIONS", "UI_SEAT_ADD_BOT", "UI_SEAT_REMOVE_BOT",
	"LOBBY_BOT_NAME", "LOBBY_BOT_RANDOM_GOD", "LOBBY_BOT_FORMAT", "UI_LOCAL_SEAT_LABEL", "UI_LOCAL_SEAT_AI", "LOCAL_INFO_SEAT_CODE",
	"LOCAL_INFO_NO_CODE", "UI_RESULT_TEAM", "UI_RESULT_SLOT", "UI_RESULT_AND", "LOBBY_RESULT_TEAM_WON", "LOBBY_RESULT_TEAM_LOST",
	"LOBBY_RESULT_TEAM_WON_ABANDON", "LOBBY_RESULT_TEAM_LOST_ABANDON",
]

var _fails := 0


func _ready() -> void:
	_check_keys()
	await _check_boot()
	await _check_room_create()
	await _check_room_view()
	await _check_seat_list()
	await _check_local_server()
	await _check_result()
	print("TEAM SCREENS %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _frames(count := 2) -> void:
	for _i in count:
		await get_tree().process_frame


func _check_keys() -> void:
	var missing := PackedStringArray()
	for key in KEYS:
		if tr(key) == key:
			missing.append(key)
	for mode in GameModeCatalog.shared().modes:
		if tr(mode.display_name) == mode.display_name:
			missing.append(mode.display_name)
	_check(missing.is_empty(), "strings.csv has every key of the screens (missing: %s)" % ", ".join(missing))


func _items(picker: OptionButton) -> PackedStringArray:
	var out := PackedStringArray()
	for i in picker.item_count:
		out.append(picker.get_item_text(i))
	return out


## Selects the item whose metadata is `tag` and emits `item_selected` as a click does.
func _pick(picker: OptionButton, tag: String) -> bool:
	for i in picker.item_count:
		if str(picker.get_item_metadata(i)) == tag:
			picker.select(i)
			picker.item_selected.emit(i)
			return true
	return false


## Every item of the map picker is a map with at least `starts` starts (and there is one).
func _only_fitting(map: MapPicker, starts: int) -> bool:
	for i in map.item_count:
		var definition := MapCatalog.shared().find(StringName(str(map.get_item_metadata(i))))
		if definition == null or definition.player_starts < starts:
			return false
	return map.item_count > 0


func _lists(picker: OptionButton, tag: String) -> bool:
	for i in picker.item_count:
		if str(picker.get_item_metadata(i)) == tag:
			return true
	return false


func _check_boot() -> void:
	var boot := BOOT_SCENE.instantiate()
	add_child(boot)
	await _frames()
	var mode := boot.get_node(^"%ModePicker") as ModePicker
	var map := boot.get_node(^"%MapPicker") as MapPicker
	_check(mode != null and map != null, "boot: %ModePicker and %MapPicker exist")
	_check(_items(mode).has(tr("UI_MODE_PICKER_ITEM") % tr("MODE_2V2")), "boot: the mode picker offers «2 contra 2» (%s)" % ", ".join(_items(mode)))
	_check(mode.selected_tag() == &"1v1", "boot: the mode starts at 1v1")
	_check(_pick(mode, "2v2") and _only_fitting(map, 4) and _lists(map, "test_flat4") and not _lists(map, "high_noon"),
		"boot: with 2v2 the map picker lists only maps of 4 starts, test_flat4 among them (%s)" % ", ".join(_items(map)))
	_check(_pick(mode, "1v1") and map.item_count > 1, "boot: back to 1v1 the map picker lists every map again")
	var ai_god := boot.get_node(^"%AiGod") as AiGodPicker
	_check(ai_god.item_count == GameData.gods().size() + 1, "boot: the AI god picker has «Aleatorio» and every god")
	## 055i-a: a god that is not `offered` leaves the picker; its metadata is the GodType, and the pick text is its display_name.
	var god := GameCatalog.shared().gods[0]
	god.offered = false
	ai_god.fill()
	_check(ai_god.item_count == GameData.gods().size(), "boot: a god with offered = false is not in the AI god picker")
	god.offered = true
	ai_god.fill()
	ai_god.select(1)
	_check(ai_god.selected_god() == GameCatalog.shared().offered_gods()[0], "boot: the AI god picker carries the GodType")
	var meta := MatchWire.encode_pick(SacrificeFlow.pick)
	_check(LobbyText.pick_text(meta).contains(SacrificeFlow.pick.god.display_name), "lobby: the pick text names the god by its display_name")
	boot.queue_free()
	await _frames()


func _check_room_create() -> void:
	var view := ROOM_CREATE_SCENE.instantiate()
	add_child(view)
	await _frames()
	_check(_pick(view.get_node(^"%RoomMode") as OptionButton, "2v2"), "room create: the mode picker offers 2v2")
	var options: Dictionary = view.call(&"options")
	var world := MapCatalog.shared().find(StringName(str(options.get("world", ""))))
	_check(str(options.get("mode", "")) == "2v2" and world != null and world.player_starts >= 4,
		"room create: the options carry mode 2v2 and a map of 4 starts (%s)" % JSON.stringify(options))
	view.queue_free()
	await _frames()


func _check_room_view() -> void:
	var view := ROOM_VIEW_SCENE.instantiate()
	add_child(view)
	await _frames()
	_check((view.get_node(^"%RoomTitle") as Label).text == tr(LobbyText.OFFLINE), "room view alone says «Sin conexión»")
	_check(view.get_node(^"%Seats") is SeatList and not (view.get_node(^"%BotOptions") as Control).visible,
		"room view: %Seats is a SeatList and the bot options are hidden offline")
	view.queue_free()
	await _frames()


## A 2v2 room: me (host) in seat 1, a person in 2, a Hard bot with Pyro in 3, seat 4 free.
func _fake_room() -> Dictionary:
	return {
		"id": "r1", "state": MpLobbyRooms.State.OPEN, "options": {"mode": "2v2", "world": "test_flat4"}, "private": false,
		"countdown_left": 0.0, "last_result": {},
		"seats": [
			{"seat": 0, "free": false, "bot": false, "name": "Ana", "meta": {}, "ready": false, "connected": true, "host": true, "you": true},
			{"seat": 1, "free": false, "bot": false, "name": "Beto", "meta": {}, "ready": true, "connected": true, "host": false, "you": false},
			{"seat": 2, "free": false, "bot": true, "name": "", "meta": {"god": "pyro", "difficulty": "hard"}, "ready": true,
				"connected": true, "host": false},
			{"seat": 3, "free": true},
		],
	}


func _check_seat_list() -> void:
	var list := SEAT_LIST_SCENE.instantiate() as SeatList
	add_child(list)
	await _frames()
	var added: Array[int] = []
	list.bot_add_requested.connect(func(seat: int) -> void: added.append(seat))
	list.show_room(_fake_room(), true)
	await _frames()
	var groups := list.groups()
	_check(groups.size() == 2, "seat list: a 2v2 room shows two team groups (%d)" % groups.size())
	if groups.size() == 2:
		var first := (groups[0].get_node(^"%TeamTitle") as Label)
		var second := (groups[1].get_node(^"%TeamTitle") as Label)
		_check(first.visible and first.text == tr("UI_ROOM_VIEW_TEAM") % 1 and second.text == tr("UI_ROOM_VIEW_TEAM") % 2,
			"seat list: the groups are «%s» and «%s»" % [first.text, second.text])
		_check(groups[0].get_node(^"%TeamSeats").get_child_count() == 2 and groups[1].get_node(^"%TeamSeats").get_child_count() == 2,
			"seat list: two seats in each team")
	var bot := list.row(2)
	var bot_name := (bot.get_node(^"%SeatName") as Label).text
	var bot_pick := (bot.get_node(^"%SeatPick") as Label).text
	_check(bot_name == tr("LOBBY_BOT_NAME") and bot_pick.contains(tr("UI_AI_DIFFICULTY_HARD")) and bot_pick.contains("Pyro"),
		"seat list: the bot row says «%s · %s»" % [bot_name, bot_pick])
	_check((bot.get_node(^"%RemoveBot") as Control).visible, "seat list: the host sees «Quitar IA» on the bot seat")
	var free := list.row(3)
	_check((free.get_node(^"%AddBot") as Control).visible and (free.get_node(^"%Sit") as Control).visible,
		"seat list: the host sees «Agregar IA» and «Sentarme aquí» on the free seat")
	(free.get_node(^"%AddBot") as Button).pressed.emit()
	_check(added == [3], "seat list: «Agregar IA» asks for seat index 3 (%s)" % str(added))
	list.show_room(_fake_room(), false)
	_check(not (free.get_node(^"%AddBot") as Control).visible and not (bot.get_node(^"%RemoveBot") as Control).visible,
		"seat list: a player who is not the host sees no bot buttons")
	var one := _fake_room()
	one["options"] = {}
	one["seats"] = (one["seats"] as Array).slice(0, 2)
	list.show_room(one, true)
	_check(list.groups().size() == 1 and not (list.groups()[0].get_node(^"%TeamTitle") as Label).visible,
		"seat list: a 1v1 room shows one group with no team title")
	list.queue_free()
	await _frames()


func _check_local_server() -> void:
	var screen := LOCAL_SERVER_SCENE.instantiate()
	add_child(screen)
	await _frames()
	screen.queue_free()
	var host := LOCAL_HOST_SCENE.instantiate()
	add_child(host)
	await _frames()
	var mode := host.get_node(^"%HostMode") as ModePicker
	var seats := host.get_node(^"%HostSeats")
	_check(seats.get_child_count() == 1, "local server: a 1v1 has one seat besides the host's (%d)" % seats.get_child_count())
	_check(_pick(mode, "2v2"), "local server: the mode picker offers 2v2")
	await _frames()
	_check(seats.get_child_count() == 3 and _only_fitting(host.get_node(^"%HostMap") as MapPicker, 4),
		"local server: 2v2 shows three seats and only maps of 4 starts (%d)" % seats.get_child_count())
	var ally := seats.get_child(0) as LocalSeatRow
	_check(ally.slot == 2 and (ally.get_node(^"%SeatLabel") as Label).text == tr("UI_LOCAL_SEAT_LABEL") % [2, 1],
		"local server: seat 2 is in team 1 (%s)" % (ally.get_node(^"%SeatLabel") as Label).text)
	var choice := seats.get_child(2).get_node(^"%SeatChoice") as AiDifficultyPicker
	_check(choice.is_human() and _pick(choice, "easy"), "local server: a seat starts as a person and can be an Easy AI")
	var ai: Dictionary = (host as Object).call(&"ai_seats")
	_check(ai.size() == 1 and str((ai.get(4, {}) as Dictionary).get("difficulty", "")) == "easy", "local server: the AI seats are {4: easy} (%s)" % str(ai))
	var codes := LocalServerText.codes_text({3: "bbb", 2: "aaa"})
	_check(codes == "%s\n%s" % [tr("LOCAL_INFO_SEAT_CODE") % [2, "aaa"], tr("LOCAL_INFO_SEAT_CODE") % [3, "bbb"]],
		"local server: one code line per seat for a person, in seat order")
	_check(LocalServerText.codes_text({2: "aaa"}) == tr("LOCAL_INFO_CODE") % "aaa", "local server: one seat keeps the 1v1 line")
	host.queue_free()
	await _frames()


func _check_result() -> void:
	GameModeCatalog.use(&"2v2")
	var world := Node3D.new()
	add_child(world)
	var state := MATCH_STATE_SCENE.instantiate() as MatchState
	world.add_child(state)
	var banner := RESULT_SCENE.instantiate() as MatchResultBanner
	banner.match_state = state
	add_child(banner)
	await _frames()
	_check(banner.text_for(1).is_empty() and banner.team_text_for(1).is_empty(), "result: nothing while the match goes on")
	state.defeat_side(3)
	state.defeat_side(4)
	var winners: Array[int] = [1, 2]
	state.end_match_team(winners)
	await _frames()
	_check(banner.text_for(1) == tr("UI_RESULT_VICTORY") and banner.text_for(2) == tr("UI_RESULT_VICTORY"), "result: «Victoria» for both allies")
	_check(banner.text_for(3) == tr("UI_RESULT_DEFEAT"), "result: «Derrota» for the other team")
	var line := banner.team_text_for(1)
	_check(line.begins_with((tr("UI_RESULT_TEAM") % "").strip_edges()) and line.contains(tr("UI_RESULT_SLOT") % 2),
		"result: the team line names the winners («%s»)" % line)
	_check(banner.team_label != null and banner.team_label.name == &"TeamLine", "result: the banner has its %TeamLine")
	var lobby := LobbyText.result_text({"winner_slot": 1, "winner_slots": [1, 2], "reason": "result"}, 2)
	_check(lobby == tr("LOBBY_RESULT_TEAM_WON"), "result: the room says «%s» to the ally" % lobby)
	banner.queue_free()
	world.queue_free()
	GameModeCatalog.reset()
	await _frames()
