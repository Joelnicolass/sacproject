extends Node

## RFC-055 055g g0, debug only: records one sacrifice scenario tick by tick as JSONL, so a refactor of the ritual and the doctor can be
## compared with `diff` against the file the code made BEFORE it. One process per case:
##   godot --headless --fixed-fps 600 res://debug/sacrifice/ritual_timeline.tscn -- --case=<case> --out=<file>
## Cases: desecrate_complete, desecrate_doctor_killed, desecrate_site_falls, convert_complete, convert_pump_kill, carry_kill, push, body_facts.
## `--out` is an absolute path or a project path (res://, user://, or relative to the project); the folder is created.
## It builds a small world (a floor, SacrificeSystem, a wizard of slot 1, an altar, a creature) and casts the real spell, with the rules of
## debug/rules/desecrate.tres or convert.tres. It reads only what the plan (055g section 9.1) says does not change: SacrificeSystem and
## Ritual public members, DoctorBody, Captive, the groups. What it does not do: judge anything (the `diff` does) or write to src/scenes.
## Each line: tick, event (cast, vortex, landed, took, arrived, phase, round, drain, outcome, freed, sample), what, phase, round, outcome,
## hp and mana of the target (1e-6), souls in the caster's purse, positions of the captive, the doctors and the vortices (1e-4 m).
## Prints `TIMELINE <case> lines=<n> outcome=<...>`; exit code 0 when the case ended, 2 on timeout, 1 on a usage or cast error.

const SYSTEM_SCENE := preload("res://scenes/sacrifice/sacrifice_system.tscn")
const SOUL_SYSTEM_SCENE := preload("res://scenes/souls/soul_system.tscn")
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const DESECRATE_RULES := preload("res://debug/rules/desecrate.tres")
const CONVERT_RULES := preload("res://debug/rules/convert.tres")
const GOD := "james"
const BODY_DIRS: Array[String] = ["res://scenes/units/bodies/", "res://scenes/wizards/bodies/"]
## Simulated seconds before a case counts as stuck, and wall-clock milliseconds before the process gives up.
const CAP_S := 240.0
const WALL_LIMIT_MS := 180000
const SAMPLE_TICKS := 30
const PUSHER_DISTANCE_M := 8.0

var _case := ""
var _out := ""
var _lines := PackedStringArray()
var _tick := 0
var _recording := false
var _finished := false
var _start_ms := 0
var _outcome := "none"
var _marks := {}
var _rules: MatchRules
var _root: Node3D
var _system: SacrificeSystem
var _caster: WizardBody
var _target: WizardBody
var _altar: Altar
var _captive: UnitBody
var _soul: Soul
var _pusher: UnitBody
var _last_ritual: Ritual
var _watch := {}
var _poses := {}
var _vortex_count := 0
var _phase := -1
var _round := -1
var _ritual_outcome := -1
var _held := false
var _reviving := false
var _last_hp := 0.0
var _last_mana := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			_case = arg.trim_prefix("--case=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	_start_ms = Time.get_ticks_msec()
	if _case.is_empty() or _out.is_empty():
		printerr("ritual_timeline: usage -- --case=<case> --out=<file>")
		get_tree().quit(1)
		return
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	if Time.get_ticks_msec() - _start_ms > WALL_LIMIT_MS or _tick > _secs(CAP_S) + 600:
		_outcome = "timeout"
		_write()
		_finished = true
		get_tree().quit(2)
		return
	_tick += 1
	if not _recording:
		return
	_observe()
	if _tick % SAMPLE_TICKS == 0:
		_emit("sample")


func _run() -> void:
	await _frames(2)
	if _case == "body_facts":
		_dump_body_facts()
		await _finish()
		return
	var desecrate := _case.begins_with("desecrate") or _case == "push"
	if not (desecrate or _case in ["convert_complete", "convert_pump_kill", "carry_kill"]):
		printerr("ritual_timeline: unknown case '%s'" % _case)
		get_tree().quit(1)
		return
	_rules = DESECRATE_RULES if desecrate else CONVERT_RULES
	await _build(desecrate)
	var ok := await _cast("ucas" if desecrate else "ccas", _captive if desecrate else _soul)
	if not ok:
		_write()
		await _dispose()
		get_tree().quit(1)
		return
	while not _finished and not _step():
		await _frames(1)
	await _finish()


# --- The world ---

func _build(desecrate: bool) -> void:
	_root = Node3D.new()
	_root.name = "RitualTimeline"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 2.0, 800.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	add_child(_root)
	_system = SYSTEM_SCENE.instantiate() as SacrificeSystem
	_system.rules = _rules
	_root.add_child(_system)
	_system.carrier_arrived.connect(func(_errand: CarryErrand) -> void: _emit("arrived"))
	if not desecrate:
		_root.add_child(SOUL_SYSTEM_SCENE.instantiate())
	_caster = _wizard(1, Vector3.ZERO)
	if desecrate:
		_altar = _altar_at(2, Vector3(0.0, 0.0, 60.0))
		_target = _wizard(2, Vector3(60.0, 0.0, 60.0))
		_captive = _unit(Vector3(0.0, 0.1, 12.0), 1, "nmuh")
		if _case == "push":
			var site := _altar.site.center()
			_pusher = _unit(Vector3(site.x + PUSHER_DISTANCE_M, 0.1, site.z), 2, "nmuh")
	else:
		_altar = _altar_at(1, Vector3(0.0, 0.0, -70.0))
		_captive = _unit(Vector3(0.0, 0.1, 14.0), 2, "nugf" if _case == "convert_complete" else "nmuh")
	await _frames(20)
	if not desecrate:
		_captive.get_node("Health").damage(99999.0, 1)
		await _frames(120)
		_soul = _soul_of(_captive)
		for _i in 400:
			if _soul != null and _soul.state == Soul.State.NORMAL:
				break
			await _frames(1)
	_watch["captive"] = _captive
	_watch["altar"] = _altar
	if _target != null:
		_watch["target"] = _target


## Casts `tag` on `aimed` for real: begin, the casting time, finish. Starts the recording at the begin (tick 0).
func _cast(tag: String, aimed: Node3D) -> bool:
	var action := _caster.get_node("Caster").action_for(tag) as SpellAction
	var spell: SpellType = _caster.get_node("Spellbook").structure_by_tag(tag)
	var aim := action.check(_caster, spell, Vector3.ZERO, aimed, "")
	if not aim.status.is_empty():
		_outcome = "cast_refused_" + str(aim.status)
		return false
	_tick = 0
	_recording = true
	_prime()
	_emit("cast", "begin")
	action.begin(_caster, spell, aim)
	await _frames(maxi(ceili(spell.casting_time_s * Engine.physics_ticks_per_second), 1))
	var told := action.finish(_caster, spell, aimed)
	_emit("cast", "finish:" + told)
	if not told.is_empty():
		_outcome = "cast_failed_" + told
	return told.is_empty()


# --- What each case does after the cast ---

## One tick of the case's script. True when the case has ended.
func _step() -> bool:
	var ritual := _ritual()
	match _case:
		"desecrate_doctor_killed":
			if ritual != null and ritual.phase == Ritual.Phase.SHOOT and ritual.round_index == 0:
				_mark_once("shoot")
				if _since("shoot") >= _secs(1.0) and not _marks.has("killed"):
					_marks["killed"] = _tick
					var doomed := _ring_doctor(ritual, 1)
					if doomed != null:
						doomed.kill(2)
		"desecrate_site_falls":
			if ritual != null and ritual.phase == Ritual.Phase.WALK:
				_mark_once("walk")
				if _since("walk") >= SAMPLE_TICKS and not _marks.has("fell"):
					_marks["fell"] = _tick
					_altar.state = Altar.State.DESTROYED
		"convert_pump_kill":
			if is_instance_valid(_captive) and _captive.is_reviving():
				_mark_once("pump")
				if _since("pump") >= 120 and not _marks.has("killed"):
					_marks["killed"] = _tick
					_kill_carrier()
			return _marks.has("killed") and _since("killed") >= 150 and _victim_verdict()
		"carry_kill":
			if is_instance_valid(_captive) and _captive.is_held():
				_mark_once("held")
				if _since("held") >= 180 and not _marks.has("killed"):
					_marks["killed"] = _tick
					_kill_carrier()
			return _marks.has("killed") and _since("killed") >= 240 and _victim_verdict()
	return _ritual_ended()


func _victim_verdict() -> bool:
	var dead := not is_instance_valid(_captive) or _captive.is_dead()
	_outcome = "victim_dead" if dead else "victim_alive"
	return true


## The ritual finished (or went away) and 120 ticks have passed.
func _ritual_ended() -> bool:
	if not is_instance_valid(_last_ritual):
		return _phase >= 0
	_outcome = Ritual.Outcome.keys()[_last_ritual.outcome]
	if _last_ritual.is_queued_for_deletion():
		return true
	if _last_ritual.outcome != Ritual.Outcome.RUNNING:
		_mark_once("ended")
		return _since("ended") >= 120
	return false


func _kill_carrier() -> void:
	var doctors := _doctors()
	if not doctors.is_empty():
		doctors[0].kill(2)


# --- The recording ---

## Resets what the diffing remembers so the first tick of the recording compares against the state at the cast.
func _prime() -> void:
	_last_hp = _hp()
	_last_mana = _mana()
	for doctor in _doctors():
		_poses[doctor.name] = doctor.pose


func _observe() -> void:
	for doctor in _doctors():
		_watch[String(doctor.name)] = doctor
	for node in get_tree().get_nodes_in_group(Ritual.GROUP):
		_watch[String(node.name)] = node
		_last_ritual = node as Ritual
	var vortices := _vortices()
	for vortex in vortices:
		_watch[String(vortex.name)] = vortex
	if vortices.size() != _vortex_count:
		_emit("vortex", "open" if vortices.size() > _vortex_count else "close")
		_vortex_count = vortices.size()
	for doctor in _doctors():
		if int(_poses.get(doctor.name, -1)) == DoctorBody.Pose.FALLING and doctor.pose != DoctorBody.Pose.FALLING:
			_emit("landed", String(doctor.name))
		_poses[doctor.name] = doctor.pose
	if is_instance_valid(_captive):
		if _captive.is_held() and not _held:
			_emit("took", "held")
		if _captive.is_reviving() and not _reviving:
			_emit("took", "revive")
		_held = _captive.is_held()
		_reviving = _captive.is_reviving()
	if is_instance_valid(_last_ritual):
		var ritual := _last_ritual
		if ritual.phase != _phase:
			_phase = ritual.phase
			_emit("phase", Ritual.Phase.keys()[_phase])
		if ritual.round_index != _round:
			_round = ritual.round_index
			_emit("round", str(_round))
		if ritual.outcome != _ritual_outcome:
			_ritual_outcome = ritual.outcome
			_emit("outcome", Ritual.Outcome.keys()[_ritual_outcome])
	var hp := _hp()
	var mana := _mana()
	if _target != null and is_instance_valid(_target) and (_last_hp - hp > 1.0e-9 or _last_mana - mana > 1.0e-9):
		_emit("drain", "", ',"d_hp":%s,"d_mana":%s' % [_num(_last_hp - hp, 6), _num(_last_mana - mana, 6)])
	_last_hp = hp
	_last_mana = mana
	for key: String in _watch.keys():
		var node: Variant = _watch[key]
		if not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
			_emit("freed", key)
			_watch.erase(key)


func _emit(event: String, what := "", extra := "") -> void:
	if not _recording:
		return
	var ritual := _last_ritual if is_instance_valid(_last_ritual) else null
	var line := '{"tick":%d,"event":"%s","what":"%s","phase":%d,"round":%d,"outcome":%d' % [
		_tick, event, what, ritual.phase if ritual else -1, ritual.round_index if ritual else -1, ritual.outcome if ritual else -1]
	line += ',"hp":%s,"mana":%s,"souls":%d' % [_num_or_null(_hp(), 6), _num_or_null(_mana(), 6), _souls()]
	line += ',"captive":%s' % (_pos(_captive) if is_instance_valid(_captive) else "null")
	var doctors: PackedStringArray = []
	for doctor in _doctors():
		doctors.append('{"n":"%s","p":%s,"pose":%d}' % [doctor.name, _pos(doctor), doctor.pose])
	line += ',"doctors":[%s]' % ",".join(doctors)
	var vortices: PackedStringArray = []
	for vortex in _vortices():
		vortices.append(_pos(vortex))
	line += ',"vortex":[%s]' % ",".join(vortices)
	if _pusher != null:
		line += ',"pusher":%s,"push_dist":%s' % [_pos(_pusher) if is_instance_valid(_pusher) else "null", _push_distance()]
	_lines.append(line + extra + "}")


## The target of the ritual: the wizard whose altar it is (Desecrate) or the creature (Convert).
func _hp() -> float:
	if _target != null:
		return (_target.health as Health).current if is_instance_valid(_target) else NAN
	var health := _captive.get_node_or_null("Health") as Health if is_instance_valid(_captive) else null
	return health.current if health != null else NAN


func _mana() -> float:
	if _target != null and is_instance_valid(_target):
		return float(_target.mana.get("current"))
	return NAN


func _souls() -> int:
	var purse := _caster.get_node_or_null("SoulPurse") as SoulPurse if is_instance_valid(_caster) else null
	return purse.count if purse != null else -1


func _push_distance() -> String:
	if not is_instance_valid(_pusher):
		return "null"
	var site := _altar.site.center()
	return _num(Vector2(_pusher.global_position.x - site.x, _pusher.global_position.z - site.z).length(), 4)


# --- Body facts ---

func _dump_body_facts() -> void:
	for dir in BODY_DIRS:
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for file: String in files:
			if not file.ends_with(".tscn"):
				continue
			var scene := load(dir + file) as PackedScene
			if scene == null:
				_lines.append('{"scene":"%s%s","error":"not a PackedScene"}' % [dir, file])
				continue
			var f := BodyFacts.of(scene)
			_lines.append('{"scene":"%s%s","from_scene":%s,"model_id":"%s","height":%s,"flying_height":%s,"radius":%s,"reach":%s,"capsule_height":%s,"capsule_radius":%s,"flying_capsule_height":%s,"center":%s,"top":%s,"muzzle":%s,"feet":%s}' % [
				dir, file, str(f.from_scene).to_lower(), f.model_id, _dbl(f.height_m), _dbl(f.flying_height_m), _dbl(f.radius_m), _dbl(f.reach_m),
				_dbl(f.capsule_height_m), _dbl(f.capsule_radius_m), _dbl(f.flying_capsule_height_m), _dbl3(f.center), _dbl3(f.top), _dbl3(f.muzzle), _dbl3(f.feet)])
	_outcome = "ok"


## A double as text: the decimal digits and the 64 bits (hex, little endian), so a 1e-12 difference shows up.
func _dbl(value: float) -> String:
	return '"%s|%s"' % [String.num(value, 12), PackedFloat64Array([value]).to_byte_array().hex_encode()]


func _dbl3(value: Vector3) -> String:
	return "[%s,%s,%s]" % [_dbl(value.x), _dbl(value.y), _dbl(value.z)]


# --- Numbers as text (the same bytes on every run) ---

func _num(value: float, decimals: int) -> String:
	var rounded := snappedf(value, pow(10.0, -decimals))
	if rounded == 0.0:
		rounded = 0.0
	return ("%." + str(decimals) + "f") % rounded


func _num_or_null(value: float, decimals: int) -> String:
	return "null" if is_nan(value) else _num(value, decimals)


func _pos(node: Node3D) -> String:
	var at := node.global_position
	return "[%s,%s,%s]" % [_num(at.x, 4), _num(at.y, 4), _num(at.z, 4)]


# --- Finding things (public groups and the system's roots) ---

func _ritual() -> Ritual:
	for node in get_tree().get_nodes_in_group(Ritual.GROUP):
		var ritual := node as Ritual
		if ritual != null and not ritual.is_queued_for_deletion():
			return ritual
	return null


## The living doctors, by the number in their name (Doctor2 before Doctor10).
func _doctors() -> Array[DoctorBody]:
	var found: Array[DoctorBody] = []
	for node in get_tree().get_nodes_in_group(DoctorBody.GROUP):
		var doctor := node as DoctorBody
		if doctor != null and not doctor.is_queued_for_deletion():
			found.append(doctor)
	found.sort_custom(func(a: DoctorBody, b: DoctorBody) -> bool: return _serial(a) < _serial(b))
	return found


func _ring_doctor(ritual: Ritual, index: int) -> DoctorBody:
	var ring: Array[DoctorBody] = []
	for doctor in _doctors():
		if ritual.is_part(doctor):
			ring.append(doctor)
	return ring[index] if index < ring.size() else null


func _vortices() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in _system.get_node("Vortices").get_children():
		if node is Node3D and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _serial(node: Node) -> int:
	return String(node.name).to_int()


func _soul_of(unit: Node) -> Soul:
	for node in get_tree().get_nodes_in_group("soul"):
		var soul := node as Soul
		if soul != null and not soul.is_queued_for_deletion() and soul.corpse == unit:
			return soul
	return null


func _mark_once(key: String) -> void:
	if not _marks.has(key):
		_marks[key] = _tick


func _since(key: String) -> int:
	return _tick - int(_marks[key])


func _secs(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


# --- Building blocks ---

func _wizard(slot: int, at: Vector3) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = slot
	wizard.god = GOD
	(wizard.get_node("Health") as Health).rules = _rules
	(wizard.get_node("SoulPurse") as SoulPurse).rules = _rules
	_root.add_child(wizard)
	wizard.global_position = at
	return wizard


func _altar_at(slot: int, at: Vector3) -> Altar:
	var altar := ALTAR_SCENE.instantiate() as Altar
	altar.owner_slot = slot
	altar.position = at
	_root.add_child(altar)
	return altar


func _unit(at: Vector3, slot: int, tag: String) -> UnitBody:
	var type := GameData.creature(tag)
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.owner_slot = slot
	unit.type = type
	unit.model = type.model_id() if type else ""
	unit.rules = _rules
	unit.idle_aggro = false
	unit.target_groups = PackedStringArray()
	unit.position = at
	_root.add_child(unit)
	return unit


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


# --- The end ---

func _write() -> void:
	var path := _out
	if not (path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path()):
		path = "res://" + path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("ritual_timeline: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
	else:
		for line in _lines:
			file.store_line(line)
		file.close()
	print("TIMELINE %s lines=%d outcome=%s" % [_case, _lines.size(), _outcome])


func _finish() -> void:
	_recording = false
	_write()
	await _dispose()
	_finished = true
	get_tree().quit(0)


## Bodies that still simulate must not be freed under the engine: the bones stop, the nodes leave through the queue together, two frames pass.
func _dispose() -> void:
	_recording = false
	var seen := {}
	var groups: Array[StringName] = [DoctorBody.GROUP, &"unit", Captive.HELD_GROUP, &"corpse", &"wizard"]
	for group in groups:
		for node in get_tree().get_nodes_in_group(group):
			if seen.has(node) or not is_instance_valid(node):
				continue
			seen[node] = true
			var driver := (node as Node).find_child("RagdollDriver", true, false) as RagdollDriver
			if driver != null:
				driver.set_pose(RagdollDriver.Pose.OFF)
			(node as Node).queue_free()
	await _frames(2)
	if is_instance_valid(_root):
		_root.queue_free()
	await _frames(2)
