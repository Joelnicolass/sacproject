extends RefCounted

## 055c1 (c1-c2) cases of rules_suite: the AnimationLibrary of each model is the one place the rules read the timing of a swing, a shot,
## a stun, a flight and a death from (through ClipFacts), so these cases keep it healthy:
##   - every CreatureType and WizardType points at the library of its model (`clips` = models/<model>_clips.tres);
##   - every library has whole frames, its markers inside the clip, an `idle` when its model has a scene, only roles the bodies know,
##     and a ClipFacts that agrees with the Animation (frames, fps, hits, shots);
##   - an `attack*` clip of a model of your own (assets/custom/models/) has its `hit` marker, a `shoot*` clip its `shoot` marker. The
##     original's models have swings and shots with no marker on purpose (they land on the last frame); their counts may only go down.
## Prints CLIP FACTS types=<n> linked=<n> bad=<n> and CLIP LIBRARIES libs=<n> anims=<n> no_hit=<n> no_shot=<n> bad=<n>.

const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"
const MODELS_DIR := "res://scenes/bodies/models/"
const CUSTOM_MODELS_DIR := "res://assets/custom/models/"
const MAX_LINES := 12
## Swings and shots of the original's models with no marker (they land on the last frame, as in the original). Do not raise: a new
## swing or shot gets its marker.
const MAX_SWINGS_WITHOUT_HIT := 13
const MAX_SHOTS_WITHOUT_MARKER := 53


func run(_host: Node) -> Dictionary:
	return {"clip_facts": _types(), "clip_libraries": _libraries()}


## Every type points at the library of its model, and the rules read from that same library.
func _types() -> Dictionary:
	var count := 0
	var linked := 0
	var bad := PackedStringArray()
	for dir: String in [CREATURES_DIR, WIZARDS_DIR]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			count += 1
			var type := load(dir + file) as Resource
			var path := ModelPaths.clips_path(BodyFacts.of(type.get("body") as PackedScene).model_id)
			var library := type.get("clips") as AnimationLibrary
			if library == null:
				_note(bad, "%s: no clips (its library is %s)" % [file, path])
			elif library.resource_path != path:
				_note(bad, "%s: clips is %s, the library of its model is %s" % [file, library.resource_path, path])
			else:
				linked += 1
	print("CLIP FACTS types=%d linked=%d bad=%d" % [count, linked, count - linked])
	for line in bad:
		print("CLIP FACTS   " + line)
	return {"ok": count > 0 and linked == count, "types": count, "linked": linked, "notes": bad}


## Every library: whole frames, markers inside, roles the bodies know, and ClipFacts equal to the Animation.
func _libraries() -> Dictionary:
	var libs := 0
	var anims := 0
	var no_hit := 0
	var no_shot := 0
	var bad := PackedStringArray()
	for file in DirAccess.get_files_at(MODELS_DIR):
		if not file.ends_with("_clips.tres"):
			continue
		libs += 1
		var model := ModelPaths.tag_of_file(file)
		var library := load(MODELS_DIR + file) as AnimationLibrary
		if library == null:
			_note(bad, file + ": does not load")
			continue
		var custom := ResourceLoader.exists("%s%s.glb" % [CUSTOM_MODELS_DIR, model])
		var facts := ClipFacts.of(library)
		if ModelPaths.exists(model) and not library.has_animation(&"idle"):
			_note(bad, file + ": the model has a scene but the library has no idle")
		for role in library.get_animation_list():
			if role == &"RESET":
				continue  # the hands: the Animation every role without a hand returns to (not a role)
			anims += 1
			var anim := library.get_animation(role)
			_check_clip(file, role, anim, facts, bad)
			if String(role).begins_with("attack") and facts.hits(role).is_empty():
				if custom:
					_note(bad, "%s/%s: a clip of your own needs its `hit` marker" % [file, role])
				else:
					no_hit += 1
			if String(role).begins_with("shoot") and facts.shots(role).is_empty():
				if custom:
					_note(bad, "%s/%s: a clip of your own needs its `shoot` marker" % [file, role])
				else:
					no_shot += 1
	if no_hit > MAX_SWINGS_WITHOUT_HIT:
		_note(bad, "%d swings without a `hit` marker, there were %d: give the new one its marker" % [no_hit, MAX_SWINGS_WITHOUT_HIT])
	if no_shot > MAX_SHOTS_WITHOUT_MARKER:
		_note(bad, "%d shots without a `shoot` marker, there were %d: give the new one its marker" % [no_shot, MAX_SHOTS_WITHOUT_MARKER])
	print("CLIP LIBRARIES libs=%d anims=%d no_hit=%d no_shot=%d bad=%d" % [libs, anims, no_hit, no_shot, bad.size()])
	for line in bad:
		print("CLIP LIBRARIES   " + line)
	return {"ok": libs > 0 and bad.is_empty(), "libs": libs, "anims": anims, "no_hit": no_hit, "no_shot": no_shot, "bad": bad}


func _check_clip(file: String, role: StringName, anim: Animation, facts: ClipFacts, bad: PackedStringArray) -> void:
	if not BodyModel.ROLES.has(String(role)):
		_note(bad, "%s/%s: not a role the bodies know (BodyModel.ROLES)" % [file, role])
	var span := anim.length / anim.step if anim.step > 0.0 else -1.0
	if span < 0.0 or absf(span - roundf(span)) > 0.001:
		_note(bad, "%s/%s: length %.4f is not whole frames of step %.4f" % [file, role, anim.length, anim.step])
	elif facts.frames(role) != roundi(span) or facts.fps(role) != roundi(1.0 / anim.step):
		_note(bad, "%s/%s: ClipFacts says %d frames at %d, the Animation has %d" % [file, role, facts.frames(role), facts.fps(role), roundi(span)])
	for marker in anim.get_marker_names():
		if anim.get_marker_time(marker) > anim.length + 0.0001:
			_note(bad, "%s/%s: marker %s past the end" % [file, role, marker])
	for frame in facts.hits(role) + facts.shots(role):
		if frame < 0 or frame > facts.frames(role):
			_note(bad, "%s/%s: a blow or shot at frame %d, the clip has %d" % [file, role, frame, facts.frames(role)])


func _note(notes: PackedStringArray, line: String) -> void:
	if notes.size() < MAX_LINES:
		notes.append(line)
