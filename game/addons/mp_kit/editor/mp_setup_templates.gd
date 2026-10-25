@tool
class_name MpSetupTemplates
extends RefCounted

## The scenes MpSetupWizard writes, built as plain nodes (then packed): what a person would build by hand following
## QUICKSTART.md. Not: writing files (MpSetupWizard).

const FLOW := "res://addons/mp_kit/mp_flow.gd"
const MENU := "res://addons/mp_kit/mp_boot_menu.tscn"
const LOBBY_SCREEN := "res://addons/mp_kit/rooms/ui/mp_lobby_screen.tscn"
const ROOM_SERVER := "res://addons/mp_kit/rooms/mp_room_server.gd"
const ACTOR := "res://addons/mp_kit/nodes/mp_actor.gd"
const INPUT := "res://addons/mp_kit/nodes/mp_input.gd"
const STATE := "res://addons/mp_kit/nodes/mp_state.gd"
const MATCH := "res://addons/mp_kit/nodes/mp_match.gd"
const SLOT_SPAWNER := "res://addons/mp_kit/mp_slot_spawner.gd"


static func player_script(is_3d: bool) -> String:
	var base := "CharacterBody3D" if is_3d else "CharacterBody2D"
	var speed := "5.0" if is_3d else "220.0"
	var move := "Vector3(dir.x, 0.0, dir.y) * SPEED" if is_3d else "dir * SPEED"
	return """extends %s

## Your player. Movement goes in mp_move: the server runs it and, with MpActor > Prediction on, the owner runs it at
## once too (no lag). The rules go in _physics_process behind net.is_authority().
## Calls by name: net.to_server(&"x") runs mp_sv_x on the server; net.to_all(&"x") runs mp_all_x everywhere.

const SPEED := %s

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput


func mp_move(keys: MpInput, _delta: float) -> void:
	var dir := keys.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	velocity = %s
	move_and_slide()


func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	if input.is_action_just_pressed(&"ui_accept"):
		MpState.of(self).add(StringName("p%%d" %% net.owner_slot))
		net.to_all(&"flash")


func mp_all_flash() -> void:
	$Visual.scale = Vector%s(1.4, 1.4%s)
	create_tween().tween_property($Visual, "scale", Vector%s(1, 1%s), 0.2)
""" % [base, speed, move, "3" if is_3d else "2", ", 1.4" if is_3d else "", "3" if is_3d else "2", ", 1" if is_3d else ""]


static func player(is_3d: bool, script: Script) -> Node:
	var root: Node = CharacterBody3D.new() if is_3d else CharacterBody2D.new()
	root.name = "Player"
	root.set("motion_mode", 1)
	root.set_script(script)
	if is_3d:
		var mesh := MeshInstance3D.new()
		mesh.name = "Visual"
		mesh.mesh = CapsuleMesh.new()
		_add(root, mesh)
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		shape.shape = CapsuleShape3D.new()
		_add(root, shape)
	else:
		var body := Polygon2D.new()
		body.name = "Visual"
		body.polygon = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
		_add(root, body)
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, 32)
		shape.shape = rect
		_add(root, shape)
	var actor: Node = load(ACTOR).new()
	actor.name = "MpActor"
	actor.set("predict", true)
	actor.set("sync_rotation", is_3d)
	_add(root, actor)
	var mp_input: Node = load(INPUT).new()
	mp_input.name = "MpInput"
	_add(root, mp_input)
	var spawn_only := PackedStringArray(["MpActor:owner_slot"])
	MpSyncBuilder.ensure(actor, "MpSync", ^"../..", MpActorSync.entries(actor), spawn_only, root)
	return root


static func world(is_3d: bool, players: int, player_scene: PackedScene) -> Node:
	var root: Node = Node3D.new() if is_3d else Node2D.new()
	root.name = "World"
	if is_3d:
		var camera := Camera3D.new()
		camera.name = "Camera"
		camera.position = Vector3(0, 12, 12)
		camera.rotation_degrees = Vector3(-45, 0, 0)
		_add(root, camera)
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		sun.rotation_degrees = Vector3(-60, 30, 0)
		_add(root, sun)
	var points: Node = Node3D.new() if is_3d else Node2D.new()
	points.name = "SpawnPoints"
	_add(root, points)
	for i in players:
		var angle := TAU * i / players
		var marker: Node = Marker3D.new() if is_3d else Marker2D.new()
		marker.name = "P%d" % (i + 1)
		if is_3d:
			(marker as Node3D).position = Vector3(cos(angle), 0, sin(angle)) * 4.0
		else:
			(marker as Node2D).position = Vector2(480, 270) + Vector2(cos(angle), sin(angle)) * 180.0
		_add(points, marker)
	var actors: Node = Node3D.new() if is_3d else Node2D.new()
	actors.name = "Actors"
	_add(root, actors)
	var spawner := MultiplayerSpawner.new()
	spawner.name = "Players"
	spawner.set_script(load(SLOT_SPAWNER))
	spawner.spawn_path = ^"../Actors"
	spawner.set("pawn_scene", player_scene)
	spawner.set("spawn_points", ^"../SpawnPoints")
	_add(root, spawner)
	var state: Node = load(STATE).new()
	state.name = "Score"
	_add(root, state)
	MpSyncBuilder.ensure(state, "MpSync", ^"..", PackedStringArray(["values"]), PackedStringArray(), root)
	var match_node: Node = load(MATCH).new()
	match_node.name = "Match"
	_add(root, match_node)
	return root


static func boot(net: Resource, paths: Dictionary, private_server: bool) -> Node:
	var root := Control.new()
	root.name = "Boot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var flow: Node = load(FLOW).new()
	flow.name = "Flow"
	flow.set("net_config", net)
	flow.set("boot_path", paths["boot"])
	flow.set("world_path", paths["world"])
	flow.set("lobby_path", paths["lobby"])
	flow.set("room_server_path", paths["rooms"])
	flow.set("start_when", 1)
	_add(root, flow)
	var menu: Node = (load(MENU) as PackedScene).instantiate()
	menu.name = "Menu"
	menu.set("lobby_scene_path", paths["lobby"])
	menu.set("offer_private_server", private_server)
	_add(root, menu)
	return root


static func lobby(back_path: String) -> Node:
	var root: Node = (load(LOBBY_SCREEN) as PackedScene).instantiate()
	root.name = "Lobby"
	root.set("back_path", back_path)
	return root


static func room_server(config: Resource) -> Node:
	var root := Node.new()
	root.name = "Rooms"
	root.set_script(load(ROOM_SERVER))
	root.set("config", config)
	return root


static func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var top := parent
	while top.owner:
		top = top.owner
	child.owner = top if parent.owner else parent
