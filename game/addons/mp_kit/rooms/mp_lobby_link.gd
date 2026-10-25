class_name MpLobbyLink
extends RefCounted

## The lobby stack (/root/MpLobby: Server + Client with their own SceneMultiplayer). A project may register it as an
## autoload; if not, the first room node that needs it creates it at the same path, which every peer must share.
## Not: the protocol (MpLobbyServer / MpLobbyClient).

const PATH := "MpLobby"
const SCRIPT := "res://addons/mp_kit/lobby/mp_lobby.gd"


static func of(tree: SceneTree) -> Node:
	var node := tree.root.get_node_or_null(PATH)
	if node:
		return node
	node = (load(SCRIPT) as GDScript).new()
	node.name = PATH
	tree.root.add_child(node)
	return node


static func client(tree: SceneTree) -> MpLobbyClient:
	return of(tree).client as MpLobbyClient


static func server(tree: SceneTree) -> MpLobbyServer:
	return of(tree).server as MpLobbyServer
