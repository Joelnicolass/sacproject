extends SceneTree

## Audits how every summonable creature, every wizard and every game actor with clips stands once its idle clip plays.
## Uses the same pose and capsule the game uses (BodyCatalog) over frame 0 of the idle clip.
## "$GODOT" --headless --path game --script res://tools/audit_body_pose.gd
## Ends with POSE AUDIT PASS, or POSE AUDIT FAIL and exit code 1.

const _OBJ := preload("res://scenes/world/obj_mesh.gd")

const BOOKS := "res://cache/data/books.json"
const CREATURES := "res://cache/data/creatures.json"
const WIZARDS := "res://cache/data/wizards.json"
const CLIPS := "res://cache/data/anim_mesh_clips_f37.json"
## Walkers: feet within this distance of y = 0 with the idle clip.
const FEET_TOLERANCE := 0.3
## Capsule height against the posed model height.
const CAPSULE_TOLERANCE := 0.25
## A model whose up axis tilts further than this from +y is lying on its side.
const UPRIGHT_MIN_Y := 0.9


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _initialize() -> void:
	var books := _read(BOOKS)
	var creatures := _read(CREATURES)
	var wizards := _read(WIZARDS)
	var clips := _read(CLIPS)
	var rows := {}
	for god: Variant in books:
		for tag: Variant in books[god].get("creatures", []):
			var row: Dictionary = creatures.get(tag, {})
			rows[str(row.get("model", "?"))] = ["unit", str(row.get("name", tag)), row]
	for tag: Variant in wizards:
		var wizard: Dictionary = wizards[tag]
		rows[str(wizard.get("model", "?"))] = ["wizard", str(wizard.get("name", tag)), wizard]
	## Game actors outside the books (the Sac Doctor): any creature whose model has exported clips.
	for tag: Variant in creatures:
		var row: Dictionary = creatures[tag]
		var model := str(row.get("model", "?"))
		if clips.has(model) and not rows.has(model):
			rows[model] = ["actor", str(row.get("name", tag)), row]
	if rows.is_empty():
		push_error("POSE AUDIT: no hay books.json / wizards.json en cache/data")
		quit(1)
		return
	print("model|kind|name|fly|up_y|foot|cap_h|cap_r|reach|idle_tag|posed_y(min,max)|posed_size|verdict")
	var failed := 0
	var keys := rows.keys()
	keys.sort()
	for model: String in keys:
		var kind: String = rows[model][0]
		var data: Dictionary = rows[model][2]
		var info := BodyCatalog.info(model)
		var pose := BodyCatalog.pose(model, true)
		var flies := float(data.get("flying_speed", 0.0)) > 0.0
		## The clip the body was baked from (F112: stance1 for book creatures of level 2+), else the idle clip.
		var idle_tag := str(info.get("pose_source", ""))
		if idle_tag.is_empty() or not clips.get(model, {}).has(idle_tag):
			idle_tag = str(data.get("idle_animation", {}).get("tag", ""))
		var clip: Dictionary = clips.get(model, {}).get(idle_tag, {})
		var frames: Array = clip.get("frame_objs", [])
		var cap_h := maxf(float(info.get("height", 1.8)), 0.6)
		var cap_r := minf(float(info.get("radius", 0.35)), cap_h * 0.45)
		var up := (pose.basis * Vector3.UP).normalized()
		var verdict: PackedStringArray = []
		var posed_y := "-"
		var posed_size := "-"
		var frame: ArrayMesh = null
		if not frames.is_empty():
			frame = _OBJ.build(str(frames[0]), "", {_OBJ.MIRROR_Z: true})
		if frame == null:
			verdict.append("SIN_CLIP")
		else:
			var box := pose * frame.get_aabb()
			posed_y = "%.2f,%.2f" % [box.position.y, box.end.y]
			posed_size = "%.2f,%.2f,%.2f" % [box.size.x, box.size.y, box.size.z]
			if up.y < UPRIGHT_MIN_Y:
				verdict.append("DE_COSTADO")
			if absf(box.position.y) > FEET_TOLERANCE:
				verdict.append("FLOTA(%+.2f)" % box.position.y if box.position.y > 0.0 else "HUNDIDO(%+.2f)" % box.position.y)
			if absf(cap_h - box.size.y) > CAPSULE_TOLERANCE * box.size.y:
				verdict.append("CAPSULA(%.2f vs %.2f)" % [cap_h, box.size.y])
		if not verdict.is_empty():
			failed += 1
		print("%s|%s|%s|%s|%.2f|%.2f|%.2f|%.2f|%.2f|%s|%s|%s|%s" % [
			model, kind, rows[model][1], "vuela" if flies else "", up.y,
			float(info.get("foot_offset", 0.0)), cap_h, cap_r, float(info.get("reach", 0.0)),
			idle_tag, posed_y, posed_size, "ok" if verdict.is_empty() else " ".join(verdict),
		])
	print("modelos %d, con falla %d" % [keys.size(), failed])
	if failed == 0:
		print("POSE AUDIT PASS")
		quit()
	else:
		print("POSE AUDIT FAIL")
		quit(1)
