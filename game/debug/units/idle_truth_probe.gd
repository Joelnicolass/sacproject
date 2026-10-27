class_name IdleTruthProbe
extends BenchProbe

## F376 (RFC-053 053g): does a creature at rest look like it walks on the spot? A BenchProbe child of the ExpectJudge of
## debug/units/f376_idle_truth.tscn. Every tick it reads, for each UnitBody, its FSM state, the clip role that state asks for, its
## flat speed (from the real displacement) and its target. It measures:
##   run_still    seconds with the role `run` and a flat speed under `still_speed`, counted in streaks longer than `streak_min_s`
##                (the worst body of the row's subject);
##   idle_cycles  Idle→Chase→Idle cycles per minute begun with no foe in sight (the worst body of the subject);
##   gesture_root meters the root or the hip slides on the ground during the `gesture` clip of EVERY model scene of
##                scenes/bodies/models/ (creatures and wizards), read from the .glb's AnimationPlayer (ClipSlide; the worst
##                model; a model without the role measures nothing).
## It only reads: the digest of the bench does not change. Headless the rig is inert, so the role is the state's (UnitState.clip_role);
## a body in the air plays its flight clip and is skipped for run_still. Debug code.

## Below this flat speed (m/s) a body playing `run` is «walking on the spot».
@export var still_speed := 0.2
## Only streaks longer than this count (a frame of turn while it starts to walk is not a step on the spot).
@export var streak_min_s := 0.2

## instance id -> the body's record.
var _records: Dictionary = {}
## model tag -> meters (-1: no gesture), and the text of the measure.
var _slides: Dictionary = {}
var _slide_detail: Dictionary = {}
var _tick := 0
var _first_tick := -1


func begin(_bodies: Dictionary) -> void:
	_records.clear()


func step(tick: int) -> void:
	_tick = tick
	if _first_tick < 0:
		_first_tick = tick
	for node in get_tree().get_nodes_in_group(&"unit"):
		var body := node as UnitBody
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var id := body.get_instance_id()
		if not _records.has(id):
			_records[id] = {"body": body, "pos": body.global_position, "mode": body.mode, "streak": 0, "still": 0,
				"worst": 0, "worst_ctx": "", "cycles": 0, "chase_from_idle": false, "chase_no_foe": false, "cycle_ctx": ""}
			continue
		_observe(_records[id], body)


func measures(measure: String) -> bool:
	return measure in ["run_still", "idle_cycles", "gesture_root"]


func value_of(expect: BenchExpect, bodies: Array) -> float:
	if expect.measure == "gesture_root":
		_measure_all_models()
		var worst_slide := 0.0
		for model: String in _slides:
			worst_slide = maxf(worst_slide, float(_slides[model]))
		return worst_slide
	var worst := 0.0
	for body: Node3D in bodies:
		worst = maxf(worst, _value_for(expect.measure, body))
	return worst


func notes_of(expect: BenchExpect, bodies: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	if expect.measure == "gesture_root":
		var over: Array = []
		var with_gesture := 0
		for model: String in _slides:
			if float(_slides[model]) >= 0.0:
				with_gesture += 1
			if float(_slides[model]) > expect.max_value:
				over.append(model)
		over.sort_custom(func(a: String, b: String) -> bool: return float(_slides[a]) > float(_slides[b]))
		for model: String in over:
			lines.append("modelo %s gesto %s" % [model, str(_slide_detail[model])])
		lines.append("%d modelos medidos, %d con gesto, %d por encima de %.2f m" % [_slides.size(), with_gesture, over.size(), expect.max_value])
		return lines
	var rows: Array = []
	for body: Node3D in bodies:
		var value := _value_for(expect.measure, body)
		if value > 0.0:
			rows.append([value, body])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for row: Array in rows.slice(0, 12):
		var body := row[1] as UnitBody
		var record: Dictionary = _records.get(body.get_instance_id(), {})
		if expect.measure == "run_still":
			lines.append("%s (%s) %.2f s de run quieto; peor racha %.2f s: %s" % [body.name, _tag(body), float(row[0]),
				float(record.get("worst", 0)) / MatchClock.TICKS_PER_SECOND_F, str(record.get("worst_ctx", ""))])
		else:
			lines.append("%s (%s) %.2f ciclos/min; %d ciclos; ultimo %s" % [body.name, _tag(body), float(row[0]),
				int(record.get("cycles", 0)), str(record.get("cycle_ctx", ""))])
	return lines


func _value_for(measure: String, body: Node3D) -> float:
	var unit := body as UnitBody
	if unit == null:
		return 0.0
	var record: Dictionary = _records.get(unit.get_instance_id(), {})
	match measure:
		"run_still":
			var still := int(record.get("still", 0))
			if int(record.get("streak", 0)) > MatchClock.ticks_for(streak_min_s):
				still += int(record["streak"])
			return float(still) / MatchClock.TICKS_PER_SECOND_F
		"idle_cycles":
			var minutes := maxf(1.0 / 60.0, float(_tick - _first_tick) / MatchClock.TICKS_PER_SECOND_F / 60.0)
			return float(record.get("cycles", 0)) / minutes
	return 0.0


func _observe(record: Dictionary, body: UnitBody) -> void:
	var pos := body.global_position
	var last: Vector3 = record["pos"]
	var speed := Vector2(pos.x - last.x, pos.z - last.z).length() * MatchClock.TICKS_PER_SECOND_F
	record["pos"] = pos
	var state := body.current_state()
	var role := state.clip_role() if state != null else ""
	if role == "run" and not body.is_flying() and speed < still_speed:
		record["streak"] = int(record["streak"]) + 1
		if int(record["streak"]) > int(record["worst"]):
			record["worst"] = record["streak"]
			record["worst_ctx"] = "%s desde %s, blanco %s, paso pedido %.2f m/s" % [state.name,
				ExpectJudge._seconds(_tick - int(record["streak"])), _name_of(body.target), Vector2(body.velocity.x, body.velocity.z).length()]
	else:
		_close_streak(record)
	var mode: int = body.mode
	var was: int = record["mode"]
	if mode == was:
		return
	if was == UnitBody.Mode.IDLE and mode == UnitBody.Mode.CHASE:
		record["chase_from_idle"] = true
		record["chase_no_foe"] = not _foe_in_sight(body)
		record["cycle_ctx"] = "blanco %s a los %s" % [_name_of(body.target), ExpectJudge._seconds(_tick)]
	elif was == UnitBody.Mode.CHASE and mode == UnitBody.Mode.IDLE:
		if bool(record["chase_from_idle"]) and bool(record["chase_no_foe"]):
			record["cycles"] = int(record["cycles"]) + 1
		record["chase_from_idle"] = false
	elif mode != UnitBody.Mode.CHASE:
		record["chase_from_idle"] = false
	record["mode"] = mode


func _close_streak(record: Dictionary) -> void:
	if int(record["streak"]) > MatchClock.ticks_for(streak_min_s):
		record["still"] = int(record["still"]) + int(record["streak"])
	record["streak"] = 0


## A foe by the rules of orders (stance, health that can go down) within the body's sight.
func _foe_in_sight(body: UnitBody) -> bool:
	for group in [&"unit", &"wizard", &"structure"]:
		for node in get_tree().get_nodes_in_group(group):
			if node != body and node is Node3D and body.engagement.is_foe(node) and body.locomotion.flat_distance(node as Node3D) <= body.vision.range_m():
				return true
	return false


func _measure_all_models() -> void:
	if not _slides.is_empty():
		return
	for file in DirAccess.get_files_at(ModelPaths.SCENE_DIR):
		if file.ends_with(".tscn"):
			gesture_slide_m(ModelPaths.tag_of_file(file))


## Meters the `gesture` clip of `model`'s scene slides the body on the ground (ClipSlide). -1 when the model has no scene
## or no gesture role. Cached per model.
func gesture_slide_m(model: String) -> float:
	if _slides.has(model):
		return float(_slides[model])
	_slides[model] = -1.0
	if not ModelPaths.exists(model):
		return -1.0
	var scene := load(ModelPaths.scene_path(model)) as PackedScene
	var root := scene.instantiate() as BodyModel if scene != null else null
	if root == null:
		return -1.0
	add_child(root)
	var tag := root.tag_for("gesture")
	var player := root.clip_player()
	var skeleton := root.skeleton()
	if not tag.is_empty() and player != null and skeleton != null and player.has_animation(tag):
		var gesture := ClipSlide.measure(player, skeleton, player.get_animation(tag))
		var rest_tag := root.tag_for("idle")
		var rest := ClipSlide.measure(player, skeleton, player.get_animation(rest_tag)) if player.has_animation(rest_tag) else {}
		_slides[model] = float(gesture["slide"])
		_slide_detail[model] = "%s raiz %.3f m, cadera %.3f m (raiz por eje %s); reposo %s %.3f m" % [tag, float(gesture["root"]),
			float(gesture["hip"]), AiAudit.fmt(gesture["span"]), rest_tag, float(rest.get("slide", 0.0))]
	remove_child(root)
	root.free()
	return float(_slides[model])


static func _name_of(node: Variant) -> String:
	return String((node as Node).name) if node != null and is_instance_valid(node) else "-"


static func _tag(body: UnitBody) -> String:
	return body.type.tag if body.type != null else body.model
