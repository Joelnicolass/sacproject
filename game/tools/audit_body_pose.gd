extends SceneTree

## Audits how every summonable creature, every wizard and every game actor with clips stands once its idle clip plays.
## Uses the same pose and capsule the game uses (BodyCatalog) over frame 0 of the idle clip.
## "$GODOT" --headless --path game --script res://tools/audit_body_pose.gd
## Ends with POSE AUDIT PASS, or POSE AUDIT FAIL and exit code 1.
## F134: hybrid fliers (fly, and rest on a stance1 clip) are judged over every frame of that rest clip in a
## second section, HIBRIDA, instead of by frame 0.
## F135: a third section, VUELO, judges the flying capsule (BodyCatalog height_flying) over every frame of the fly clip.

const _OBJ := preload("res://scenes/world/obj_mesh.gd")

const BOOKS := OriginalAssets.DATA_DIR + "books.json"
const CREATURES := OriginalAssets.DATA_DIR + "creatures.json"
const WIZARDS := OriginalAssets.DATA_DIR + "wizards.json"
const CLIPS := "res://cache/data/anim_mesh_clips_f37.json"
## Walkers: feet within this distance of y = 0 with the idle clip.
const FEET_TOLERANCE := 0.3
## Capsule height against the posed model height.
const CAPSULE_TOLERANCE := 0.25
## A model whose up axis tilts further than this from +y is lying on its side.
const UPRIGHT_MIN_Y := 0.9
## F134 C1: median over the rest clip of each frame's lowest point, and the lowest point of the whole clip.
const HYBRID_MEDIAN_LIMIT := 0.30
const HYBRID_MIN_LIMIT := -0.35
## F134 C1 for a model marked rest_hovers (Phoenix): the lowest point of the clip within this distance of y = 0.
const HYBRID_HOVER_LIMIT := 0.35
## F134 C2: p95 of the frame tops - this <= capsule <= highest top + this.
const HYBRID_CAPSULE_SLACK := 0.10
## F135 C3: p50 of the fly frame tops <= flying capsule; p95 - this <= flying capsule <= max(capsule, highest top) + this.
const FLYING_CAPSULE_SLACK := 0.10


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
		push_error("POSE AUDIT: no hay books.json / wizards.json en assets/original/data")
		quit(1)
		return
	print("model|kind|name|fly|up_y|foot|cap_h|cap_r|reach|idle_tag|posed_y(min,max)|posed_size|verdict")
	var failed := 0
	var hybrids: Array = []
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
		var hybrid := _is_hybrid(kind, data, idle_tag, flies)
		if hybrid:
			var fly_tag := str(data.get("flight_animations", {}).get("fly", {}).get("tag", ""))
			var fly_frames: Array = clips.get(model, {}).get(fly_tag, {}).get("frame_objs", []) if not fly_tag.is_empty() else []
			hybrids.append([model, rows[model][1], idle_tag, frames, fly_tag, fly_frames])
		var posed_y := "-"
		var posed_size := "-"
		var frame: ArrayMesh = null
		if not frames.is_empty():
			frame = _OBJ.build(str(frames[0]), {_OBJ.MIRROR_Z: true})
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
		if hybrid:
			# Frame 0 alone says little for a rest clip that beats its wings: the HIBRIDA section judges where it stands
			# and its capsule. A body on its side or with no clip still fails here (REVIEW-F134).
			var kept := PackedStringArray(["HIBRIDA"])
			for flag in verdict:
				if flag == "DE_COSTADO" or flag == "SIN_CLIP":
					kept.append(flag)
			verdict = kept
			if kept.size() > 1:
				failed += 1
		elif not verdict.is_empty():
			failed += 1
		print("%s|%s|%s|%s|%.2f|%.2f|%.2f|%.2f|%.2f|%s|%s|%s|%s" % [
			model, kind, rows[model][1], "vuela" if flies else "", up.y,
			float(info.get("foot_offset", 0.0)), cap_h, cap_r, float(info.get("reach", 0.0)),
			idle_tag, posed_y, posed_size, "ok" if verdict.is_empty() else " ".join(verdict),
		])
	print("modelos %d, con falla %d" % [keys.size(), failed])
	failed += _audit_hybrids(hybrids)
	failed += _audit_flying(hybrids)
	if failed == 0:
		print("POSE AUDIT PASS")
		quit()
	else:
		print("POSE AUDIT FAIL")
		quit(1)


## A unit that flies and rests on its stance1 clip (the body was baked from it): it lands, so it must stand.
## The nine with takeoff/fly/land clips, plus Rhinok, which flies without them.
func _is_hybrid(kind: String, data: Dictionary, rest_tag: String, flies: bool) -> bool:
	var stance := str(data.get("stance_animation", {}).get("tag", ""))
	return kind == "unit" and flies and not stance.is_empty() and stance == rest_tag


## F134: every frame of the rest clip, posed as the game poses it (BodyCatalog.pose, overrides included), from the
## frames baked by tools/bake_clips.gd (027h). Returns how many hybrids fail C1 or C2.
func _audit_hybrids(hybrids: Array) -> int:
	print("")
	print("HIBRIDA|model|name|rest_tag|frames|min|median_frame_min|p50_max|p95_max|top_max|cap_h|hovers|verdict")
	var failed := 0
	for row: Array in hybrids:
		var model: String = row[0]
		var mins: Array[float] = []
		var maxes: Array[float] = []
		var pose := BodyCatalog.pose(model, true)
		var missing := 0
		for path: Variant in row[3]:
			var mesh := _baked_frame(str(path))
			if mesh == null:
				missing += 1
				continue
			var box := pose * mesh.get_aabb()
			mins.append(box.position.y)
			maxes.append(box.end.y)
		var entry := BodyCatalog.overrides().find(model)
		var hovers := entry != null and entry.rest_hovers
		var cap_h := maxf(float(BodyCatalog.info(model).get("height", 1.8)), 0.6)
		var verdict: PackedStringArray = []
		var stats := "-|-|-|-|-"
		if mins.is_empty():
			verdict.append("SIN_HORNEAR")
		else:
			if missing > 0:
				verdict.append("SIN_HORNEAR(%d)" % missing)
			var low: float = mins.min()
			var median := _percentile(mins, 0.5)
			var p95 := _percentile(maxes, 0.95)
			var top: float = maxes.max()
			stats = "%+.2f|%+.2f|%.2f|%.2f|%.2f" % [low, median, _percentile(maxes, 0.5), p95, top]
			if hovers:
				if absf(low) > HYBRID_HOVER_LIMIT:
					verdict.append("C1(min %+.2f)" % low)
			elif absf(median) > HYBRID_MEDIAN_LIMIT or low < HYBRID_MIN_LIMIT:
				verdict.append("C1(med %+.2f min %+.2f)" % [median, low])
			if cap_h < p95 - HYBRID_CAPSULE_SLACK or cap_h > top + HYBRID_CAPSULE_SLACK:
				verdict.append("C2(cap %.2f p95 %.2f tope %.2f)" % [cap_h, p95, top])
		if not verdict.is_empty():
			failed += 1
		print("HIBRIDA|%s|%s|%s|%d|%s|%.2f|%s|%s" % [
			model, row[1], row[2], mins.size(), stats, cap_h, "flota" if hovers else "",
			"ok" if verdict.is_empty() else " ".join(verdict),
		])
	print("hibridas %d, con falla %d" % [hybrids.size(), failed])
	return failed


## F135 C3: every frame of the fly clip, posed as the game poses it, against the capsule Flight gives it while FLYING
## (BodyCatalog height_flying). A hybrid without a fly clip (Rhinok) never flies here: SIN_VUELO, not counted.
func _audit_flying(hybrids: Array) -> int:
	print("")
	print("VUELO|model|name|fly_tag|frames|min|p50_max|p95_max|top_max|cap_h|cap_fly|verdict")
	var failed := 0
	for row: Array in hybrids:
		var model: String = row[0]
		var info := BodyCatalog.info(model)
		var cap_h := maxf(float(info.get("height", 1.8)), 0.6)
		var cap_fly := maxf(float(info.get("height_flying", cap_h)), 0.6)
		var fly_tag: String = row[4]
		var mins: Array[float] = []
		var maxes: Array[float] = []
		var missing := 0
		var pose := BodyCatalog.pose(model, true)
		for path: Variant in row[5]:
			var mesh := _baked_frame(str(path))
			if mesh == null:
				missing += 1
				continue
			var box := pose * mesh.get_aabb()
			mins.append(box.position.y)
			maxes.append(box.end.y)
		var verdict: PackedStringArray = []
		var stats := "-|-|-|-"
		if fly_tag.is_empty():
			verdict.append("SIN_VUELO")
		elif maxes.is_empty():
			verdict.append("SIN_HORNEAR")
			failed += 1
		else:
			if missing > 0:
				verdict.append("SIN_HORNEAR(%d)" % missing)
			var p50 := _percentile(maxes, 0.5)
			var p95 := _percentile(maxes, 0.95)
			var top: float = maxes.max()
			# min: how far above the origin the fly clip carries the body (informative; the capsule starts at the origin).
			stats = "%+.2f|%.2f|%.2f|%.2f" % [mins.min(), p50, p95, top]
			if cap_fly < p50 or cap_fly < p95 - FLYING_CAPSULE_SLACK or cap_fly > maxf(cap_h, top) + FLYING_CAPSULE_SLACK:
				verdict.append("C3(vuelo %.2f p50 %.2f p95 %.2f tope %.2f)" % [cap_fly, p50, p95, top])
			if not verdict.is_empty():
				failed += 1
		print("VUELO|%s|%s|%s|%d|%s|%.2f|%.2f|%s" % [
			model, row[1], fly_tag if not fly_tag.is_empty() else "-", maxes.size(), stats, cap_h, cap_fly,
			"ok" if verdict.is_empty() else " ".join(verdict),
		])
	print("vuelo %d, con falla %d" % [hybrids.size(), failed])
	return failed


## A clip frame baked by tools/bake_clips.gd (027h), or null.
static func _baked_frame(obj_path: String) -> Mesh:
	var baked := BodyCatalog.clip_frame_path(obj_path)
	if baked.is_empty() or not ResourceLoader.exists(baked):
		return null
	return ResourceLoader.load(baked) as Mesh


## Nearest-rank percentile (0.5 = median, averaged between the two middle values of an even count).
static func _percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var count := sorted.size()
	if fraction == 0.5:
		return sorted[count / 2] if count % 2 == 1 else (sorted[count / 2 - 1] + sorted[count / 2]) * 0.5
	return sorted[clampi(ceili(fraction * count) - 1, 0, count - 1)]
