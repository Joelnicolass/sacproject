class_name Mp
extends Object

## The short way: the verbs a multiplayer game needs, from any script, with no node to find first.
##   Mp.play_solo()  Mp.host()  Mp.join("192.168.1.5")  Mp.join("1.2.3.4:7777#CODE")  Mp.leave()  Mp.open_rooms()
##   if Mp.is_server(): …     Mp.me()     Mp.state().add(&"score")     Mp.finish({"winner": Mp.me()})
## Every call goes to the nodes that do the work (MpFlow, MpKit, MpWorld, MpState, MpMatch, MpMatchGate); use them directly for
## the rest. Not: the actor's own calls (MpActor: is_local, to_server, to_all), which belong to each actor.


## Plays alone, with no network: the same world and rules, this player is slot 1.
static func play_solo() -> void:
	var flow := _flow("play_solo")
	if flow:
		flow.play_solo()


## Hosts a match on this PC (LAN, or the relay when the game says so); this player plays too.
static func host() -> Error:
	var flow := _flow("host")
	return flow.host_lan() if flow else ERR_UNCONFIGURED


## Joins a server: "192.168.1.5", "game.example.com:7777", "ip:port#CODE" (a private match), or a "wss://…" URL.
static func join(address: String) -> Error:
	var flow := _flow("join")
	return flow.join_address(address) if flow else ERR_UNCONFIGURED


## Leaves the match: back to the lobby for an online match, to the boot scene otherwise. Same as the Leave button.
static func leave() -> void:
	var flow := _flow("leave")
	if flow:
		flow.leave_match()


## Opens the online lobby (MpGame.lobby_scene). False when the game has none.
static func open_rooms() -> bool:
	var flow := _flow("open_rooms")
	if flow == null or flow.lobby_path.is_empty():
		push_warning("Mp.open_rooms(): the game has no lobby scene (MpGame › Scenes › Lobby Scene)")
		return false
	flow.get_tree().change_scene_to_file(flow.lobby_path)
	return true


## True where the rules run: the server, or this PC when playing solo. Score, damage, spawning: only here.
static func is_server() -> bool:
	return MpKit.is_authority()


## True in a networked match (host, dedicated or client); false solo and in the menu.
static func is_online() -> bool:
	return MpKit.is_networked()


## How the connection is doing: {rtt_ms, jitter_ms, loss (0..1), grade (MpNetQuality.Grade), grade_name ("good",
## "fair", "bad")}. On a client, its link to the server; on the server, the player of `slot` (empty until it pinged).
static func net_quality(slot: int = 0) -> Dictionary:
	if MpKit.net_quality == null:
		return {}
	if slot > 0 and MpKit.is_server():
		return MpKit.net_quality.of_slot(slot)
	return MpKit.net_quality.snapshot()


## This player's seat: 1, 2, 3… (0 on a dedicated server, which plays no seat, and before a seat is given).
static func me() -> int:
	return MpKit.local_slot()


## The world's shared values (score, timer, round): `Mp.state().add(&"score")` on the server, `get_value` anywhere.
static func state() -> MpState:
	var tree := _tree()
	return MpState.of(tree.root) if tree else null


## The world's MpMatch (seats, waiting, player_joined, player_left…), or null outside a match.
static func current_match() -> MpMatch:
	var tree := _tree()
	if tree == null:
		return null
	var world := MpWorld.of(tree.root)
	if world:
		return world.current_match() as MpMatch
	var scene := tree.current_scene
	if scene == null:
		return null
	var found := scene.find_children("*", "Node", true, false).filter(func(n: Node) -> bool: return n is MpMatch)
	return found[0] as MpMatch if not found.is_empty() else null


## The start gate of the match (who may sit, the wait for every seat, the rejoin grace): `Mp.gate().is_waiting()`,
## `Mp.gate().can_start_now()`, its signals. Every peer has one; the server's decides.
static func gate() -> MpMatchGate:
	return MpKit.gate


## Server (or solo): ends the match for everyone with `result` (MpMatch.finish).
static func finish(result: Dictionary = {}) -> void:
	var match_node := current_match()
	if match_node == null:
		push_warning("Mp.finish(): no MpMatch in this scene (an MpWorld has one)")
		return
	match_node.finish(result)


## The player of `slot` on this peer (null until it spawned here). `Mp.player(Mp.me())` is your own.
static func player(slot: int) -> Node:
	var tree := _tree()
	var world := MpWorld.of(tree.root) if tree else null
	return world.player(slot) if world else null


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _flow(verb: String) -> MpFlow:
	var tree := _tree()
	var flow := MpFlow.find_in_tree(tree.root) if tree else null
	if flow == null:
		push_error("Mp.%s(): no MpFlow (put one in the boot scene, or run the MpKit › Setup game wizard)" % verb)
	return flow
