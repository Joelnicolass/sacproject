class_name MpInviteLabel
extends Label

## Put one in the match HUD (the MpWorld's Hud has one). When this PC runs a private match (the menu's
## "Private server", MpLocalServer), it shows what friends type in the Join field: "192.168.1.5:7801#K7P2QX".
## Hidden everywhere else (a LAN host, a client, an online match). Not: the codes themselves (MpLocalServer.codes).

## `%s` is the invite (one per free seat, separated by commas).
@export var text_format: String = "Friends join with %s"

const CHECK_S := 0.25
## By group, untyped: this node must not load the rooms scripts (MpLocalServer.GROUP).
const SERVER_GROUP := &"mp_local_server"

var _since: float = CHECK_S


func _ready() -> void:
	## Shown while the world waits for the friends (MpMatch pauses the tree).
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(delta: float) -> void:
	_since += delta
	if _since < CHECK_S:
		return
	_since = 0.0
	var server: Node = null
	for node in get_tree().get_nodes_in_group(SERVER_GROUP):
		if not node.is_queued_for_deletion():
			server = node
	var invite: String = server.call(&"invite_text") if server and server.call(&"is_ready") else ""
	visible = not invite.is_empty()
	if visible:
		text = text_format % invite
