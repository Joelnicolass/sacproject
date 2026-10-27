extends Node

## 055s s4: where the memory of the exported dedicated server goes. It does not belong to the game: DedicatedStrip puts it in a
## scratch pack (SAC_PACK_PROBE=1) and agent/runs/run_055s_dedicated_cost.sh runs it as
##   godot --headless --main-pack <probe.pck> res://dedicated_mem_probe/probe.tscn -- --dedicated --no-flow
## It lets the autoloads finish, notes the static memory, loads the main scene (boot) as the dedicated does, waits HOLD_S and prints
## one `MEM ...` line per fact: static memory at both moments, object counts, what is in the resource cache by folder and by class.
## It stays alive after `MEM done` (the script reads the RSS of the process, then kills it) and quits by itself after 120 s.

const BOOT := "res://scenes/core/boot.tscn"
const HOLD_S := 5.0
const RUNNER_META := "dedicated_mem_probe_runner"
const SKIP_DIRS: PackedStringArray = [".godot", ".git", ".import"]
const TOP := 25
const FOLDER_DEPTH := 3

var _by_folder: Dictionary = {}
var _by_class: Dictionary = {}


func _ready() -> void:
	## AgentKit mounts every harness script under its autoload in every flow: only the probe run (`--dedicated --no-flow`) measures.
	if not OS.get_cmdline_user_args().has("--no-flow"):
		return
	if has_meta(RUNNER_META):
		_run.call_deferred()
		return
	## The change of scene frees this node: a twin under the root does the measuring.
	var twin := (get_script() as GDScript).new() as Node
	twin.set_meta(RUNNER_META, true)
	twin.name = "DedicatedMemProbeRunner"
	get_tree().root.add_child.call_deferred(twin)


func _mb(bytes: int) -> float:
	return float(bytes) / 1048576.0


func _run() -> void:
	get_tree().create_timer(120.0).timeout.connect(func() -> void: get_tree().quit(2))
	await get_tree().process_frame
	var floor_bytes := OS.get_static_memory_usage()
	print("MEM autoloads static=%.1f MB resources=%d nodes=%d" % [_mb(floor_bytes), _monitor(Performance.OBJECT_RESOURCE_COUNT), _monitor(Performance.OBJECT_NODE_COUNT)])
	get_tree().change_scene_to_file(BOOT)
	await get_tree().create_timer(HOLD_S).timeout
	var now_bytes := OS.get_static_memory_usage()
	print("MEM boot static=%.1f MB peak=%.1f MB (the main scene and what it loads add %.1f MB over the autoloads)" % [_mb(now_bytes), _mb(OS.get_static_memory_peak_usage()), _mb(now_bytes - floor_bytes)])
	print("MEM objects total=%d resources=%d nodes=%d orphans=%d texture_mem=%.1f MB buffer_mem=%.1f MB" % [_monitor(Performance.OBJECT_COUNT), _monitor(Performance.OBJECT_RESOURCE_COUNT), _monitor(Performance.OBJECT_NODE_COUNT), _monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), _mb(_monitor(Performance.RENDER_TEXTURE_MEM_USED)), _mb(_monitor(Performance.RENDER_BUFFER_MEM_USED))])
	_walk("res://")
	_print_table("folder", _by_folder)
	_print_table("class", _by_class)
	print("MEM done")


func _monitor(which: Performance.Monitor) -> int:
	return int(Performance.get_monitor(which))


## Every file of the pack whose resource is in the cache right now (the pack lists imported files by their original name).
func _walk(dir: String) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		if not SKIP_DIRS.has(sub):
			_walk(dir.path_join(sub))
	for raw: String in DirAccess.get_files_at(dir):
		var file := raw.trim_suffix(".remap").trim_suffix(".import")
		var path := dir.path_join(file)
		if ResourceLoader.has_cached(path):
			_count(path)


func _count(path: String) -> void:
	var parts := path.trim_prefix("res://").split("/")
	var folder := "/".join(parts.slice(0, mini(FOLDER_DEPTH, parts.size() - 1)))
	_add(_by_folder, folder, 1)
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if resource == null:
		return
	_add(_by_class, resource.get_class(), _units(resource))


## One number that says how big the resource is for its class: samples, vertices, keys, pixels, source characters; 1 for the rest.
func _units(resource: Resource) -> int:
	if resource is AudioStreamWAV:
		return (resource as AudioStreamWAV).data.size()
	if resource is ArrayMesh:
		var mesh := resource as ArrayMesh
		var vertices := 0
		for surface in range(mesh.get_surface_count()):
			vertices += mesh.surface_get_array_len(surface)
		return vertices
	if resource is Animation:
		var anim := resource as Animation
		var keys := 0
		for track in range(anim.get_track_count()):
			keys += anim.track_get_key_count(track)
		return keys
	if resource is Texture2D:
		return (resource as Texture2D).get_width() * (resource as Texture2D).get_height()
	if resource is Script:
		return (resource as Script).source_code.length()
	return 1


func _add(table: Dictionary, key: String, units: int) -> void:
	var row: Array = table.get(key, [0, 0])
	row[0] += 1
	row[1] += units
	table[key] = row


func _print_table(label: String, table: Dictionary) -> void:
	var keys := table.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return table[a][0] > table[b][0])
	for index in range(mini(TOP, keys.size())):
		var key: String = keys[index]
		print("MEM %s %s n=%d units=%d" % [label, key, table[key][0], table[key][1]])
