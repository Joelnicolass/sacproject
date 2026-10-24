class_name AnimExpect
extends RefCounted

## Debug: what the type data (CreatureType, WizardType, the Sac Doctor) says every role of a body should play. It is read
## straight from the .tres files and does not use the bake's own rules, so the audit checks the scenes against the data.
## Static; no state.

const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"
const DOCTOR_MODEL := "sacd"
## The clip the Sac Doctor holds while it falls out of the vortex (sacengine «expelled»).
const DOCTOR_FALL_TAG := "SDex"
## CreatureType dictionaries whose entries are a role each, and the roles they carry.
const SETS := {"extra_animations": ["cower", "talk_cower", "work"], "flight_animations": ["takeoff", "fly", "land", "hover"],
	"stun_animations": ["knock", "get_up", "fly_damage", "hit_floor"], "death_animations": ["death", "fly_death"],
	"captive_animations": ["rise", "held", "thrash"]}
const MELEE_ROLES: PackedStringArray = ["attack", "attack2", "attack3"]
## The doctor's melee slots are its works: slot -> role (doctor_body.gd work_slots / work_roles).
const DOCTOR_SLOT_ROLES := {0: "attack", 1: "work", 2: "cast"}


## model tag -> Array of {"who": "creature dcas", "kind": "creature|peasant|doctor|wizard", "type": Resource}.
static func owners() -> Dictionary:
	var out: Dictionary = {}
	for file in _files(CREATURES_DIR):
		var type := load(CREATURES_DIR + file) as CreatureType
		if type == null or type.model.is_empty():
			continue
		var kind := "doctor" if type.model == DOCTOR_MODEL else ("peasant" if type.extra_animations.has("cower") else "creature")
		_add(out, type.model, {"who": "%s %s" % [kind, type.tag], "kind": kind, "type": type})
	for file in _files(WIZARDS_DIR):
		var wizard := load(WIZARDS_DIR + file) as WizardType
		if wizard != null and not wizard.model.is_empty():
			_add(out, wizard.model, {"who": "wizard " + wizard.tag, "kind": "wizard", "type": wizard})
	return out


## role -> {"tag": String, "accept": PackedStringArray, "frames": int} for one owner; only the roles its data names.
static func roles_of(owner: Dictionary) -> Dictionary:
	var type: Resource = owner["type"]
	var roles: Dictionary = {}
	var stance := _clip(type.get("stance_animation"))
	var idle := _clip(type.get("idle_animation"))
	roles["idle"] = _entry(stance if not str(stance["tag"]).is_empty() else idle, [stance, idle])
	if not str(idle["tag"]).is_empty() and idle["tag"] != stance["tag"]:
		roles["gesture"] = _entry(idle, [idle])
	var run := _clip(type.get("run_animation"))
	if int(run["frames"]) <= 1:
		run = _clip(type.get("walk_animation"))
	roles["run"] = _entry(run, [run])
	if type is WizardType:
		var casts: Dictionary = (type as WizardType).cast_animations
		roles["cast"] = _entry(_clip(casts.get("cast")), [_clip(casts.get("cast"))])
		roles["cast_run"] = _entry(_clip(casts.get("run_cast")), [_clip(casts.get("run_cast"))])
		var stun: Dictionary = (type as WizardType).stun_animations
		for role: String in SETS["stun_animations"]:
			roles[role] = _entry(_clip(stun.get(role)), [_clip(stun.get(role))])
	else:
		_creature_roles(type as CreatureType, owner["kind"] == "doctor", roles)
	for role: String in roles.keys():
		if str((roles[role] as Dictionary)["tag"]).is_empty():
			roles.erase(role)
	return roles


static func _creature_roles(type: CreatureType, doctor: bool, roles: Dictionary) -> void:
	for slot in type.melee_animations.size():
		var role: String = DOCTOR_SLOT_ROLES.get(slot, "") if doctor else (MELEE_ROLES[slot] if slot < MELEE_ROLES.size() else "")
		if not role.is_empty():
			roles[role] = _entry(_clip(type.melee_animations[slot]), [_clip(type.melee_animations[slot])])
	if not doctor and not type.shoot_animations.is_empty():
		roles["shoot"] = _entry(_clip(type.shoot_animations[0]), [_clip(type.shoot_animations[0])])
	for field: String in SETS:
		var table: Dictionary = type.get(field)
		for role: String in SETS[field]:
			if table.has(role):
				roles[role] = _entry(_clip(table.get(role)), [_clip(table.get(role))])
	if doctor:
		roles["fall"] = {"tag": DOCTOR_FALL_TAG, "accept": PackedStringArray([DOCTOR_FALL_TAG]), "frames": 0}


static func _clip(value: Variant) -> Dictionary:
	var dict: Dictionary = value if value is Dictionary else {}
	# The .glb carries every clip at 30 fps: a 20 fps clip of the data (the Spitfire's shoot) is compared in 30 fps frames.
	var rate := maxi(1, int(dict.get("framerate", 30)))
	return {"tag": str(dict.get("tag", "")), "frames": roundi(float(dict.get("frames", 0)) * 30.0 / float(rate))}


static func _entry(main: Dictionary, accepted: Array) -> Dictionary:
	var accept := PackedStringArray()
	for clip: Dictionary in accepted:
		if not str(clip["tag"]).is_empty():
			accept.append(str(clip["tag"]))
	return {"tag": main["tag"], "accept": accept, "frames": main["frames"]}


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
