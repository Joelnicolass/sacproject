extends "res://addons/mp_kit/tests/mp_test.gd"

## MpSyncBuilder: the inspector list of MpActor / MpState becomes the replication config saved in the scene.


func test_paths() -> void:
	check(MpSyncBuilder.path_of("position") == NodePath(".:position"), "a root property gets .:")
	check(MpSyncBuilder.path_of("Health:current") == NodePath("Health:current"), "a child property stays as is")


func test_modes() -> void:
	var cfg := MpSyncBuilder.build(PackedStringArray(["position", "Health:current"]), PackedStringArray(["MpActor:owner_slot"]))
	check(cfg.get_properties().size() == 3, "three properties")
	check(cfg.property_get_replication_mode(^".:position") == SceneReplicationConfig.REPLICATION_MODE_ALWAYS, "a transform is sent every interval")
	check(cfg.property_get_replication_mode(^"Health:current") == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE, "anything else on change")
	check(cfg.property_get_replication_mode(^"MpActor:owner_slot") == SceneReplicationConfig.REPLICATION_MODE_NEVER, "spawn-only is never resent")
	for path in cfg.get_properties():
		check(cfg.property_get_spawn(path), "%s is in the spawn packet" % path)


func test_matches_and_duplicates() -> void:
	var entries := PackedStringArray(["position", "position", " "])
	var cfg := MpSyncBuilder.build(entries)
	check(cfg.get_properties().size() == 1, "duplicates and blanks are dropped")
	check(MpSyncBuilder.matches(cfg, entries), "a config matches the list it came from")
	check(not MpSyncBuilder.matches(cfg, PackedStringArray(["position", "rotation"])), "a new entry is a difference")
	check(not MpSyncBuilder.matches(null, entries), "no config is a difference")


func test_ensure_builds_once() -> void:
	var holder := Node.new()
	var sync := MpSyncBuilder.ensure(holder, "MpSync", ^"../..", PackedStringArray(["position"]), PackedStringArray(), null)
	var cfg := sync.replication_config
	var again := MpSyncBuilder.ensure(holder, "MpSync", ^"../..", PackedStringArray(["position"]), PackedStringArray(), null)
	check(again == sync and again.replication_config == cfg, "an unchanged list keeps the same synchronizer and config")
	check(sync.root_path == NodePath("../.."), "root_path points at the shared node")
	holder.free()
