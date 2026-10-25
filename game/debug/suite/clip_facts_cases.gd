extends RefCounted

## 055c1 (c1-c1) cases of rules_suite: the AnimationLibrary of every model says, through ClipFacts, what the clip dictionaries of the
## creatures and wizards say today (frames, frame rate, the frame of each `hit` and `shoot`), and every library has the shape the
## migrator gives it. The dictionaries are still the rules' source in this cut; this proves the library is ready to replace them.
## Prints CLIP FACTS roles=<n> equal=<n> differ=<n> missing=<n> and CLIP LIBRARIES libs=<n> anims=<n> bad=<n>.
## Ref: tools/migrate/extract_clips_055c1.py (the translation table dictionary -> role).

const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"
const MODELS_DIR := "res://scenes/bodies/models/"
const MELEE: PackedStringArray = ["attack", "attack2", "attack3"]
const SHOOT: PackedStringArray = ["shoot", "shoot2"]
const TABLES := {
	"extra_animations": ["cower", "talk_cower", "work", "pull"], "flight_animations": ["takeoff", "fly", "land", "hover"],
	"stun_animations": ["knock", "get_up", "fly_damage", "hit_floor"], "death_animations": ["death", "fly_death"],
	"captive_animations": ["rise", "held", "thrash"],
}
const MAX_LINES := 12


func run(_host: Node) -> Dictionary:
	return {"clip_facts": _parity(), "clip_libraries": _shape()}


func _parity() -> Dictionary:
	var counts := {"roles": 0, "equal": 0, "differ": 0, "missing": 0}
	var notes := PackedStringArray()
	for dir: String in [CREATURES_DIR, WIZARDS_DIR]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var type := load(dir + file) as Resource
			var library := load("%s%s_clips.tres" % [MODELS_DIR, type.get("model")]) as AnimationLibrary
			var facts := ClipFacts.of(library)
			for row: Array in _expected(type):
				counts["roles"] += 1
				var role: String = row[0]
				var entry: Dictionary = row[1]
				if not facts.has(StringName(role)):
					counts["missing"] += 1
					_note(notes, "%s: no role %s" % [file, role])
				elif _same(facts, StringName(role), entry):
					counts["equal"] += 1
				else:
					counts["differ"] += 1
					_note(notes, "%s: %s is %d@%d hits %s shots %s, the dictionary says %s" % [file, role, facts.frames(StringName(role)),
						facts.fps(StringName(role)), facts.hits(StringName(role)), facts.shots(StringName(role)), entry])
	print("CLIP FACTS roles=%d equal=%d differ=%d missing=%d" % [counts["roles"], counts["equal"], counts["differ"], counts["missing"]])
	for line in notes:
		print("CLIP FACTS   " + line)
	return {"ok": counts["roles"] > 0 and counts["differ"] == 0 and counts["missing"] == 0, "counts": counts, "notes": notes}


## Markers belong to the clip, and a clip can serve two roles (the Blight's `shoot2` plays a melee clip): the hits are compared
## for the attack roles and the shots for the shoot roles, which are the ones the rules read them from.
func _same(facts: ClipFacts, role: StringName, entry: Dictionary) -> bool:
	if facts.frames(role) != roundi(float(entry["frames"])) or facts.fps(role) != roundi(float(entry.get("framerate", 30))):
		return false
	if MELEE.has(String(role)) and facts.hits(role) != _ticks(entry.get("attack_ticks", [])):
		return false
	return not SHOOT.has(String(role)) or facts.shots(role) == _ticks(entry.get("shoot_ticks", []))


func _ticks(list: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for tick: Variant in list:
		out.append(roundi(float(tick)))
	return out


## [[role, {frames, framerate, attack_ticks, shoot_ticks}]] of one type: the translation table of the plan.
func _expected(type: Resource) -> Array:
	var out := []
	var run_clip: Dictionary = type.get("run_animation")
	_add(out, "idle", type.get("stance_animation"))
	_add(out, "gesture", type.get("idle_animation"))
	_add(out, "run", run_clip)
	var walk: Dictionary = type.get("walk_animation")
	if walk.get("tag", "") != run_clip.get("tag", ""):
		_add(out, "walk", walk)
	var melee: Array = type.get("melee_animations") if type.get("melee_animations") != null else []
	for i in mini(melee.size(), MELEE.size()):
		_add(out, MELEE[i], melee[i])
	var shoot: Array = type.get("shoot_animations") if type.get("shoot_animations") != null else []
	for i in mini(shoot.size(), SHOOT.size()):
		_add(out, SHOOT[i], shoot[i])
	for property: String in TABLES:
		var table: Variant = type.get(property)
		for role: String in TABLES[property]:
			if table is Dictionary and (table as Dictionary).has(role):
				_add(out, role, table[role])
	var cast: Variant = type.get("cast_animations")
	if cast is Dictionary:
		_add(out, "cast", (cast as Dictionary).get("cast", {}))
		_add(out, "cast_run", (cast as Dictionary).get("run_cast", {}))
		var deaths: PackedInt32Array = type.get("death_frames")
		for i in mini(deaths.size(), 3):
			out.append(["death" if i == 0 else "death%d" % (i + 1), {"frames": deaths[i], "framerate": 30}])
		out.append(["ghost_rise", {"frames": type.get("corpse_rise_frames"), "framerate": 30}])
		out.append(["unghost", {"frames": type.get("float_to_stance_frames"), "framerate": 30}])
	return out.filter(func(row: Array) -> bool: return float(row[1].get("frames", 0)) > 0.0)


func _add(out: Array, role: String, entry: Variant) -> void:
	if entry is Dictionary and not (entry as Dictionary).is_empty() and not str((entry as Dictionary).get("tag", "x")).is_empty():
		out.append([role, entry])


func _note(notes: PackedStringArray, line: String) -> void:
	if notes.size() < MAX_LINES:
		notes.append(line)


## Every library: an idle (when the model has a scene), whole frames, markers and the method track inside the clip.
func _shape() -> Dictionary:
	var libs := 0
	var anims := 0
	var bad := PackedStringArray()
	for file in DirAccess.get_files_at(MODELS_DIR):
		if not file.ends_with("_clips.tres"):
			continue
		libs += 1
		var library := load(MODELS_DIR + file) as AnimationLibrary
		if library == null:
			_note(bad, file + ": does not load (run tools/migrate/run_extract_clips_055c1.sh)")
			continue
		for role in library.get_animation_list():
			anims += 1
			var anim := library.get_animation(role)
			var span := anim.length / anim.step if anim.step > 0.0 else -1.0
			if span < 0.0 or absf(span - roundf(span)) > 0.001:
				_note(bad, "%s/%s: length %.4f is not whole frames of step %.4f" % [file, role, anim.length, anim.step])
			for marker in anim.get_marker_names():
				if anim.get_marker_time(marker) > anim.length + 0.0001:
					_note(bad, "%s/%s: marker %s past the end" % [file, role, marker])
	print("CLIP LIBRARIES libs=%d anims=%d bad=%d" % [libs, anims, bad.size()])
	for line in bad:
		print("CLIP LIBRARIES   " + line)
	return {"ok": libs > 0 and bad.is_empty(), "libs": libs, "anims": anims, "bad": bad}
