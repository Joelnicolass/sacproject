extends RefCounted

## 055f f4 case of rules_suite: how the AI plays lives in data/ai/tactics_*.tres (crowd and senses embedded) and in the Clock of
## ai_side.tscn, with the numbers the code used before. Per difficulty: each field from profile_original.tres or a code literal, digit
## for digit; the clock's ticks per job (24/120/12/12/120/24, 12/60/6/6/60/12, 9/45/4/4/45/9); the ages (16/8/32/8/16/8); the guard
## pick's scale in float32; and that a room's ids easy, normal, hard still find their file. Prints AI TACTICS checked=<n> differ=<n>.

const SIDE := preload("res://scenes/ai/ai_side.tscn")
const IDS: Array[String] = ["easy", "normal", "hard"]
## The numbers of profile_original.tres and the code's literals, with all their digits.
const WIZARD := {
	"wizard_replan_s": 1.6, "wizard_reissue_s": 0.8, "ghost_wait_m": 256.0, "wizard_stop_m": 10.0,
	"attack_coefficient": 280.0, "weight_passive": 0.5, "weight_no_ability": 0.3333333432674408, "weight_sac_doctor": 10.0,
	"range_distance_scale": 0.7142857313156128, "near_distance_sq": 1600.0,
	"emergency_threat_factor": 1.2999999523162842, "summon_threat_cap": 0.6, "emergency_mana_ratio": 1400.0, "ready_divisor": 2,
	"convert_reach_m": 500.0, "convert_score_factor": 0.8999999761581421,
	"build_threat_cap": 0.9, "build_range_slack": 1.399999976158142, "build_reach_factor": 5.0,
	"desecrate_range_factor": 0.8999999761581421,
	"soul_reach_scale": 100.0, "soul_reach_base": 80.0, "soul_keep_factor": 1.25,
}
const CROWD := {
	"group_radius_m": 30.0, "group_growth": 0.1, "group_cap": 1.8, "record_near_m": 100.0, "follow_radius_m": 8.0,
	"retreat_hold_m": 10.0, "mana_seek_m": 3620.0, "interact_reach_m": 160.0, "guard_pick_near_m": 10.0, "guard_pick_far_m": 3620.0,
}
const SENSES := {
	"rerate_s": 1.6, "status_s": 0.8, "souls_snapshot_s": 3.2, "threat_s": 0.8, "threat_near_m": 10.0, "threat_far_m": 280.0,
}
const TICKS := {
	"easy": [24, 120, 12, 12, 120, 24],
	"normal": [12, 60, 6, 6, 60, 12],
	"hard": [9, 45, 4, 4, 45, 9],
}
## [seconds field, where it lives, ages].
const AGES := [
	["rerate_s", "senses", 16], ["status_s", "senses", 8], ["souls_snapshot_s", "senses", 32], ["threat_s", "senses", 8],
	["wizard_replan_s", "wizard", 16], ["wizard_reissue_s", "wizard", 8],
]
const GUARD_SCALE := 0.0002770083083305508

var _checked := 0
var _lines := PackedStringArray()


func run(_host: Node) -> Dictionary:
	var side: Node = SIDE.instantiate()
	var clock: AiClock = side.get_node("Clock") as AiClock
	for id: String in IDS:
		var difficulty: AiDifficulty = AiSeat.difficulty_of(id)
		if difficulty == null:
			_differ("%s: no difficulty" % id)
			continue
		var tactics: AiTactics = difficulty.tactics_or_normal()
		_fields(id, tactics, WIZARD)
		_embedded(id, tactics)
		if tactics.crowd != null:
			_fields(id + ".crowd", tactics.crowd, CROWD)
			_guard_scale(id, tactics.crowd)
		if tactics.senses != null:
			_fields(id + ".senses", tactics.senses, SENSES)
		var play: AiPlay = AiPlay.make(difficulty, null, clock.base_ticks(AiClock.Job.PERCEPTION))
		clock.play = play
		_ticks(id, clock)
		_ages(id, play, tactics)
		_compare(id + ".aggression", play.aggression, difficulty.aggression)
	_rooms()
	_seat_override(clock)
	side.free()
	print("AI TACTICS checked=%d differ=%d" % [_checked, _lines.size()])
	for line in _lines:
		print("AI TACTICS   " + line)
	return {"ai_tactics": {"ok": _checked > 0 and _lines.is_empty(), "checked": _checked, "differ": _lines.size(), "notes": _lines}}


func _fields(where: String, resource: Resource, expected: Dictionary) -> void:
	for key: String in expected:
		_compare("%s.%s" % [where, key], resource.get(key), expected[key])


## crowd and senses are sub-resources of the same file (nothing scattered over several .tres).
func _embedded(id: String, tactics: AiTactics) -> void:
	_checked += 1
	if tactics.crowd == null or tactics.senses == null:
		_differ("%s: crowd or senses missing" % id)
		return
	if not (_is_embedded(tactics.crowd) and _is_embedded(tactics.senses)):
		_differ("%s: crowd %s, senses %s not embedded" % [id, tactics.crowd.resource_path, tactics.senses.resource_path])


## A sub-resource has no file of its own (its path is empty or «file.tres::id»).
static func _is_embedded(resource: Resource) -> bool:
	return resource.resource_path.is_empty() or resource.resource_path.contains("::")


## The weight of the guard pick falls by 1/(far - near) per meter; in float32 that is the constant the code had.
func _guard_scale(id: String, crowd: AiCrowdTactics) -> void:
	var scale: float = AiField.f32(1.0 / (crowd.guard_pick_far_m - crowd.guard_pick_near_m))
	_compare(id + ".guard_pick_scale", scale, GUARD_SCALE)


func _ticks(id: String, clock: AiClock) -> void:
	var got: Array = []
	for job: int in 6:
		got.append(clock.ticks(job))
	_checked += 1
	if got != (TICKS[id] as Array):
		_differ("%s.ticks: %s (was %s)" % [id, str(got), str(TICKS[id])])


func _ages(id: String, play: AiPlay, tactics: AiTactics) -> void:
	if tactics.senses == null:
		return
	for row: Array in AGES:
		var holder: Resource = tactics.senses if row[1] == "senses" else tactics
		var seconds: float = float(holder.get(row[0]))
		_compare("%s.%s ages" % [id, row[0]], play.ages_for(seconds), row[2])


## The ids a room sends (easy, normal, hard) find their file through data/ai/difficulties.tres, in the menus' order.
func _rooms() -> void:
	_checked += 1
	var ids: PackedStringArray = AiSeat.difficulty_ids()
	if ids != PackedStringArray(IDS):
		_differ("difficulty_ids: %s" % str(ids))
	for id: String in IDS:
		var difficulty: AiDifficulty = AiSeat.difficulty_of(id)
		var path: String = difficulty.resource_path if difficulty != null else "-"
		_compare("difficulty_of(%s)" % id, path, "res://data/ai/difficulty_%s.tres" % id)
	_compare("difficulty_of(empty)", AiSeat.difficulty_of("") == null, true)
	_compare("difficulty_of(unknown)", AiSeat.difficulty_of("insane") == null, true)
	_compare("seat without difficulty", AiSeat.new().difficulty_or_normal().resource_path, "res://data/ai/difficulty_normal.tres")


## A seat's own tactics win over its difficulty's; without them it plays the difficulty's.
func _seat_override(clock: AiClock) -> void:
	var own := AiTactics.new()
	var hard: AiDifficulty = AiSeat.difficulty_of("hard")
	var with_own: AiPlay = AiPlay.make(hard, own, clock.base_ticks(AiClock.Job.PERCEPTION))
	var without: AiPlay = AiPlay.make(hard, null, clock.base_ticks(AiClock.Job.PERCEPTION))
	_compare("seat tactics win", with_own.tactics == own, true)
	_compare("difficulty tactics otherwise", without.tactics == hard.tactics_or_normal(), true)


func _compare(what: String, got: Variant, want: Variant) -> void:
	_checked += 1
	if typeof(got) != typeof(want) or got != want:
		_differ("%s = %s (was %s)" % [what, var_to_str(got), var_to_str(want)])


func _differ(line: String) -> void:
	_lines.append(line)
