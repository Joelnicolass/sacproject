extends Node

## 024b test bed (RFC-024 §6): a Trogg of slot 1 with a Druid 20 m away and another 60 m away that has
## "hit first", all standing still. check_tick (Enter) lets the Trogg fight: the runner asks its TargetPicker
## who it chooses, prints the scores next to the ones worked out from sacengine updateTarget (state.d:12925)
## and lets it go. A third Druid stands beyond every sight of the side and is never in the table.
## Headless it releases by itself, runs `fight_s` seconds, prints `TARGET_PICK {json}` and quits.
##
## The RFC wrote the far Druid's weight as 0.25*(100/60)^2*1.25*1.2; sacengine gives 0.3025*1.25*1.2 for
## d = 60 < 100 (s = 1 - 0.75*0.6 = 0.55): the 0.25*ref/d branch only starts at ref. The runner expects the
## second.

const TAG := "TARGET_PICK "
const REF := 100.0

@export var world: Node3D
@export var trogg: UnitBody
@export var near_foe: UnitBody
@export var far_foe: UnitBody
@export var unseen_foe: UnitBody
@export var status_label: Label
@export var settle_ticks := 10
@export var fight_s := 12.0
@export var follow_with_camera := true

var _args: Dictionary = {}
var _headless := false
var _ticks := 0
var _armed := false
var _released := false
var _done := false
var _release_tick := 0
var _report: Dictionary = {}


func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	_headless = DisplayServer.get_name() == "headless"
	trogg.get_node("TargetPicker").set("record_scores", true)
	_set_status("Pendiente")
	if _headless or _args.has("autostart"):
		_armed = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick") and not _released:
		_armed = true


func _physics_process(_delta: float) -> void:
	if _done or not _armed:
		return
	_ticks += 1
	if not _released:
		if _ticks >= settle_ticks:
			_release()
		return
	var seconds := float(_ticks - _release_tick) / 60.0
	if seconds >= fight_s:
		_finish()


func _release() -> void:
	_released = true
	_release_tick = _ticks
	var picker := trogg.get_node("TargetPicker") as TargetPicker
	## Every body looks once (the side has not looked yet at tick 0).
	for body in [trogg, near_foe, far_foe, unseen_foe]:
		body.vision.refresh()
	var here := trogg.global_position
	var near_d := _flat(here, near_foe.global_position)
	var far_d := _flat(here, far_foe.global_position)
	var without := picker.pick(here)
	_report["near_m"] = snappedf(near_d, 0.1)
	_report["far_m"] = snappedf(far_d, 0.1)
	_report["unseen_m"] = snappedf(_flat(here, unseen_foe.global_position), 0.1)
	_report["without_attacker"] = _name_of(without)
	_report["table_without"] = _table(picker)
	## The far Druid "hits first": what UnitBody.struck does through TargetPicker._on_struck.
	VisionSides.reveal(far_foe, trogg)
	picker.note_attacker(far_foe)
	var chosen := picker.pick(here)
	var expected_near := TargetPicker.score(near_d, REF, false, false, false)
	var expected_far := TargetPicker.score(far_d, REF, false, true, false)
	var expected := near_foe if expected_near >= expected_far else far_foe
	_report["expected_near"] = snappedf(expected_near, 0.0001)
	_report["expected_far"] = snappedf(expected_far, 0.0001)
	_report["rfc_text_far"] = snappedf(0.25 * pow(100.0 / far_d, 2.0) * 1.25 * 1.2, 0.0001)
	_report["chosen"] = _name_of(chosen)
	_report["expected"] = _name_of(expected)
	_report["table_with_attacker"] = _table(picker)
	_report["unseen_in_table"] = _in_table(picker, unseen_foe)
	_report["unseen_visible"] = VisionSides.sees(1, unseen_foe)
	_report["ok"] = chosen == expected and not bool(_report["unseen_in_table"]) and not bool(_report["unseen_visible"])
	trogg.idle_aggro = true
	if follow_with_camera and not _headless:
		var camera := world.get_node_or_null("%Camera")
		if camera:
			camera.call("set_follow", trogg)
	var lines := "Elige: %s (esperado %s)\n%s: %.3f · %s: %.3f (golpeó primero)" % [_name_of(chosen), _name_of(expected), _name_of(near_foe), expected_near, _name_of(far_foe), expected_far]
	_set_status(lines)
	print("target_pick: elige %s; esperado %s; %s %.4f, %s %.4f" % [_name_of(chosen), _name_of(expected), _name_of(near_foe), expected_near, _name_of(far_foe), expected_far])


func _finish() -> void:
	_done = true
	_report["target_at_end"] = _name_of(trogg.target)
	_report["near_hp"] = snappedf(float(near_foe.get_node("Health").get("current")), 0.1)
	_report["far_hp"] = snappedf(float(far_foe.get_node("Health").get("current")), 0.1)
	_report["unseen_hp"] = snappedf(float(unseen_foe.get_node("Health").get("current")), 0.1)
	_report["unseen_untouched"] = float(unseen_foe.get_node("Health").get("current")) >= float(unseen_foe.get_node("Health").get("maximum"))
	_report["ok"] = bool(_report["ok"]) and bool(_report["unseen_untouched"])
	print(TAG + JSON.stringify(_report))
	if _args.has("out"):
		var file := FileAccess.open(str(_args["out"]), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(_report, "  "))
	if _headless or _args.has("quit"):
		get_tree().quit(0 if bool(_report["ok"]) else 1)


func _table(picker: TargetPicker) -> Array:
	var rows := []
	for entry in picker.last_scores:
		rows.append({"foe": _name_of(entry["node"]), "score": snappedf(float(entry["score"]), 0.0001)})
	return rows


func _in_table(picker: TargetPicker, node: Node3D) -> bool:
	for entry in picker.last_scores:
		if entry["node"] == node:
			return true
	return false


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


static func _name_of(node: Node) -> String:
	return String(node.name) if node != null else "-"


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var cut := body.find("=")
		if cut < 0:
			out[body] = true
		else:
			out[body.substr(0, cut)] = body.substr(cut + 1)
	return out
