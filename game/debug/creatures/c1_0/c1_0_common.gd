extends RefCounted

## Helpers shared by the disposable c1-0 probe (055c1): argument parsing, the watchdog, the scans of the model scenes and of the
## catalog. It measures nothing by itself and writes nothing outside user://c1_0. Deleted when c1 closes.

const OUT_DIR := "user://c1_0"
const MANIFEST := "user://c1_0/manifest.json"
const MODELS_DIR := "res://scenes/bodies/models/"
const GLB_DIR := "res://assets/original/models/"
const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"
## Every probe quits by itself after this, whatever happens (a hung parity script once blocked the queue).
const WATCHDOG_S := 120.0
## BodyModel.ROLES plus the roles 055c1 adds, copied here so the probe does not depend on the class cache.
const ALL_ROLES: PackedStringArray = ["idle", "run", "attack", "attack2", "attack3", "shoot", "cast", "hit", "death", "held", "thrash",
	"rise", "fly", "cower", "talk_cower", "work", "takeoff", "land", "knock", "get_up", "fly_damage", "gesture", "cast_run", "hover",
	"fly_death", "fall", "hit_floor", "walk", "shoot2", "pull", "death2", "death3", "ghost_rise", "unghost"]
const HOLD_ROLES: PackedStringArray = ["death", "fly_death", "fall"]
const ONE_SHOT_ROLES: PackedStringArray = ["attack", "attack2", "attack3", "shoot", "cast", "hit", "rise", "hit_floor"]


## Prints C1_0 FAIL and asks the loop to quit with 1. The caller must return right after.
static func fail(tree: SceneTree, reason: String) -> void:
	print("C1_0 FAIL " + reason)
	tree.quit(1)


## Quits with 1 after WATCHDOG_S seconds, whatever the script is doing (a script stuck in a loop cannot be rescued: every loop of the probe is bounded).
static func arm_watchdog(tree: SceneTree) -> void:
	tree.create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("C1_0 FAIL watchdog %d s" % int(WATCHDOG_S))
		tree.quit(1))


## The value of `--name=value` among the user arguments (after `--`), or `default`.
static func user_arg(arg_name: String, default: String) -> String:
	var prefix := "--%s=" % arg_name
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return default


static func static_mb() -> float:
	return float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0


## Resident set of this process in KB (macOS/Linux `ps`), -1 when unavailable.
static func rss_kb() -> int:
	var out: Array = []
	var code := OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], out)
	if code != 0 or out.is_empty():
		return -1
	return int(str(out[0]).strip_edges())


static func file_len(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else 0


## Size of the file deflated (zlib, what git stores): the estimate of its weight in the repository.
static func deflate_len(path: String) -> int:
	var bytes := FileAccess.get_file_as_bytes(path)
	return bytes.compress(FileAccess.COMPRESSION_DEFLATE).size() if not bytes.is_empty() else 0


## Vector2i(tracks, keys) of an animation.
static func track_stats(anim: Animation) -> Vector2i:
	var keys := 0
	for track in anim.get_track_count():
		keys += anim.track_get_key_count(track)
	return Vector2i(anim.get_track_count(), keys)


## Models with a scene: {models, clips, frames, per: {model: {clips, frames}}}, read from the text of each .tscn (no instancing).
## clips = number of `"framerate"` entries of its `clips` table; frames = the sum of their `"frames"`.
static func scan_all() -> Dictionary:
	var rx := RegEx.new()
	rx.compile("\"frames\": (\\d+)")
	var per: Dictionary = {}
	var total_clips := 0
	var total_frames := 0
	for file in DirAccess.get_files_at(MODELS_DIR):
		if not file.ends_with(".tscn"):
			continue
		var text := FileAccess.get_file_as_string(MODELS_DIR + file)
		var clips := text.count("\"framerate\"")
		var frames := 0
		for found in rx.search_all(text):
			frames += int(found.get_string(1))
		per[file.get_basename()] = {"clips": clips, "frames": frames}
		total_clips += clips
		total_frames += frames
	return {"models": per.size(), "clips": total_clips, "frames": total_frames, "per": per}


## Model tags the 15 wizards use: {model: true}.
static func wizard_models() -> Dictionary:
	var out: Dictionary = {}
	for file in DirAccess.get_files_at(WIZARDS_DIR):
		if file.ends_with(".tres"):
			var type := load(WIZARDS_DIR + file) as Resource
			if type != null:
				out[str(type.get("model"))] = true
	return out


## The models to build: `many` (most clips of a creature), `simple` (fewest clips, >= 4), the wizard `hero`, plus `eorc` and `jnwr`
## of the plan. spec: "auto", "all" or a comma list.
static func pick_models(spec: String, scan: Dictionary, wizards: Dictionary) -> PackedStringArray:
	var per: Dictionary = scan["per"]
	if spec == "all":
		return PackedStringArray(per.keys())
	if spec != "auto":
		return spec.split(",", false)
	var many := ""
	var simple := ""
	for model: String in per:
		if wizards.has(model):
			continue
		var count: int = per[model]["clips"]
		if many.is_empty() or count > int(per[many]["clips"]):
			many = model
		if count >= 4 and (simple.is_empty() or count < int(per[simple]["clips"])):
			simple = model
	var out := PackedStringArray()
	for model: String in [many, simple, "hero", "eorc", "jnwr"]:
		if not model.is_empty() and per.has(model) and not out.has(model):
			out.append(model)
	print("C1_0 models many=%s simple=%s wizard=hero (+eorc, jnwr)" % [many, simple])
	return out


## Today's dictionaries of every creature, grouped: {model: {tag: {hits: [frame], shoots: [frame], conflict: bool}}}.
## `hits` are the attack_ticks of melee_animations and `shoots` the shoot_ticks of shoot_animations (frames at the clip's framerate).
static func creature_ticks() -> Dictionary:
	var out: Dictionary = {}
	for file in DirAccess.get_files_at(CREATURES_DIR):
		if not file.ends_with(".tres"):
			continue
		var type := load(CREATURES_DIR + file) as Resource
		if type == null:
			continue
		var by_tag: Dictionary = out.get_or_add(str(type.get("model")), {})
		_collect(by_tag, type.get("melee_animations"), "attack_ticks", "hits")
		_collect(by_tag, type.get("shoot_animations"), "shoot_ticks", "shoots")
	return out


static func _collect(by_tag: Dictionary, list: Variant, ticks_key: String, field: String) -> void:
	if not list is Array:
		return
	for entry: Variant in list:
		if not entry is Dictionary:
			continue
		var clip: Dictionary = entry
		var frames: Array = []
		for tick: Variant in clip.get(ticks_key, []):
			frames.append(int(tick))
		var slot: Dictionary = by_tag.get_or_add(str(clip.get("tag", "")), {"hits": [], "shoots": [], "conflict": false})
		var known: Array = slot[field]
		if known.is_empty():
			slot[field] = frames
		elif not frames.is_empty() and known != frames:
			slot["conflict"] = true


## role -> {tag, timeline} of a model scene instance (not in the tree): the AnimationNodeAnimation of each state of its Tree.
static func roles_of(inst: Node) -> Dictionary:
	var out: Dictionary = {}
	var anim_tree := inst.get_node_or_null("Tree") as AnimationTree
	if anim_tree == null:
		return out
	var machine := anim_tree.tree_root as AnimationNodeStateMachine
	if machine == null:
		return out
	for role: String in ALL_ROLES:
		if machine.has_node(role):
			var state := machine.get_node(role) as AnimationNodeAnimation
			if state != null:
				out[role] = {"tag": String(state.animation), "timeline": state.timeline_length}
	return out


## The AnimationPlayer inside the .glb of a model scene instance (null when there is none).
static func glb_player(inst: Node) -> AnimationPlayer:
	var model := inst.get_node_or_null("Model")
	if model == null:
		return null
	var found := model.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if not found.is_empty() else null
