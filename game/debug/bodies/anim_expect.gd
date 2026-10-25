class_name AnimExpect
extends RefCounted

## Debug: what the clips of every type (CreatureType, WizardType, the Sac Doctor) say each role of a body plays: the role, the .glb
## clip behind it (the Animation's name) and its length in 30 fps frames. It is read from the type's own library (`clips`), so the
## audit checks the model scenes against what the rules read. Static; no state.

const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"
const DOCTOR_MODEL := "sacd"
## The clip the Sac Doctor holds while it falls out of the vortex (sacengine expelled).
const DOCTOR_FALL_TAG := "SDex"


## model tag -> Array of {"who": "creature dcas", "kind": "creature|peasant|doctor|wizard", "type": Resource}.
static func owners() -> Dictionary:
	var out: Dictionary = {}
	for file in _files(CREATURES_DIR):
		var type := load(CREATURES_DIR + file) as CreatureType
		if type == null or type.model_id().is_empty():
			continue
		var kind := "doctor" if type.model_id() == DOCTOR_MODEL else ("peasant" if type.peasant else "creature")
		_add(out, type.model_id(), {"who": "%s %s" % [kind, type.tag], "kind": kind, "type": type})
	for file in _files(WIZARDS_DIR):
		var wizard := load(WIZARDS_DIR + file) as WizardType
		if wizard != null and not wizard.model_id().is_empty():
			_add(out, wizard.model_id(), {"who": "wizard " + wizard.tag, "kind": "wizard", "type": wizard})
	return out


## role -> {"tag": String, "accept": PackedStringArray, "frames": int} for one owner; the roles its library names.
static func roles_of(owner: Dictionary) -> Dictionary:
	var library: AnimationLibrary = (owner["type"] as Resource).get("clips")
	var roles: Dictionary = {}
	if library == null:
		return roles
	for role in library.get_animation_list():
		var anim := library.get_animation(role)
		var tag := anim.resource_name
		if tag.is_empty():
			continue
		# The .glb carries every clip at 30 fps: a 20 fps clip (the Spitfire's shoot) is compared in 30 fps frames.
		var frames := roundi(anim.length * 30.0)
		roles[String(role)] = {"tag": tag, "accept": PackedStringArray([tag]), "frames": frames}
	if owner["kind"] == "doctor":
		roles["fall"] = {"tag": DOCTOR_FALL_TAG, "accept": PackedStringArray([DOCTOR_FALL_TAG]), "frames": 0}
	return roles


static func _add(out: Dictionary, model: String, owner: Dictionary) -> void:
	if not out.has(model):
		out[model] = []
	(out[model] as Array).append(owner)


static func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			out.append(file)
	out.sort()
	return out
