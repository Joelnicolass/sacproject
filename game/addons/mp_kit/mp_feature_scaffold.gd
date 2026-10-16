@tool
class_name MpFeatureScaffold
extends RefCounted

## Writes a replicated feature folder: script + packed scene. No gameplay.


static func sanitize_id(raw: String) -> String:
	var snake := raw.strip_edges().to_snake_case()
	var out := ""
	for i in snake.length():
		var ch := snake[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			out += ch
	return out.trim_prefix("_")


static func script_text(base_class: String, _feature_id: String, with_pipe: bool) -> String:
	var ready_body := "	pass\n"
	var pipe_fn := ""
	if with_pipe:
		ready_body = """	if has_node("MpCustomPipe"):
		$MpCustomPipe.packet.connect(_on_custom_packet)
"""
		pipe_fn = """

func send_manual(data: Dictionary) -> void:
	if has_node("MpCustomPipe"):
		$MpCustomPipe.send(data)


func _on_custom_packet(data: Dictionary, from_peer: int) -> void:
	pass
"""
	return """extends %s

## Replicated feature. Fill apply_action. LAN and dedicated use this same script.

@export var player_slot: int = 0


func _ready() -> void:
%s
func try_action(payload: Dictionary) -> void:
	if MpAuthority.should_send_command():
		submit_action.rpc_id(1, payload)
	else:
		apply_action(payload)


@rpc("any_peer", "call_remote", "reliable")
func submit_action(payload: Dictionary) -> void:
	if not MpAuthority.accept_command(self, player_slot):
		return
	apply_action(payload)


func apply_action(payload: Dictionary) -> void:
	pass
%s
""" % [base_class, ready_body, pipe_fn]


static func write_feature(
	res_dir: String,
	feature_id: String,
	base_class: String,
	with_pipe: bool
) -> Error:
	var id := sanitize_id(feature_id)
	if id.is_empty():
		return ERR_INVALID_PARAMETER
	var dir := res_dir
	if not dir.begins_with("res://"):
		dir = "res://".path_join(dir)
	var abs_dir := ProjectSettings.globalize_path(dir)
	if not DirAccess.dir_exists_absolute(abs_dir):
		var mk := DirAccess.make_dir_recursive_absolute(abs_dir)
		if mk != OK:
			return mk
	var gd_path := dir.path_join("%s.gd" % id)
	var tscn_path := dir.path_join("%s.tscn" % id)
	var file := FileAccess.open(gd_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(script_text(base_class, id, with_pipe))
	file.close()
	var packed := _pack_scene(id, base_class, gd_path, with_pipe)
	if packed == null:
		return ERR_CANT_CREATE
	return ResourceSaver.save(packed, tscn_path)


static func _pack_scene(
	id: String,
	base_class: String,
	gd_path: String,
	with_pipe: bool
) -> PackedScene:
	var root: Node = ClassDB.instantiate(base_class) as Node
	if root == null:
		return null
	root.name = id.to_pascal_case()
	var script := load(gd_path)
	if script:
		root.set_script(script)
	var replicate := Node.new()
	replicate.name = "MpReplicate"
	replicate.set_script(load("res://addons/mp_kit/mp_replicate.gd"))
	root.add_child(replicate)
	replicate.owner = root
	var sync := MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	var cfg := SceneReplicationConfig.new()
	if base_class.begins_with("CharacterBody") or base_class.begins_with("Node2") or base_class.begins_with("Node3"):
		cfg.add_property(NodePath(".:position"))
		cfg.add_property(NodePath(".:rotation"))
		cfg.add_property(NodePath(".:visible"))
	sync.replication_config = cfg
	root.add_child(sync)
	sync.owner = root
	if with_pipe:
		var pipe := Node.new()
		pipe.name = "MpCustomPipe"
		pipe.set_script(load("res://addons/mp_kit/mp_custom_pipe.gd"))
		root.add_child(pipe)
		pipe.owner = root
		pipe.set("channel", StringName(id))
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		root.free()
		return null
	root.free()
	return packed


static func write_flow(
	tscn_path: String,
	boot_path: String,
	world_path: String,
	start_when: int = 1
) -> Error:
	var tscn := tscn_path
	if not tscn.begins_with("res://"):
		tscn = "res://".path_join(tscn)
	var gd_path := tscn.get_basename() + ".gd"
	var abs_dir := ProjectSettings.globalize_path(tscn.get_base_dir())
	if not DirAccess.dir_exists_absolute(abs_dir):
		var mk := DirAccess.make_dir_recursive_absolute(abs_dir)
		if mk != OK:
			return mk
	var gd := FileAccess.open(gd_path, FileAccess.WRITE)
	if gd == null:
		return FileAccess.get_open_error()
	gd.store_string("""extends MpFlow

## Session flow autoload. Assign boot/world in the inspector.
## Override snapshot_for_joiner() if late joiners need game state.


func snapshot_for_joiner() -> Dictionary:
	return {}
""")
	gd.close()
	var boot := boot_path.strip_edges()
	var world := world_path.strip_edges()
	var scene := FileAccess.open(tscn, FileAccess.WRITE)
	if scene == null:
		return FileAccess.get_open_error()
	scene.store_string(
		"""[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="%s" id="1"]

[node name="MpFlow" type="Node"]
script = ExtResource("1")
boot_path = "%s"
world_path = "%s"
start_when = %d
"""
		% [gd_path, boot, world, start_when]
	)
	scene.close()
	return OK
