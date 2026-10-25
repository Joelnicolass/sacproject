@tool
class_name MpSyncBuilder
extends RefCounted

## Turns the list a human ticks in the inspector into a SceneReplicationConfig. No nodes, no network:
## the same function runs in the editor (to save the synchronizer in the .tscn) and in the tests.
## Not: deciding what to sync (MpActor / MpState own that list) or showing it to peers (MpSpawner).
##
## An entry is a property of the synchronizer's root ("position") or of a node under it ("Health:current").
## Every entry is sent when the node spawns. Transforms (and MpActor's stamp / MpInput's ack, which must travel in
## the same packet as them) are sent every interval (ALWAYS); anything else
## only when it changes (ON_CHANGE, reliable). `spawn_only` entries are sent once at spawn (NEVER).

const ALWAYS_PROPS: PackedStringArray = [
	"position", "rotation", "rotation_degrees", "scale", "transform", "quaternion", "basis",
	"global_position", "global_rotation", "global_transform", "velocity", "linear_velocity", "angular_velocity",
	"net_stamp", "net_position", "net_rotation", "acked_seq",
]


## The NodePath of one inspector entry: "position" -> ".:position"; "Health:current" stays as is.
static func path_of(entry: String) -> NodePath:
	var clean := entry.strip_edges()
	if clean.contains(":"):
		return NodePath(clean)
	return NodePath(".:" + clean)


static func mode_of(entry: String) -> int:
	var prop := entry.strip_edges().get_slice(":", entry.count(":"))
	if ALWAYS_PROPS.has(prop):
		return SceneReplicationConfig.REPLICATION_MODE_ALWAYS
	return SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE


static func build(entries: PackedStringArray, spawn_only: PackedStringArray = PackedStringArray()) -> SceneReplicationConfig:
	var cfg := SceneReplicationConfig.new()
	for entry in entries:
		if entry.strip_edges().is_empty():
			continue
		var path := path_of(entry)
		if cfg.has_property(path):
			continue
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, mode_of(entry))
	for entry in spawn_only:
		var path := path_of(entry)
		if cfg.has_property(path):
			continue
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_NEVER)
	return cfg


## True when `cfg` already holds exactly what `build` would make (the editor rebuilds only on a difference).
static func matches(cfg: SceneReplicationConfig, entries: PackedStringArray, spawn_only: PackedStringArray = PackedStringArray()) -> bool:
	if cfg == null:
		return false
	var want := build(entries, spawn_only)
	var have := cfg.get_properties()
	if have.size() != want.get_properties().size():
		return false
	for path in want.get_properties():
		if not have.has(path):
			return false
		if cfg.property_get_spawn(path) != want.property_get_spawn(path):
			return false
		if cfg.property_get_replication_mode(path) != want.property_get_replication_mode(path):
			return false
	return true


## The synchronizer child named `sync_name` of `holder`, created (and owned by `scene_owner`, so it is saved) when
## missing, with `root_path` pointing at the node whose properties it sends. Returns it updated.
static func ensure(holder: Node, sync_name: String, root_path: NodePath, entries: PackedStringArray,
		spawn_only: PackedStringArray, scene_owner: Node) -> MultiplayerSynchronizer:
	var sync := holder.get_node_or_null(sync_name) as MultiplayerSynchronizer
	if sync == null:
		sync = MultiplayerSynchronizer.new()
		sync.name = sync_name
		holder.add_child(sync)
		if scene_owner:
			sync.owner = scene_owner
	if sync.root_path != root_path:
		sync.root_path = root_path
	if not matches(sync.replication_config, entries, spawn_only):
		sync.replication_config = build(entries, spawn_only)
	return sync
