@tool
class_name MpActorSync
extends RefCounted

## What an MpActor's synchronizer sends, from its inspector, and building it in the editor. The pose travels in
## MpActor.net_position / net_rotation (with the stamp) when smoothing or predicting, so on a client only MpActor
## writes the parent's pose; with prediction MpInput's ack rides in the same packet. Not: sending (Godot does).


static func entries(actor: MpActor) -> PackedStringArray:
	var out := PackedStringArray()
	var parent := actor.get_parent()
	var me := String(parent.get_path_to(actor)) if parent else "MpActor"
	var held := actor.uses_net_pose()
	if actor.sync_position:
		out.append(me + ":net_position" if held else "position")
	if actor.sync_rotation:
		out.append(me + ":net_rotation" if held else "rotation")
	if actor.sync_visible:
		out.append("visible")
	out.append_array(actor.sync_extra)
	if out.is_empty():
		return out
	if held:
		out.append(me + ":net_stamp")
		out.append(me + ":net_teleports")
	var mp_input := actor.input() if parent else null
	if actor.predict and mp_input:
		out.append(String(parent.get_path_to(mp_input)) + ":acked_seq")
	return out


## Sent once, when the node spawns: the owning slot.
static func spawn_only(actor: MpActor) -> PackedStringArray:
	return PackedStringArray([String(actor.get_parent().get_path_to(actor)) + ":owner_slot"])


## Editor: create or update the MpSync child so the scene saves it. Only in the scene that owns the actor.
static func rebuild(actor: MpActor) -> void:
	if not actor.is_inside_tree():
		return
	var scene := actor.get_tree().edited_scene_root
	if scene == null or actor.owner != scene or actor.get_parent() == null:
		return
	var sync := MpSyncBuilder.ensure(actor, MpActor.SYNC_NAME, NodePath("../.."), entries(actor), spawn_only(actor), scene)
	sync.replication_interval = 1.0 / actor.send_hz if actor.send_hz > 0 else 0.0
	actor.update_configuration_warnings()
