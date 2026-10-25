extends RefCounted

## 055s (s2) case of rules_suite: the server and the room server never load presentation. The body scene of every creature and wizard
## carries only its size and sockets, plus a placeholder where its look (model, sounds) goes; the appearance lives behind it. For each
## CreatureType and WizardType this checks:
##   - its body scene's `Look` is an instance placeholder of `<name>_look.tscn` (the file exists), with nothing overridden on it;
##   - neither the type file nor the body scene depends on an audio stream, a sound set, a .glb, a model scene or a look scene
##     (ResourceLoader.get_dependencies), so loading them does not pull the appearance in;
##   - the look scene loads, its root is a BodyLook with a model (or the static mesh of a hybrid), and its model is the `model_id`
##     the body scene saves, which is what travels in the packets.
## Prints PRESENTATION REFS bodies=<n> types=<n> leaks=<n> looks=<n> bad=<n> (and a line per problem, at most 12).

const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"
## Anything a dependency path contains that is the appearance. The clip libraries (`<model>_clips.tres`, in the models folder) are not:
## the rules read them, and the dedicated export empties their tracks (DedicatedStrip).
const FORBIDDEN: PackedStringArray = [".glb", ".wav", ".ogg", ".mp3", "scenes/bodies/models/", "data/audio/creatures/", "data/audio/wizards/", "_look.tscn"]
const ALLOWED_PART := "_clips"
const MAX_LINES := 12


func run(_host: Node) -> Dictionary:
	var types := 0
	var bodies := 0
	var leaks := 0
	var looks := 0
	var bad := PackedStringArray()
	for dir: String in [CREATURES_DIR, WIZARDS_DIR]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			types += 1
			var type := load(dir + file) as Resource
			var body := type.get("body") as PackedScene
			if body == null:
				_note(bad, "%s: no body scene" % file)
				continue
			bodies += 1
			leaks += _leaks(dir + file, bad)
			leaks += _leaks(body.resource_path, bad)
			var look_path := _placeholder(body, file, bad)
			if look_path.is_empty():
				continue
			if _look_is_sound(look_path, BodyFacts.of(body).model_id, file, bad):
				looks += 1
	print("PRESENTATION REFS bodies=%d types=%d leaks=%d looks=%d bad=%d" % [bodies, types, leaks, looks, bad.size()])
	for line in bad:
		print("PRESENTATION REFS   " + line)
	var ok := bodies > 0 and bodies == types and leaks == 0 and looks == bodies and bad.is_empty()
	return {"presentation_refs": {"ok": ok, "bodies": bodies, "types": types, "leaks": leaks, "looks": looks, "bad": bad}}


## How many direct dependencies of `path` are the appearance.
func _leaks(path: String, bad: PackedStringArray) -> int:
	var count := 0
	for dependency in ResourceLoader.get_dependencies(path):
		for needle in FORBIDDEN:
			if dependency.contains(needle) and not dependency.contains(ALLOWED_PART):
				_note(bad, "%s depends on %s" % [path.get_file(), dependency])
				count += 1
				break
	return count


## The path the `Look` placeholder of the body scene points at ("" and a note when it is not a clean placeholder).
func _placeholder(body: PackedScene, file: String, bad: PackedStringArray) -> String:
	var root := body.instantiate()
	var found := root.get_node_or_null("Look") if root != null else null
	var path := ""
	if found == null or not found is InstancePlaceholder:
		_note(bad, "%s: the body scene has no `Look` instance placeholder" % file)
	else:
		path = (found as InstancePlaceholder).get_instance_path()
		var expected := body.resource_path.trim_suffix(".tscn") + "_look.tscn"
		if path != expected or not ResourceLoader.exists(path):
			_note(bad, "%s: Look points at %s, expected %s" % [file, path, expected])
			path = ""
		elif not (found as InstancePlaceholder).get_stored_values().is_empty():
			_note(bad, "%s: the Look placeholder overrides %s (it would load with the body scene)" % [file, str((found as InstancePlaceholder).get_stored_values().keys())])
			path = ""
	if root != null:
		root.free()
	return path


## The look at `path` loads, is a BodyLook with something to draw and its model is `model_id`.
func _look_is_sound(path: String, model_id: String, file: String, bad: PackedStringArray) -> bool:
	var scene := load(path) as PackedScene
	var root := scene.instantiate() if scene != null else null
	var look := root as BodyLook
	var ok := false
	if look == null:
		_note(bad, "%s: %s is not a BodyLook" % [file, path.get_file()])
	elif look.model == null and look.static_mesh == null:
		_note(bad, "%s: %s draws nothing (no model, no static mesh)" % [file, path.get_file()])
	elif look.model != null and look.model.model != model_id:
		_note(bad, "%s: %s draws model %s, its body scene says %s" % [file, path.get_file(), look.model.model, model_id])
	else:
		ok = true
	if root != null:
		root.free()
	return ok


func _note(notes: PackedStringArray, line: String) -> void:
	if notes.size() < MAX_LINES:
		notes.append(line)
