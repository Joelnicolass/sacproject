@tool
class_name MpWorld
extends Node

## The match in one node. Add it to your world scene and set Player Scene: in the editor it builds what a networked
## world needs, as its own children you can see and move:
##   SpawnPoints  one marker per seat (move them where players start)
##   Actors       where the players (and anything a spawner makes) live
##   Players      MpSlotSpawner: one player per seat, on every peer, late joiners included
##   State        MpState: score, timer, round (`Mp.state()`)
##   Match        MpMatch: waits for every seat, players leaving and coming back, finish (`Mp.finish()`)
##   Hud/Leave    MpLeaveButton (turn off Leave Button to skip it)
##   Hud/Invite   MpInviteLabel: in a private match of this PC, what friends type to join
## A piece you delete is built again next time the scene opens; a piece you rename is not found (keep the names).
## Not: your level (put it next to this node), your player (a scene with MpActor + MpInput, see the Setup game wizard).

const GROUP := &"mp_world"
## By path, untyped: this @tool script also loads where the MpKit autoload does not exist (the wizard, the editor
## before the plugin is on), and those nodes name MpKit.
const SLOT_SPAWNER := "res://addons/mp_kit/mp_slot_spawner.gd"
const STATE := "res://addons/mp_kit/nodes/mp_state.gd"
const MATCH := "res://addons/mp_kit/nodes/mp_match.gd"
const LEAVE := "res://addons/mp_kit/nodes/mp_leave_button.gd"
const INVITE := "res://addons/mp_kit/nodes/mp_invite_label.gd"
const PIECES := ["SpawnPoints", "Actors", "Players", "State", "Match"]

## The scene every seat gets (it needs an MpActor). Same as Players › Pawn Scene.
@export var player_scene: PackedScene:
	set(next):
		player_scene = next
		var spawner := get_node_or_null("Players")
		if spawner and spawner.get("pawn_scene") != next:
			spawner.set("pawn_scene", next)
## Spawn points made when the pieces are built (more seats reuse them in turn).
@export_range(1, 64) var seats: int = 4
## Build a Hud with a Leave button.
@export var leave_button: bool = true
## Build the Hud's invite line for private matches (MpInviteLabel).
@export var invite_label: bool = true


## The MpWorld of the current scene, or null.
static func of(from: Node) -> MpWorld:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP) as MpWorld


## Builds every missing piece under `world` (owned by `scene_root`, so it is saved with the scene).
## The editor calls it when the node is added; the Setup game wizard calls it while writing the world scene.
static func build(world: MpWorld, scene_root: Node, is_3d: bool) -> void:
	var points := world.get_node_or_null("SpawnPoints")
	if points == null:
		points = Node3D.new() if is_3d else Node2D.new()
		points.name = "SpawnPoints"
		_own(world, points, scene_root)
		for i in world.seats:
			var angle := TAU * i / world.seats
			var marker: Node = Marker3D.new() if is_3d else Marker2D.new()
			marker.name = "P%d" % (i + 1)
			if is_3d:
				(marker as Node3D).position = Vector3(cos(angle), 0, sin(angle)) * 4.0
			else:
				(marker as Node2D).position = Vector2(480, 270) + Vector2(cos(angle), sin(angle)) * 180.0
			_own(points, marker, scene_root)
	if world.get_node_or_null("Actors") == null:
		var actors: Node = Node3D.new() if is_3d else Node2D.new()
		actors.name = "Actors"
		_own(world, actors, scene_root)
	if world.get_node_or_null("Players") == null:
		var spawner := MultiplayerSpawner.new()
		spawner.set_script(load(SLOT_SPAWNER))
		spawner.name = "Players"
		spawner.spawn_path = ^"../Actors"
		spawner.set("spawn_points", ^"../SpawnPoints")
		spawner.set("pawn_scene", world.player_scene)
		_own(world, spawner, scene_root)
	if world.get_node_or_null("State") == null:
		var state: Node = load(STATE).new()
		state.name = "State"
		_own(world, state, scene_root)
		MpSyncBuilder.ensure(state, "MpSync", ^"..", PackedStringArray(["values"]), PackedStringArray(), scene_root)
	if world.get_node_or_null("Match") == null:
		## A base node plus set_script, never Script.new(): in the editor a non-tool script must stay a placeholder
		## (its _ready would run there and talk to the network).
		var match_node := Node.new()
		match_node.set_script(load(MATCH))
		match_node.name = "Match"
		_own(world, match_node, scene_root)
	var hud := world.get_node_or_null("Hud")
	if hud == null and (world.leave_button or world.invite_label):
		hud = CanvasLayer.new()
		hud.name = "Hud"
		_own(world, hud, scene_root)
	if world.leave_button and hud.get_node_or_null("Leave") == null:
		var leave := Button.new()
		leave.set_script(load(LEAVE))
		leave.name = "Leave"
		leave.position = Vector2(16, 16)
		_own(hud, leave, scene_root)
	if world.invite_label and hud.get_node_or_null("Invite") == null:
		var invite := Label.new()
		invite.set_script(load(INVITE))
		invite.name = "Invite"
		invite.position = Vector2(16, 56)
		_own(hud, invite, scene_root)


static func _own(parent: Node, child: Node, scene_root: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root


func _enter_tree() -> void:
	add_to_group(GROUP)
	if Engine.is_editor_hint():
		_build_in_editor.call_deferred()
		return
	## Before the spawner's _ready (children are ready first): it spawns at once in solo.
	var spawner := get_node_or_null("Players")
	if spawner and player_scene and spawner.get("pawn_scene") == null:
		spawner.set("pawn_scene", player_scene)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for piece in PIECES:
		if get_node_or_null(piece) == null:
			push_error("MpWorld '%s': no %s child. Open the scene in the editor and save it (the editor builds it)." % [name, piece])


## The world's shared values (its MpState: score, timer…). Typed: `Mp.state()`.
func state() -> Node:
	return get_node_or_null("State")


## The match (its MpMatch): finish(result), seats(), waiting, and its signals. Typed: `Mp.current_match()`.
func current_match() -> Node:
	return get_node_or_null("Match")


## The player of `slot` on this peer (null until it spawned here).
func player(slot: int) -> Node:
	var spawner := get_node_or_null("Players")
	return spawner.call(&"pawn_for", slot) if spawner else null


## Where actors live (spawn_path of the spawners).
func actors() -> Node:
	return get_node_or_null("Actors")


func _build_in_editor() -> void:
	var scene := get_tree().edited_scene_root if is_inside_tree() else null
	if scene == null or (owner != scene and self != scene):
		return
	MpWorld.build(self, scene, _in_3d())
	update_configuration_warnings()


## A 3D world when the nearest spatial ancestor is a Node3D.
func _in_3d() -> bool:
	var node := get_parent()
	while node:
		if node is Node3D:
			return true
		if node is CanvasItem:
			return false
		node = node.get_parent()
	return false


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if player_scene == null:
		out.append("Set Player Scene: the scene every seat gets (it needs an MpActor).")
	return out
