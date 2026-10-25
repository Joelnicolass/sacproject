extends SceneTree
## 055s s0 (disposable), question 1: does an InstancePlaceholder keep the look out of memory, and what does the editor see?
## Needs s0_fixtures.gd first. One mode per process (the resource cache must start empty), given after `--`:
##   placeholder  load the body with the placeholder, instantiate it (runtime state), then create_instance() on it
##   plain        control: the same body without the placeholder (the look loads with the scene)
##   editstate    instantiate with the editor edit states (MAIN, INSTANCE): is the placeholder replaced by the real scene?
##   spawner      the body under the node a MultiplayerSpawner watches, create_instance() there (late join is NOT covered)
## Prints `S0 1 <mode> ...` and `S0 VERDICT placeholder <mode> ...`. Always ends in quit().

const DIR := "res://debug/bodies/s0/tmp/"
const LOOK_PATHS: PackedStringArray = ["look.tscn", "look_mesh.res", "look_sound.res"]

var _mode := "placeholder"


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("S0 VERDICT placeholder %s TIMEOUT" % _mode)
		quit(2))
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	## create_instance() needs the tree running: in _initialize the root is not inside the tree yet.
	await process_frame
	quit(_main())


func _cached() -> String:
	var parts := PackedStringArray()
	for p in LOOK_PATHS:
		parts.append("%s=%s" % [p, ResourceLoader.has_cached(DIR + p)])
	return " ".join(parts)


func _any_cached() -> bool:
	for p in LOOK_PATHS:
		if ResourceLoader.has_cached(DIR + p):
			return true
	return false


func _res_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))


func _main() -> int:
	var body_path := DIR + ("body_plain.tscn" if _mode == "plain" else "body_placeholder.tscn")
	if not FileAccess.file_exists(body_path):
		print("S0 VERDICT placeholder %s ERROR fixtures missing (run s0_fixtures.gd first)" % _mode)
		return 1
	print("S0 1 %s before load: %s resources=%d" % [_mode, _cached(), _res_count()])
	var before := _res_count()
	var ps := ResourceLoader.load(body_path) as PackedScene
	if ps == null:
		print("S0 VERDICT placeholder %s ERROR load failed" % _mode)
		return 1
	print("S0 1 %s after load(PackedScene): %s resources=%d (+%d)" % [_mode, _cached(), _res_count(), _res_count() - before])
	print("S0 1 %s dependencies of the body scene: %s" % [_mode, str(ResourceLoader.get_dependencies(body_path))])
	match _mode:
		"plain":
			var ok := _any_cached()
			print("S0 VERDICT placeholder plain control: look loaded with the scene=%s (expected true, else the measure is blind)" % ok)
			return 0 if ok else 1
		"editstate":
			return _edit_states(ps)
		"spawner":
			return _spawner(ps)
	return _runtime(ps, before)


func _runtime(ps: PackedScene, before: int) -> int:
	var body := ps.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var look := body.get_node_or_null("Look")
	var cls := look.get_class() if look != null else "<missing>"
	print("S0 1 placeholder instantiate(DISABLED): Look is %s, kids of Body=%d, %s resources=%d (+%d)" % [cls, body.get_child_count(), _cached(), _res_count(), _res_count() - before])
	var not_loaded := not _any_cached()
	if look is InstancePlaceholder:
		print("S0 1 placeholder get_instance_path=%s" % (look as InstancePlaceholder).get_instance_path())
	root.add_child(body)
	var mid := _res_count()
	var made: Node = null
	if look is InstancePlaceholder:
		made = (look as InstancePlaceholder).create_instance(true)
	var made_cls := made.get_class() if made != null else "<null>"
	var kids := made.get_child_count() if made != null else -1
	var made_name := str(made.name) if made != null else "<null>"
	var made_parent := str(made.get_parent().name) if made != null and made.get_parent() != null else "<none>"
	print("S0 1 placeholder create_instance(replace=true): %s name=%s kids=%d parent=%s, %s resources=%d (+%d)" % [made_cls, made_name, kids, made_parent, _cached(), _res_count(), _res_count() - mid])
	var loaded_after := _any_cached()
	var swapped := made != null and body.get_node_or_null("Look") == made and kids == 2
	print("S0 VERDICT placeholder runtime: look NOT loaded by load+instantiate=%s; create_instance loads it=%s; replaced in place=%s" % [not_loaded, loaded_after, swapped])
	body.free()
	return 0 if (not_loaded and loaded_after and swapped) else 1


func _edit_states(ps: PackedScene) -> int:
	var real_all := true
	for st: int in [PackedScene.GEN_EDIT_STATE_MAIN, PackedScene.GEN_EDIT_STATE_INSTANCE]:
		var body := ps.instantiate(st)
		var look := body.get_node_or_null("Look")
		var kids := look.get_child_count() if look != null else -1
		print("S0 1 editstate state=%d: Look is %s, kids=%d, %s" % [st, look.get_class() if look != null else "<missing>", kids, _cached()])
		if look is InstancePlaceholder or kids != 2:
			real_all = false
		body.free()
	print("S0 VERDICT placeholder editstate: the editor edit states give the REAL look (no placeholder node)=%s. Seeing it drawn in the editor window is a human check (README of run_s0.sh)" % real_all)
	return 0 if real_all else 1


func _spawner(ps: PackedScene) -> int:
	var holder := Node.new()
	holder.name = "World"
	root.add_child(holder)
	var spawn := Node.new()
	spawn.name = "Spawn"
	holder.add_child(spawn)
	var sp := MultiplayerSpawner.new()
	sp.name = "Spawner"
	holder.add_child(sp)
	sp.spawn_path = NodePath("../Spawn")
	sp.add_spawnable_scene(DIR + "body_placeholder.tscn")
	var body := ps.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	spawn.add_child(body)
	var look := body.get_node_or_null("Look")
	var was_ph := look is InstancePlaceholder
	var made: Node = (look as InstancePlaceholder).create_instance(true) if was_ph else null
	var ok := was_ph and made != null and body.get_node_or_null("Look") == made and made.get_child_count() == 2
	print("S0 1 spawner: placeholder under Spawn=%s, create_instance ok=%s, spawnable scenes=%d, body path=%s" % [was_ph, ok, sp.get_spawnable_scene_count(), str(body.get_path())])
	print("S0 VERDICT placeholder spawner: create_instance under a MultiplayerSpawner parent works=%s; late join NOT tested here (needs a client: s1 late_join.tscn). Watch for engine ERROR lines above" % ok)
	holder.free()
	return 0 if ok else 1
